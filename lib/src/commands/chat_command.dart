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
import 'dart:mirrors';

import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/util/mixins.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

/// An enum used to specify how a [ChatCommand] can be executed.
enum CommandType {
  /// Only allow execution by message.
  ///
  /// [textOnly] commands will not be registered as a slash command to Discord.
  textOnly,

  /// Only allow execution by slash command.
  slashOnly,

  /// Do not restrict execution.
  all,
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

      if (child is ChatCommand && child.type != CommandType.slashOnly) {
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
      (child is ChatCommand && child.type != CommandType.textOnly) || child.hasSlashCommand);

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
      } else if (child is ChatCommand && child.type != CommandType.textOnly) {
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

/// A [ChatCommand] is a function bound to a name and arguments.
///
/// [ChatCommand]s can be text-only (meaning they can only be executed through sending a message with
/// the bot's prefix) or slash-only (meaning they can only be executed through the means of a slash
/// command). They can also be both, meaning they can be used both as a text and as a slash command.
///
/// Note that text-only commands can be [Group]s containing slash commands and vice versa, but slash
/// commands cannot be groups containing other slash commands due to
/// [limitations on Discord](https://discord.com/developers/docs/interactions/application-commands#subcommands-and-subcommand-groups).
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

  /// The type of the command.
  ///
  /// A command's type indicates how it can be invoked; text-only commands can only be executed by
  /// sending a text message on Discord and slash commands can only be invoked by executing a slash
  /// command on Discord.
  ///
  /// Note that a command's type does not influence what type of children a command can have.
  final CommandType type;

  @override
  final Function execute;

  /// Similar to [checks] but only applies to this command.
  ///
  /// Normally checks are inherited from parent to child, but [singleChecks] will only ever apply to
  /// this command and not its children.
  final List<AbstractCheck> singleChecks = [];

  @override
  final CommandOptions options;

  late final MethodMirror _mirror;
  late final Iterable<ParameterMirror> _arguments;
  late final int _requiredArguments;
  final List<String> _orderedArgumentNames = [];
  final Map<String, Type> _mappedArgumentTypes = {};
  final Map<String, ParameterMirror> _mappedArgumentMirrors = {};
  final Map<String, Description> _mappedDescriptions = {};
  final Map<String, Choices> _mappedChoices = {};
  final Map<String, UseConverter> _mappedConverterOverrides = {};

  /// Create a new [ChatCommand]. This must then be registered with [CommandsPlugin.addCommand] or
  /// [GroupMixin.addCommand] before it can be used.
  ChatCommand(
    String name,
    String description,
    Function execute, {
    List<String> aliases = const [],
    CommandType type = CommandType.all,
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

  /// Create a new text-only [ChatCommand]. This must then be registered with
  /// [CommandsPlugin.addCommand] or [GroupMixin.addCommand] before it can be used.
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

  /// Create a new slash-only [ChatCommand]. This must then be registered with
  /// [CommandsPlugin.addCommand] or [GroupMixin.addCommand] before it can be used.
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
    this.type = CommandType.all,
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
    _mirror = (reflect(fn) as ClosureMirror).function;

    Iterable<ParameterMirror> arguments = _mirror.parameters;

    if (arguments.isEmpty) {
      throw CommandRegistrationError('Command callback function must have a Context parameter');
    }

    if (!reflectType(contextType).isAssignableTo(arguments.first.type)) {
      throw CommandRegistrationError(
          'The first parameter of a command callback must be of type $contextType');
    }

    // Skip context argument
    _arguments = arguments.skip(1);
    _requiredArguments = _arguments.fold(0, (i, e) {
      if (e.isOptional) {
        return i;
      }
      return i + 1;
    });

    for (final parametrer in _arguments) {
      if (!parametrer.type.hasReflectedType) {
        throw CommandRegistrationError('Command callback parameters must have reflected types');
      }
      if (parametrer.type.reflectedType == dynamic) {
        throw CommandRegistrationError('Command callback parameters must not be of type "dynamic"');
      }
      if (parametrer.isNamed) {
        throw CommandRegistrationError('Command callback parameters must not be named parameters');
      }
      if (parametrer.metadata.where((element) => element.reflectee is Description).length > 1) {
        throw CommandRegistrationError(
            'Command callback parameters must not have more than one Description annotation');
      }
      if (parametrer.metadata.where((element) => element.reflectee is Choices).length > 1) {
        throw CommandRegistrationError(
            'Command callback parameters must not have more than one Choices annotation');
      }
      if (parametrer.metadata.where((element) => element.reflectee is Name).length > 1) {
        throw CommandRegistrationError(
            'Command callback parameters must not have more than one Name annotation');
      }
      if (parametrer.metadata.where((element) => element.reflectee is UseConverter).length > 1) {
        throw CommandRegistrationError(
            'Command callback parameters must not have more than one UseConverter annotation');
      }
    }

    for (final argument in _arguments) {
      Iterable<Name> names = argument.metadata
          .where((element) => element.reflectee is Name)
          .map((nameMirror) => nameMirror.reflectee)
          .cast<Name>();

      String argumentName;
      if (names.isNotEmpty) {
        argumentName = names.first.name;

        if (!commandNameRegexp.hasMatch(argumentName) || name != name.toLowerCase()) {
          throw CommandRegistrationError('Invalid argument name "$argumentName"');
        }
      } else {
        String rawArgumentName = MirrorSystem.getName(argument.simpleName);

        argumentName = convertToKebabCase(rawArgumentName);

        if (!commandNameRegexp.hasMatch(argumentName) || name != name.toLowerCase()) {
          throw CommandRegistrationError(
              'Could not convert parameter "$rawArgumentName" to a valid Discord '
              'Slash command argument name (got "$argumentName")');
        }
      }

      Iterable<Description> descriptions = argument.metadata
          .where((element) => element.reflectee is Description)
          .map((descriptionMirror) => descriptionMirror.reflectee)
          .cast<Description>();

      Description description;
      if (descriptions.isNotEmpty) {
        description = descriptions.first;
      } else {
        description = const Description('No description provided');
      }

      if (description.value.isEmpty || description.value.length > 100) {
        throw CommandRegistrationError(
            'Descriptions must not be empty nor longer than 100 characters');
      }

      Iterable<Choices> choices = argument.metadata
          .where((element) => element.reflectee is Choices)
          .map((choicesMirror) => choicesMirror.reflectee)
          .cast<Choices>();

      if (choices.isNotEmpty) {
        _mappedChoices[argumentName] = choices.first;
      }

      Iterable<UseConverter> converterOverrides = argument.metadata
          .where((element) => element.reflectee is UseConverter)
          .map((useConverterMirror) => useConverterMirror.reflectee)
          .cast<UseConverter>();

      if (converterOverrides.isNotEmpty) {
        UseConverter converterOverride = converterOverrides.first;

        if (!reflectType(converterOverride.converter.output).isAssignableTo(argument.type)) {
          throw CommandRegistrationError('Invalid converter override');
        }

        _mappedConverterOverrides[argumentName] = converterOverride;
      }

      _mappedDescriptions[argumentName] = description;
      _mappedArgumentTypes[argumentName] = argument.type.reflectedType;
      _mappedArgumentMirrors[argumentName] = argument;
      _orderedArgumentNames.add(argumentName);
    }
  }

  /// Parse arguments contained in the context and call [execute].
  ///
  /// If not enough arguments are provided, [NotEnoughArgumentsException] is thrown. Remaining
  /// data after all optional and non-optional arguments have been parsed is discarded.
  /// If an exception is thrown from [execute], it is caught and rethrown as an [UncaughtException].
  ///
  /// The arguments, if the context is a [MessageChatContext], will be parsed using the relevant
  /// converter on the [commands]. If no converter is found, the command execution will fail.
  ///
  /// If the context is an [IInteractionContext], the arguments will either be parsed from their raw
  /// string representations or will not be parsed at all if the type received from the API is
  /// correct.
  @override
  Future<void> invoke(IContext context) async {
    if (context is! IChatContext) {
      return;
    }

    List<Future<dynamic>> arguments = [];

    if (context is MessageChatContext) {
      StringView argumentsView = StringView(context.rawArguments);

      for (final argumentName in _orderedArgumentNames) {
        if (argumentsView.eof) {
          break;
        }

        Type expectedType = _mappedArgumentTypes[argumentName]!;

        arguments.add(parse(
          context.commands,
          context,
          argumentsView,
          expectedType,
          converterOverride: _mappedConverterOverrides[argumentName]?.converter,
        ));
      }

      if (arguments.length < _requiredArguments) {
        throw NotEnoughArgumentsException(context);
      }
    } else if (context is InteractionChatContext) {
      for (final argumentName in _orderedArgumentNames) {
        if (!context.rawArguments.containsKey(argumentName)) {
          arguments
              .add(Future.value(_mappedArgumentMirrors[argumentName]!.defaultValue?.reflectee));
          continue;
        }

        dynamic rawArgument = context.rawArguments[argumentName]!;
        Type expectedType = _mappedArgumentTypes[argumentName]!;

        if (reflect(rawArgument).type.isAssignableTo(reflectType(expectedType))) {
          arguments.add(Future.value(rawArgument));
          continue;
        }

        arguments.add(parse(
          context.commands,
          context,
          StringView(rawArgument.toString()),
          expectedType,
          converterOverride: _mappedConverterOverrides[argumentName]?.converter,
        ));
      }
    }

    context.arguments = await Future.wait(arguments);

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
    if (type != CommandType.textOnly) {
      List<CommandOptionBuilder> options = [];

      for (final mirror in _arguments) {
        Iterable<Name> names = mirror.metadata
            .where((element) => element.reflectee is Name)
            .map((nameMirror) => nameMirror.reflectee)
            .cast<Name>();

        String name;
        if (names.isNotEmpty) {
          name = names.first.name;
        } else {
          String rawArgumentName = MirrorSystem.getName(mirror.simpleName);

          name = convertToKebabCase(rawArgumentName);
        }

        Converter<dynamic>? argumentConverter = _mappedConverterOverrides[name]?.converter ??
            commands.getConverter(mirror.type.reflectedType);

        Iterable<ArgChoiceBuilder>? choices = _mappedChoices[name]?.builders;

        choices ??= argumentConverter?.choices;

        options.add(CommandOptionBuilder(
          argumentConverter?.type ?? CommandOptionType.string,
          name,
          _mappedDescriptions[name]!.value,
          required: !mirror.isOptional,
          choices: choices?.toList(),
        ));
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

    if (type != CommandType.textOnly) {
      if (command.hasSlashCommand ||
          (command is ChatCommand && command.type != CommandType.textOnly)) {
        throw CommandRegistrationError('Cannot nest Slash commands!');
      }
    }

    super.addCommand(command);
  }

  /// Add a check to this commands [singleChecks].
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
