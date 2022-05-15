//  Copyright 2021 Abitofevrything and others.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import 'dart:async';

import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../checks/checks.dart';
import '../commands.dart';
import '../context/chat_context.dart';
import '../context/context.dart';
import '../converters/converter.dart';
import '../errors.dart';
import '../mirror_utils/mirror_utils.dart';
import '../util/mixins.dart';
import '../util/util.dart';
import '../util/view.dart';
import 'interfaces.dart';
import 'options.dart';

/// Indicates the ways a [ChatCommand] can be executed.
///
/// For example, a command with type [slashOnly] cannot be executed with a text message:
/// ```dart
/// ChatCommand test = ChatCommand.slashOnly(
///   'test',
///   'A test command',
///   (IChatContext context) async {
///     context.respond(MessageBuilder.content('Hi there!'));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
/// ![](https://user-images.githubusercontent.com/54505189/154319432-0120f3eb-ce71-44a2-8587-38b090c1a307.png)
enum CommandType {
  /// Indicates that a [ChatCommand] should only be executable through text messages (sent with the
  /// bot prefix).
  ///
  /// If this is the type of a [ChatCommand], then that command will not be registered as a Slash
  /// Command in the Discord API.
  textOnly,

  /// Indicates that a [ChatCommand] should only be executable through Slash Commands.
  slashOnly,

  /// Indicates that a [ChatCommand] can be executed by both Slash Commands and text messages.
  all,

  /// Indicates that a [ChatCommand] should use the default type provided by [IOptions.options].
  ///
  /// If the default type provided by the options is itself [def], the behaviour is identical to
  /// [all].
  // TODO: Instead of having [def], make [ChatCommand.type] be a classical option
  // ([ChatCommand.options.type]) and have it be inherited.
  def,
}

mixin ChatGroupMixin implements IChatCommandComponent {
  final StreamController<IChatContext> _onPreCallController = StreamController.broadcast();
  final StreamController<IChatContext> _onPostCallController = StreamController.broadcast();

  @override
  late final Stream<IChatContext> onPreCall = _onPreCallController.stream;

  @override
  late final Stream<IChatContext> onPostCall = _onPostCallController.stream;

  final Map<String, IChatCommandComponent> _childrenMap = {};

  @override
  void addCommand(ICommandRegisterable<IChatContext> command) {
    if (command is! IChatCommandComponent) {
      throw CommandsError(
          'All child commands of chat groups or commands must implement IChatCommandComponent');
    }

    if (_childrenMap.containsKey(command.name)) {
      throw CommandRegistrationError(
          'Command with name "$fullName ${command.name}" already exists');
    }

    for (final alias in command.aliases) {
      if (_childrenMap.containsKey(alias)) {
        throw CommandRegistrationError('Command with alias "$fullName $alias" already exists');
      }
    }

    if (parent != null) {
      logger.warning('Registering commands to a group after it is registered might cause slash '
          'commands to have incomplete definitions');
    }

    command.parent = this;

    _childrenMap[command.name] = command;
    for (final alias in command.aliases) {
      _childrenMap[alias] = command;
    }

    command.onPreCall.listen(_onPreCallController.add);
    command.onPostCall.listen(_onPostCallController.add);
  }

  @override
  Iterable<IChatCommandComponent> get children => Set.of(_childrenMap.values);

  @override
  Iterable<ChatCommand> walkCommands() sync* {
    if (this is ChatCommand) {
      yield this as ChatCommand;
    }

    for (final child in children) {
      yield* child.walkCommands() as Iterable<ChatCommand>;
    }
  }

  @override
  ChatCommand? getCommand(StringView view) {
    String name = view.getWord();

    if (_childrenMap.containsKey(name)) {
      IChatCommandComponent child = _childrenMap[name]!;

      if (child is ChatCommand && child.resolvedType != CommandType.slashOnly) {
        ChatCommand? found = child.getCommand(view);

        if (found == null) {
          return child;
        }

        return found;
      } else {
        return child.getCommand(view) as ChatCommand?;
      }
    }

    view.undo();
    return null;
  }

  @override
  String get fullName =>
      (parent == null || parent is! ICommandRegisterable
          ? ''
          : (parent as ICommandRegisterable).name + ' ') +
      name;

  @override
  bool get hasSlashCommand => children.any((child) =>
      (child is ChatCommand && child.resolvedType != CommandType.textOnly) ||
      child.hasSlashCommand);

  @override
  Iterable<CommandOptionBuilder> getOptions(CommandsPlugin commands) {
    List<CommandOptionBuilder> options = [];

    for (final child in children) {
      if (child.hasSlashCommand) {
        options.add(CommandOptionBuilder(
          CommandOptionType.subCommandGroup,
          child.name,
          child.description,
          options: List.of(child.getOptions(commands)),
        ));
      } else if (child is ChatCommand && child.resolvedType != CommandType.textOnly) {
        options.add(CommandOptionBuilder(
          CommandOptionType.subCommand,
          child.name,
          child.description,
          options: List.of(child.getOptions(commands)),
        ));
      }
    }

    return options;
  }
}

/// Represents a [Subcommand Group](https://discord.com/developers/docs/interactions/application-commands#subcommands-and-subcommand-groups).
///
/// [ChatGroup]s can be used to organise chat commands into groups of similar commands to avoid
/// filling up a user's UI. Instead, commands are organised into a tree, with only the root of the
/// tree being shown to the user until they select it.
///
/// You might also be interested in:
/// - [ChatCommand], for creating commands that can be added to groups.
class ChatGroup
    with
        ChatGroupMixin,
        ParentMixin<IChatContext>,
        CheckMixin<IChatContext>,
        OptionsMixin<IChatContext>
    implements IChatCommandComponent {
  @override
  final List<String> aliases;

  @override
  final String description;

  @override
  final String name;

  @override
  final CommandOptions options;

  /// Create a new [ChatGroup].
  ChatGroup(
    this.name,
    this.description, {
    this.aliases = const [],
    Iterable<IChatCommandComponent> children = const [],
    Iterable<AbstractCheck> checks = const [],
    this.options = const CommandOptions(),
  }) {
    if (!commandNameRegexp.hasMatch(name) || name != name.toLowerCase()) {
      throw CommandRegistrationError('Invalid group name "$name"');
    }

    for (final child in children) {
      addCommand(child);
    }

    for (final check in checks) {
      super.check(check);
    }
  }
}

/// Represents a [Discord Slash Command](https://discord.com/developers/docs/interactions/application-commands#slash-commands).
///
/// [ChatCommand]s are commands with arguments. They can be invoked in two ways: through an
/// interaction or through a text message sent by a user. In both cases, the arguments received from
/// the Discord API are parsed using [Converter]s to the type that your command expects.
///
/// For example, a simple command that responds with "Hi there!":
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (IChatContext context) async {
///     context.respond(MessageBuilder.content('Hi there!'));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/154318791-11b12542-fe70-4b17-8df8-b578ce6e0a77.png)
///
/// You might also be interested in:
/// - [CommandsPlugin.addCommand], for adding [ChatCommand]s to your bot;
/// - [ChatGroup], for creating command groups;
/// - [MessageCommand], for creating Message Commands;
/// - [UserCommand], for creating User Commands.
class ChatCommand
    with
        ChatGroupMixin,
        ParentMixin<IChatContext>,
        CheckMixin<IChatContext>,
        OptionsMixin<IChatContext>
    implements ICommand<IChatContext>, IChatCommandComponent {
  @override
  final String name;

  @override
  final Iterable<String> aliases;

  @override
  final String description;

  /// The type of this [ChatCommand].
  ///
  /// The type of a [ChatCommand] influences how it can be invoked and can be used to make chat
  /// commands executable only through Slash Commands, or only through text messages.
  ///
  /// You might also be interested in:
  /// - [resolvedType], for getting the resolved type of this command.
  /// - [ChatCommand.slashOnly], for creating [ChatCommand]s with type [CommandType.slashOnly];
  /// - [ChatCommand.textOnly], for creating [ChatCommand]s with type [CommandType.textOnly].
  final CommandType type;

  /// The resolved type of this [ChatCommand].
  ///
  /// If [type] is [CommandType.def], this will query the parent of this command for the default
  /// type. Otherwise, [type] is returned.
  ///
  /// If [type] is [CommandType.def] and no parent provides a default type, [CommandType.def] is
  /// returned.
  CommandType get resolvedType {
    if (type != CommandType.def) {
      return type;
    }

    return resolvedOptions.defaultCommandType ?? CommandType.def;
  }

  /// The function called to execute this command.
  ///
  /// The argument types for the function are dynamically loaded, so you should specify the types of
  /// the arguments in your function declaration.
  ///
  /// Additionally, the names of the arguments are converted from snakeCase Dart identifiers to
  /// kebab-case Discord argument names. If the generated name does not suit you, use the @[Name]
  /// decorator to manually set a name.
  ///
  /// If any exception occurs while calling this function, it will be caught and added to
  /// [CommandsPlugin.onCommandError], wrapped in an [UncaughtException].
  ///
  /// You might also be interested in:
  /// - [Name], for explicitely setting an argument's name;
  /// - [Description], for adding descriptions to arguments;
  /// - [Choices], for specifiying the choices for an argument;
  /// - [UseConverter], for overriding the [Converter] used for a specific argument.
  @override
  final Function execute;

  /// A list of checks that apply only to this command.
  ///
  /// Since chat commands can double as a command group when using text only commands, developers
  /// might want to add checks that only apply to a command and not to its children. [singleChecks]
  /// is how to accomplish this, as they are applied to this command but not inherited by its
  /// children.
  ///
  /// You might also be interested in:
  /// - [singleCheck], for adding single checks to chat commands;
  /// - [checks] and [check], the equivalent for inherited checks.
  final List<AbstractCheck> singleChecks = [];

  /// The types of the required and positional arguments of [execute], in the order they appear.
  final List<Type> argumentTypes = [];

  @override
  final CommandOptions options;

  late final FunctionData _functionData;

  /// Create a new [ChatCommand].
  ///
  /// You might also be interested in:
  /// - [ChatCommand.slashOnly], for creating [ChatCommand]s with type [CommandType.slashOnly];
  /// - [ChatCommand.textOnly], for creating [ChatCommand]s with type [CommandType.textOnly].
  ChatCommand(
    String name,
    String description,
    Function execute, {
    List<String> aliases = const [],
    CommandType type = CommandType.def,
    Iterable<IChatCommandComponent> children = const [],
    Iterable<AbstractCheck> checks = const [],
    Iterable<AbstractCheck> singleChecks = const [],
    CommandOptions options = const CommandOptions(),
  }) : this._(
          name,
          description,
          execute,
          IChatContext,
          aliases: aliases,
          type: type,
          children: children,
          checks: checks,
          singleChecks: singleChecks,
          options: options,
        );

  /// Create a new [ChatCommand] with type [CommandType.textOnly].
  ChatCommand.textOnly(
    String name,
    String description,
    Function execute, {
    List<String> aliases = const [],
    Iterable<IChatCommandComponent> children = const [],
    Iterable<AbstractCheck> checks = const [],
    Iterable<AbstractCheck> singleChecks = const [],
    CommandOptions options = const CommandOptions(),
  }) : this._(
          name,
          description,
          execute,
          MessageChatContext,
          aliases: aliases,
          type: CommandType.textOnly,
          children: children,
          checks: checks,
          singleChecks: singleChecks,
          options: options,
        );

  /// Create a new [ChatCommand] with type [CommandType.slashOnly].
  ChatCommand.slashOnly(
    String name,
    String description,
    Function execute, {
    List<String> aliases = const [],
    Iterable<IChatCommandComponent> children = const [],
    Iterable<AbstractCheck> checks = const [],
    Iterable<AbstractCheck> singleChecks = const [],
    CommandOptions options = const CommandOptions(),
  }) : this._(
          name,
          description,
          execute,
          InteractionChatContext,
          aliases: aliases,
          type: CommandType.slashOnly,
          children: children,
          checks: checks,
          singleChecks: singleChecks,
          options: options,
        );

  ChatCommand._(
    this.name,
    this.description,
    this.execute,
    Type contextType, {
    this.aliases = const [],
    this.type = CommandType.def,
    Iterable<IChatCommandComponent> children = const [],
    Iterable<AbstractCheck> checks = const [],
    Iterable<AbstractCheck> singleChecks = const [],
    this.options = const CommandOptions(),
  }) {
    if (!commandNameRegexp.hasMatch(name) || name != name.toLowerCase()) {
      throw CommandRegistrationError('Invalid command name "$name"');
    }

    _loadArguments(execute, contextType);

    for (final child in children) {
      addCommand(child);
    }

    for (final check in checks) {
      super.check(check);
    }

    for (final singleCheck in singleChecks) {
      this.singleCheck(singleCheck);
    }
  }

  void _loadArguments(Function fn, Type contextType) {
    _functionData = loadFunctionData(fn);

    if (_functionData.parametersData.isEmpty) {
      throw CommandRegistrationError('Command callback function must have a Context parameter');
    }

    if (!isAssignableTo(contextType, _functionData.parametersData.first.type)) {
      throw CommandRegistrationError(
          'The first parameter of a command callback must be of type $contextType');
    }

    // Skip context parameter
    for (final parameter in _functionData.parametersData.skip(1)) {
      if (parameter.description != null) {
        if (parameter.description!.isEmpty || parameter.description!.length > 100) {
          throw CommandRegistrationError(
              'Descriptions must not be empty nor longer than 100 characters');
        }
      }

      if (parameter.converterOverride != null) {
        if (!isAssignableTo(parameter.converterOverride!.output, parameter.type)) {
          throw CommandRegistrationError('Invalid converter override');
        }
      }

      argumentTypes.add(parameter.type);
    }
  }

  @override
  Future<void> invoke(IContext context) async {
    if (context is! IChatContext) {
      return;
    }

    List<dynamic> arguments = [];

    if (context is MessageChatContext) {
      StringView argumentsView = StringView(context.rawArguments);

      for (final parameter in _functionData.parametersData.skip(1)) {
        if (argumentsView.eof) {
          break;
        }

        arguments.add(await parse(
          context.commands,
          context,
          argumentsView,
          parameter.type,
          converterOverride: parameter.converterOverride,
        ));
      }

      // Context parameter will be added in first position later
      if (arguments.length < _functionData.requiredParameters - 1) {
        throw NotEnoughArgumentsException(context);
      }
    } else if (context is InteractionChatContext) {
      for (final parameter in _functionData.parametersData.skip(1)) {
        String kebabCaseName = convertToKebabCase(parameter.name);

        if (!context.rawArguments.containsKey(kebabCaseName)) {
          arguments.add(parameter.defaultValue);
          continue;
        }

        dynamic rawArgument = context.rawArguments[kebabCaseName]!;

        if (isAssignableTo(rawArgument.runtimeType, parameter.type)) {
          arguments.add(rawArgument);
          continue;
        }

        arguments.add(await parse(
          context.commands,
          context,
          StringView(rawArgument.toString(), isRestBlock: true),
          parameter.type,
          converterOverride: parameter.converterOverride,
        ));
      }
    }

    context.arguments = arguments;

    for (final check in [...checks, ...singleChecks]) {
      if (!await check.check(context)) {
        throw CheckFailedException(check, context);
      }
    }

    _onPreCallController.add(context);

    try {
      await Function.apply(execute, [context, ...context.arguments]);
    } on Exception catch (e) {
      throw UncaughtException(e, context);
    }

    _onPostCallController.add(context);
  }

  @override
  Iterable<CommandOptionBuilder> getOptions(CommandsPlugin commands) {
    if (resolvedType != CommandType.textOnly) {
      List<CommandOptionBuilder> options = [];

      for (final parameter in _functionData.parametersData.skip(1)) {
        Converter<dynamic>? argumentConverter =
            parameter.converterOverride ?? commands.getConverter(parameter.type);

        Iterable<ArgChoiceBuilder>? choices =
            parameter.choices?.entries.map((entry) => ArgChoiceBuilder(entry.key, entry.value));

        choices ??= argumentConverter?.choices;

        CommandOptionBuilder builder = CommandOptionBuilder(
          argumentConverter?.type ?? CommandOptionType.string,
          convertToKebabCase(parameter.name),
          parameter.description ?? 'No description provided',
          required: !parameter.isOptional,
          choices: choices?.toList(),
        );

        argumentConverter?.processOptionCallback?.call(builder);

        options.add(builder);
      }

      return options;
    } else {
      // Text-only commands might have children which are slash commands
      return super.getOptions(commands);
    }
  }

  @override
  void addCommand(ICommandRegisterable<IChatContext> command) {
    if (command is! IChatCommandComponent) {
      throw CommandsError(
          'All child commands of chat groups or commands must implement IChatCommandComponent');
    }

    if (resolvedType != CommandType.textOnly) {
      if (command.hasSlashCommand ||
          (command is ChatCommand && command.resolvedType != CommandType.textOnly)) {
        throw CommandRegistrationError('Cannot nest Slash commands!');
      }
    }

    super.addCommand(command);
  }

  /// Add a check to this command that does not apply to this commands children.
  ///
  /// You might also be interested in:
  /// - [check], the equivalent method for inherited checks.
  void singleCheck(AbstractCheck check) {
    for (final preCallHook in check.preCallHooks) {
      onPreCall.listen(preCallHook);
    }

    for (final postCallHook in check.postCallHooks) {
      onPostCall.listen(postCallHook);
    }

    singleChecks.add(check);
  }

  @override
  String toString() => 'Command[name="$name", fullName="$fullName"]';
}
