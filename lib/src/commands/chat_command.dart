import 'dart:async';

import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:runtime_type/runtime_type.dart';

import '../checks/checks.dart';
import '../commands.dart';
import '../context/chat_context.dart';
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
      yield* child.walkCommands();
    }
  }

  @override
  ChatCommand? getCommand(StringView view) => getCommandHelper(view, _childrenMap);

  @override
  String get fullName =>
      (parent == null || parent is! IChatCommandComponent
          ? ''
          : '${(parent as IChatCommandComponent).fullName} ') +
      name;

  @override
  bool get hasSlashCommand => children.any((child) =>
      (child is ChatCommand && child.resolvedOptions.type != CommandType.textOnly) ||
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
          localizationsName: child.localizedNames,
          localizationsDescription: child.localizedDescriptions,
        ));
      } else if (child is ChatCommand && child.resolvedOptions.type != CommandType.textOnly) {
        options.add(CommandOptionBuilder(
          CommandOptionType.subCommand,
          child.name,
          child.description,
          options: List.of(child.getOptions(commands)),
          localizationsName: child.localizedNames,
          localizationsDescription: child.localizedDescriptions,
        ));
      }
    }

    return options;
  }
}

/// Represents a [Subcommand Group](https://discord.com/developers/docs/interactions/application-commands#subcommands-and-subcommand-groups).
///
/// [ChatGroup]s can be used to organize chat commands into groups of similar commands to avoid
/// filling up a user's UI. Instead, commands are organized into a tree, with only the root of the
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

  @override
  final Map<Locale, String>? localizedNames;

  @override
  final Map<Locale, String>? localizedDescriptions;

  /// Create a new [ChatGroup].
  ChatGroup(
    this.name,
    this.description, {
    this.aliases = const [],
    Iterable<IChatCommandComponent> children = const [],
    Iterable<AbstractCheck> checks = const [],
    this.options = const CommandOptions(),
    this.localizedNames,
    this.localizedDescriptions,
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
  /// - [Name], for explicitly setting an argument's name;
  /// - [Description], for adding descriptions to arguments;
  /// - [Choices], for specifying the choices for an argument;
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
  final List<RuntimeType<dynamic>> argumentTypes = [];

  @override
  final CommandOptions options;

  late final FunctionData _functionData;

  @override
  final Map<Locale, String>? localizedNames;

  @override
  final Map<Locale, String>? localizedDescriptions;

  /// Create a new [ChatCommand].
  ///
  /// You might also be interested in:
  /// - [MessageCommand], for creating message commands;
  /// - [UserCommand], for creating user commands;
  /// - [CommandOptions.type], for changing how a command can be executed.
  ChatCommand(
    this.name,
    this.description,
    this.execute, {
    this.aliases = const [],
    Iterable<IChatCommandComponent> children = const [],
    Iterable<AbstractCheck> checks = const [],
    Iterable<AbstractCheck> singleChecks = const [],
    this.options = const CommandOptions(),
    this.localizedNames,
    this.localizedDescriptions,
  }) {
    if (!commandNameRegexp.hasMatch(name) || name != name.toLowerCase()) {
      throw CommandRegistrationError('Invalid command name "$name"');
    }

    if ((localizedNames != null &&
        localizedNames!.values
            .any((names) => !commandNameRegexp.hasMatch(names) || names != names.toLowerCase()))) {
      throw CommandRegistrationError('Invalid localized name for command "$name".');
    }

    RuntimeType<IChatContext> contextType;
    switch (resolvedOptions.type) {
      case CommandType.textOnly:
        contextType = const RuntimeType<MessageChatContext>.allowingDynamic();
        break;
      case CommandType.slashOnly:
        contextType = const RuntimeType<InteractionChatContext>.allowingDynamic();
        break;
      default:
        contextType = const RuntimeType<IChatContext>.allowingDynamic();
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

  void _loadArguments(Function fn, RuntimeType<IChatContext> contextType) {
    _functionData = loadFunctionData(fn);

    if (_functionData.parametersData.isEmpty) {
      throw CommandRegistrationError('Command callback function must have a Context parameter');
    }

    if (!contextType.isSupertypeOf(_functionData.parametersData.first.type)) {
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
        if (!parameter.type.isSupertypeOf(parameter.converterOverride!.output)) {
          throw CommandRegistrationError('Invalid converter override');
        }
      }

      argumentTypes.add(parameter.type);
    }
  }

  @override
  Future<void> invoke(IChatContext context) async {
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
    } on Exception catch (e, s) {
      Error.throwWithStackTrace(UncaughtException(e, context)..stackTrace = s, s);
    }

    _onPostCallController.add(context);
  }

  @override
  Iterable<CommandOptionBuilder> getOptions(CommandsPlugin commands) {
    if (resolvedOptions.type != CommandType.textOnly) {
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
          localizationsName: parameter.localizedNames,
          localizationsDescription: parameter.localizedDescriptions,
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

    if (resolvedOptions.type != CommandType.textOnly) {
      if (command.hasSlashCommand ||
          (command is ChatCommand && command.resolvedOptions.type != CommandType.textOnly)) {
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
