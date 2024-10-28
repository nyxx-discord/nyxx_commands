import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/plugin/http_interaction.dart';

import 'checks/checks.dart';
import 'checks/guild.dart';
import 'commands/chat_command.dart';
import 'commands/interfaces.dart';
import 'commands/message_command.dart';
import 'commands/user_command.dart';
import 'context/base.dart';
import 'context/context_manager.dart';
import 'converters/combine.dart';
import 'converters/converter.dart';
import 'converters/fallback.dart';
import 'errors.dart';
import 'event_manager.dart';
import 'mirror_utils/mirror_utils.dart';
import 'options.dart';
import 'util/util.dart';
import 'util/view.dart';

final Logger logger = Logger('Commands');

/// The base plugin used to interact with nyxx_commands.
///
/// Commands can be added to nyxx_commands with the [addCommand] method. Once you've added the
/// [CommandsPlugin] to your nyxx client, these commands will automatically become available once
/// the client is ready.
///
/// The [CommandsPlugin] will automatically subscribe to all the event streams it needs. It will
/// also bulk override all globally registered slash commands and guild commands in the guilds where
/// commands with [GuildCheck]s are registered.
///
/// For example, here is how you would create and register [CommandsPlugin]:
/// ```dart
/// final commands = CommandsPlugin(
///   prefix: (_) => '!',
/// );
///
/// final client = await Nyxx.connectGateway(
///   token,
///   intents,
///   options: GatewayClientOptions(plugins: [commands]),
/// );
/// ```
///
/// [CommandsPlugin] is also where [Converter]s are managed and stored. New developers need not
/// think about this as nyxx_commands comes with a set of default converters, but interested
/// developers can take a look at [addConverter] and the [Converter] class.
///
/// You might also be interested in:
/// - [ChatCommand], for creating commands that can be executed through Slash Commands or text
///   messages;
/// - [addCommand], for adding commands to your bot;
/// - [check], for adding checks to your bot;
/// - [MessageCommand] and [UserCommand], for creating Message and User Commands respectively.
class CommandsPlugin extends NyxxPlugin<NyxxGateway> implements CommandGroup<CommandContext> {
  /// A function called to determine the prefix for a specific message.
  ///
  /// This function should return a [Pattern] that should match the start of the message content if
  /// it begins with the prefix.
  ///
  /// If this function is `null`, message commands are disabled.
  ///
  /// For example, for a prefix of `!`:
  /// ```dart
  /// (_) => '!'
  /// ```
  ///
  /// Or, for either `!` or `$` as a prefix:
  /// ```dart
  /// (_) => RegExp(r'!|\$')
  /// ```
  ///
  /// You might also be interested in:
  /// - [dmOr], which allows for commands in private messages to omit the prefix;
  /// - [mentionOr], which allows for commands to be executed with the client's mention (ping).
  final FutureOr<Pattern> Function(MessageCreateEvent)? prefix;

  final StreamController<CommandsException> _onCommandErrorController =
      StreamController.broadcast();
  final StreamController<CommandContext> _onPreCallController = StreamController.broadcast();
  final StreamController<CommandContext> _onPostCallController = StreamController.broadcast();

  /// A stream of [CommandsException]s that occur during a command's execution.
  ///
  /// Any error that occurs during the execution of a command will be added here, allowing you to
  /// respond to errors you might encounter during a command's execution. Notably,
  /// [CheckFailedException]s are added to this stream, so you can respond to a failed check here.
  ///
  /// [CommandsError]s that occur during the registration of a command will not be added to this
  /// stream, now will any object thrown that is not an [Exception].
  ///
  /// Exceptions thrown from within a command will be wrapped in an [UncaughtException], allowing
  /// you to access the context in which a command was thrown.
  ///
  /// By default, nyxx_commands logs all exceptions added to this stream. This behavior can be
  /// changed in [options].
  ///
  /// You might also be interested in:
  /// - [CommandsException], the class all exceptions in nyxx_commands subclass;
  /// - [CallHooked.onPostCall], a stream that emits [CommandContext]s once a command completes
  /// successfully.
  late final Stream<CommandsException> onCommandError = _onCommandErrorController.stream;

  @override
  late final Stream<CommandContext> onPreCall = _onPreCallController.stream;

  @override
  late final Stream<CommandContext> onPostCall = _onPostCallController.stream;

  final Map<RuntimeType<dynamic>, Converter<dynamic>> _converters = {};

  @override
  final CommandsOptions options;

  /// The guild to register commands to.
  ///
  /// If [guild] is set, commands will be registered to that guild and will update immediately
  /// without the 1 hour delay global commands have. If [guild] is null, commands will be registered
  /// globally.
  ///
  /// You might also be interested in:
  /// - [GuildCheck], a check that allows developers to override the guild a command is registered
  ///   to.
  Snowflake? guild;

  /// The [ContextManager] attached to this [CommandsPlugin].
  late final ContextManager contextManager = ContextManager(this);

  /// The [EventManager] attached to this [CommandsPlugin].
  late final EventManager eventManager = EventManager(this);

  @override
  final List<AbstractCheck> checks = [];

  final Map<String, UserCommand> _userCommands = {};
  final Map<String, MessageCommand> _messageCommands = {};
  final Map<String, ChatCommandComponent> _chatCommands = {};

  @override
  Iterable<CommandRegisterable> get children =>
      {..._userCommands.values, ..._messageCommands.values, ..._chatCommands.values};

  @override
  String get name => 'Commands';

  /// A list of commands registered by this [CommandsPlugin] to the Discord API.
  final List<ApplicationCommand> registeredCommands = [];

  final Set<NyxxGateway> _attachedClients = {};

  /// Create a new [CommandsPlugin].
  CommandsPlugin({
    required this.prefix,
    this.guild,
    this.options = const CommandsOptions(),
  }) {
    registerDefaultConverters(this);

    if (options.logErrors) {
      onCommandError.listen(
        (error) => logger.shout('Uncaught exception in command', error, error.stackTrace),
      );
    }
  }

  @override
  Future<void> afterConnect(NyxxGateway client) async {
    _attachedClients.add(client);

    var onMessageComponentInteraction =
        client.onMessageComponentInteraction.map((event) => event.interaction);
    var onApplicationCommandInteraction =
        client.onApplicationCommandInteraction.map((event) => event.interaction);
    var onApplicationCommandAutocompleteInteraction =
        client.onApplicationCommandAutocompleteInteraction.map((event) => event.interaction);

    final httpInteractionsPlugin =
        client.options.plugins.whereType<HttpInteractionsPlugin>().firstOrNull;
    if (httpInteractionsPlugin != null) {
      onMessageComponentInteraction = httpInteractionsPlugin.onMessageComponentInteraction;
      onApplicationCommandInteraction = httpInteractionsPlugin.onApplicationCommandInteraction;
      onApplicationCommandAutocompleteInteraction =
          httpInteractionsPlugin.onApplicationCommandAutocompleteInteraction;
    }

    onMessageComponentInteraction
        .where((interaction) => interaction.data.type == MessageComponentType.button)
        .listen(
      (interaction) async {
        try {
          await eventManager.processButtonInteraction(interaction);
        } on CommandsException catch (e) {
          _onCommandErrorController.add(e);
        }
      },
    );

    onMessageComponentInteraction
        .where((interaction) => interaction.data.type == MessageComponentType.stringSelect)
        .listen(
      (interaction) async {
        try {
          await eventManager.processSelectMenuInteraction(interaction);
        } on CommandsException catch (e) {
          _onCommandErrorController.add(e);
        }
      },
    );

    onApplicationCommandInteraction.listen(
      (interaction) async {
        try {
          final applicationCommand = registeredCommands.singleWhere(
            (command) => command.id == interaction.data.id,
          );

          if (interaction.data.type == ApplicationCommandType.user) {
            await eventManager.processUserInteraction(
              interaction,
              _userCommands[applicationCommand.name]!,
            );
          } else if (interaction.data.type == ApplicationCommandType.message) {
            await eventManager.processMessageInteraction(
              interaction,
              _messageCommands[applicationCommand.name]!,
            );
          } else if (interaction.data.type == ApplicationCommandType.chatInput) {
            final (command, options) = _resolveChatCommand(interaction, applicationCommand);

            await eventManager.processChatInteraction(
              interaction,
              options,
              command,
            );
          }
        } on CommandsException catch (e) {
          _onCommandErrorController.add(e);
        }
      },
    );

    onApplicationCommandAutocompleteInteraction.listen((interaction) async {
      try {
        final applicationCommand = registeredCommands.singleWhere(
          (command) => command.id == interaction.data.id,
        );

        final (command, options) = _resolveChatCommand(interaction, applicationCommand);

        final functionData = loadFunctionData(command.execute);
        final focusedOption = options.singleWhere((element) => element.isFocused == true);
        final focusedParameter = functionData.parametersData
            .singleWhere((element) => element.name == focusedOption.name);

        final converter = focusedParameter.converterOverride ?? getConverter(focusedParameter.type);

        await eventManager.processAutocompleteInteraction(
          interaction,
          (focusedParameter.autocompleteOverride ?? converter?.autocompleteCallback)!,
          command,
        );
      } on CommandsException catch (e) {
        _onCommandErrorController.add(e);
      }
    });

    client.onMessageCreate.listen((event) async {
      try {
        await eventManager.processMessageCreateEvent(event);
      } on CommandsException catch (e) {
        _onCommandErrorController.add(e);
      }
    });

    if (children.isNotEmpty) {
      _syncCommands(client);
    }
  }

  (ChatCommand, List<InteractionOption>) _resolveChatCommand(
    Interaction<ApplicationCommandInteractionData> interaction,
    ApplicationCommand applicationCommand,
  ) {
    List<InteractionOption> options = interaction.data.options ?? [];
    ChatCommandComponent command = _chatCommands[applicationCommand.name]!;

    while (command is! ChatCommand) {
      assert(options.isNotEmpty);

      final subcommandOption = options.single;

      options = subcommandOption.options ?? [];
      command = command.children.singleWhere((element) => element.name == subcommandOption.name);
    }

    return (command, options);
  }

  @override
  void beforeClose(NyxxGateway client) {
    registeredCommands.removeWhere((command) => command.manager.client == client);
    _attachedClients.remove(client);
  }

  Future<void> _syncCommands(NyxxGateway client) async {
    final builders = await _buildCommands();

    final commands = await Future.wait(builders.entries.map(
      (e) => e.key == null
          ? client.commands.bulkOverride(e.value)
          : client.guilds[e.key!].commands.bulkOverride(e.value),
    ));

    registeredCommands.addAll(commands.expand((_) => _));

    logger.info('Synced ${builders.values.fold(0, (p, e) => p + e.length)} commands to Discord');
  }

  Future<Map<Snowflake?, List<ApplicationCommandBuilder>>> _buildCommands() async {
    final result = <Snowflake?, List<ApplicationCommandBuilder>>{null: []};

    for (final command in children) {
      final shouldRegister = command is! ChatCommandComponent ||
          command.hasSlashCommand ||
          (command is ChatCommand && command.resolvedOptions.type != CommandType.textOnly);
      if (!shouldRegister) {
        continue;
      }

      final checks = Check.all(command.checks);

      final ApplicationCommandType type;
      final String? description;
      final Map<Locale, String>? localizedDescriptions;
      final List<CommandOptionBuilder>? options;

      switch (command) {
        case ChatCommandComponent():
          type = ApplicationCommandType.chatInput;
          description = command.description;
          localizedDescriptions = command.localizedDescriptions;
          options = command.getOptions(this);
        case MessageCommand():
          type = ApplicationCommandType.message;
          description = null;
          localizedDescriptions = null;
          options = null;
        case UserCommand():
          type = ApplicationCommandType.user;
          description = null;
          localizedDescriptions = null;
          options = null;
        case _:
          throw CommandsError('Unknown command type ${command.runtimeType}');
      }

      final builder = ApplicationCommandBuilder(
        type: type,
        name: command.name,
        nameLocalizations: command.localizedNames,
        description: description,
        descriptionLocalizations: localizedDescriptions,
        options: options,
        defaultMemberPermissions: await checks.requiredPermissions,
        hasDmPermission: await checks.allowsDm,
      );

      final guildChecks = command.checks.whereType<GuildCheck>();

      if (guildChecks.length > 1) {
        throw CommandsError('Cannot have more than one GuildCheck per command');
      }

      final guilds = guildChecks.singleOrNull?.guildIds ?? [guild];
      for (final id in guilds) {
        (result[id] ??= []).add(builder);
      }
    }

    return result;
  }

  /// Adds a converter to this [CommandsPlugin].
  ///
  /// Converters can be used to convert user input ([String]s) to the type required by the command's
  /// callback function.
  ///
  /// See the [Converter] docs for more info.
  ///
  /// You might also be interested in:
  /// - [Converter], for creating your own converters;
  /// - [registerDefaultConverters], for adding the default converters to a [CommandsPlugin];
  /// - [getConverter], for retrieving the [Converter] for a specific type.
  void addConverter<T>(Converter<T> converter) {
    RuntimeType<T> type = converter.output;

    // If we were given a type argument, use that as the target type.
    // We're guaranteed by type safety that [converter] will be a subtype
    // of Converter<T>, so we can assume that the provided type argument
    // is compatible with the converter.
    if (T != dynamic) {
      type = RuntimeType<T>();
    }

    _converters[type] = converter;
  }

  /// Gets a [Converter] for a specific type.
  ///
  /// If no converter has been registered for that type, nyxx_commands will try to find existing
  /// converters that can also convert that type. For example, a `Converter<String>` would be able
  /// to convert to `Object`s. Converters created like this are known as *assembled converters* and
  /// will log a warning when used by default.
  ///
  /// You might also be interested in:
  /// - [addConverter], for adding converters to this [CommandsPlugin].
  Converter<T>? getConverter<T>(RuntimeType<T> type, {bool logWarn = true}) {
    if (_converters.containsKey(type)) {
      return _converters[type]! as Converter<T>;
    }

    List<Converter<T>> assignable = [];
    List<Converter<dynamic>> superTypes = [];

    for (final key in _converters.keys) {
      if (key.isSubtypeOf(type)) {
        assignable.add(_converters[key]! as Converter<T>);
      } else if (key.isSupertypeOf(type)) {
        superTypes.add(_converters[key]!);
      }
    }

    for (final converter in superTypes) {
      // Converters for types that superclass the target type might return an instance of the
      // target type.
      assignable.add(CombineConverter(converter, (superInstance, context) {
        if (superInstance.isOfType(type)) {
          return superInstance as T;
        }

        return null;
      }));
    }

    if (assignable.isNotEmpty) {
      if (logWarn) {
        logger.warning(
          'Using assembled converter for type ${type.internalType}. If this is intentional, you '
          'should register a custom converter for that type using '
          '`addConverter(getConverter(RuntimeType<${type.internalType}>(), logWarn: false))`',
        );
      }
      return FallbackConverter(assignable);
    }
    return null;
  }

  bool _scheduledSync = false;

  @override
  void addCommand(CommandRegisterable<CommandContext> command) {
    if (_attachedClients.isNotEmpty && !_scheduledSync) {
      _scheduledSync = true;
      scheduleMicrotask(() {
        logger.warning(
          'Registering commands after bot is ready might trigger rate limits when syncing commands',
        );
        _attachedClients.forEach(_syncCommands);
        _scheduledSync = false;
      });
    }

    command.parent = this;

    command.onPreCall.listen(_onPreCallController.add);
    command.onPostCall.listen(_onPostCallController.add);

    if (command is ChatCommandComponent) {
      if (_chatCommands.containsKey(command.name)) {
        throw CommandRegistrationError('Command with name "${command.name}" already exists');
      }

      for (final alias in command.aliases) {
        if (_chatCommands.containsKey(alias)) {
          throw CommandRegistrationError('Command with alias "$alias" already exists');
        }
      }

      _chatCommands[command.name] = command;
      for (final alias in command.aliases) {
        _chatCommands[alias] = command;
      }

      for (final child in command.walkCommands()) {
        logger.info('Registered command "${child.fullName}"');
      }
    } else if (command is UserCommand) {
      if (_userCommands.containsKey(command.name)) {
        throw CommandRegistrationError('User Command with name "${command.name}" already exists');
      }

      _userCommands[command.name] = command;

      logger.info('Registered User Command "${command.name}"');
    } else if (command is MessageCommand) {
      if (_messageCommands.containsKey(command.name)) {
        throw CommandRegistrationError(
            'Message Command with name "${command.name}" already exists');
      }

      _messageCommands[command.name] = command;

      logger.info('Registered Message Command "${command.name}"');
    } else {
      logger.warning('Unknown command type "${command.runtimeType}"');
    }
  }

  @override
  ChatCommand? getCommand(StringView view) => getCommandHelper(view, _chatCommands);

  @override
  Iterable<Command> walkCommands() sync* {
    yield* _userCommands.values;
    yield* _messageCommands.values;

    for (final command in Set.of(_chatCommands.values)) {
      yield* command.walkCommands();
    }
  }

  @override
  void check(AbstractCheck check) {
    checks.add(check);

    for (final preCallHook in check.preCallHooks) {
      onPreCall.listen(preCallHook);
    }

    for (final postCallHook in check.postCallHooks) {
      onPostCall.listen(postCallHook);
    }
  }

  @override
  String toString() =>
      'CommandsPlugin[commands=${List.of(walkCommands())}, converters=${List.of(_converters.values)}]';
}
