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

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'checks/checks.dart';
import 'checks/guild.dart';
import 'commands/chat_command.dart';
import 'commands/interfaces.dart';
import 'commands/message_command.dart';
import 'commands/user_command.dart';
import 'context/chat_context.dart';
import 'context/autocomplete_context.dart';
import 'context/context.dart';
import 'context/message_context.dart';
import 'context/user_context.dart';
import 'converters/converter.dart';
import 'errors.dart';
import 'mirror_utils/mirror_utils.dart';
import 'options.dart';
import 'util/util.dart';
import 'util/view.dart';

final Logger logger = Logger('Commands');

/// The base plugin used to interact with nyxx_commands.
///
/// Since nyxx 3.0.0, classes can extend [BasePlugin] and be registered as plugins to an existing
/// nyxx client by calling [INyxx.registerPlugin]. nyxx_commands uses that interface, which avoids
/// the need for a seperate wrapper class.
///
/// Commands can be added to nyxx_commands with the [addCommand] method. Once you've added the
/// [CommandsPlugin] to your nyxx client, these commands will automatically become available once
/// the client is ready.
///
/// The [CommandsPlugin] will automatically subscribe to all the event streams it needs, as well as
/// create its own instance of [IInteractions] for using slash commands. If you want to access this
/// instance for your own use, it is available through the [interactions] getter.
///
/// For example, here is how you would create and register [CommandsPlugin]:
/// ```dart
/// INyxxWebsocket client = NyxxFactory.createNyxxWebsocket(...);
///
/// CommandsPlugin commands = CommandsPlugin(
///   prefix: (_) => '!',
/// );
///
/// client.registerPlugin(commands);
/// client.connect();
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
class CommandsPlugin extends BasePlugin implements ICommandGroup<IContext> {
  /// A function called to determine the prefix for a specific message.
  ///
  /// This function should return a [String] representing the prefix to use for a given message.
  ///
  /// For example, for a prefix of `!`:
  /// ```dart
  /// (_) => '!'
  /// ```
  ///
  /// Or, for either `!` or `$` as a prefix:
  /// ```dart
  /// (message) => message.content.startsWith('!') ? '!' : '$'
  /// ```
  ///
  /// You might also be interested in:
  /// - [dmOr], which allows for commands in private messages to omit the prefix;
  /// - [mentionOr], which allows for commands to be executed with the client's mention (ping).
  final String Function(IMessage) prefix;

  final StreamController<CommandsException> _onCommandErrorController =
      StreamController.broadcast();
  final StreamController<IContext> _onPreCallController = StreamController.broadcast();
  final StreamController<IContext> _onPostCallController = StreamController.broadcast();

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
  /// By default, nyxx_commands logs all exceptions added to this stream. This behaviour can be
  /// changed in [options].
  ///
  /// You might also be interested in:
  /// - [CommandsException], the class all exceptions in nyxx_commands subclass;
  /// - [ICallHooked.onPostCall], a stream that emits [IContext]s once a command completes
  /// successfully.
  late final Stream<CommandsException> onCommandError = _onCommandErrorController.stream;

  @override
  late final Stream<IContext> onPreCall = _onPreCallController.stream;

  @override
  late final Stream<IContext> onPostCall = _onPostCallController.stream;

  final Map<Type, Converter<dynamic>> _converters = {};

  /// The [IInteractions] instance used by this [CommandsPlugin].
  ///
  /// [IInteractions] is the backend for the [Discord Application Command API](https://discord.com/developers/docs/interactions/application-commands)
  /// and is used by nyxx_commands to register and handle slash commands.
  ///
  /// Because [IInteractions] also allows you to use [Message Components](https://discord.com/developers/docs/interactions/message-components),
  /// developers might need to use this instance of [IInteractions]. It is not recommended to create
  /// your own instance alongside nyxx_commands as that might result in commands being deleted.
  late final IInteractions interactions;

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

  /// The client this [CommandsPlugin] instance is attached to.
  ///
  /// Will be `null` if the plugin has not been added to a client.
  ///
  /// You might also be interested in:
  /// - [INyxx.registerPlugin], for adding plugins to clients.
  INyxx? client;

  @override
  final List<AbstractCheck> checks = [];

  final Map<String, UserCommand> _userCommands = {};
  final Map<String, MessageCommand> _messageCommands = {};
  final Map<String, IChatCommandComponent> _chatCommands = {};

  @override
  Iterable<ICommandRegisterable> get children =>
      {..._userCommands.values, ..._messageCommands.values, ..._chatCommands.values};

  /// Create a new [CommandsPlugin].
  ///
  /// Note that the plugin must then be added to a nyxx client with [INyxx.registerPlugin] before it
  /// can be used.
  CommandsPlugin({
    required this.prefix,
    this.guild,
    this.options = const CommandsOptions(),
  }) {
    registerDefaultConverters(this);

    if (options.logErrors) {
      onCommandError.listen((error) {
        logger
          ..warning('Uncaught exception in command')
          ..shout(error);
      });
    }
  }

  @override
  void onRegister(INyxx nyxx, Logger logger) async {
    client = nyxx;

    if (nyxx is INyxxWebsocket) {
      nyxx.eventsWs.onMessageReceived.listen((event) => _processMessage(event.message));

      interactions = IInteractions.create(options.backend ?? WebsocketInteractionBackend(nyxx));
    } else {
      logger.warning('Commands was not intended for use without NyxxWebsocket.');

      throw CommandsError(
          'Cannot create the Interactions backend for non-websocket INyxx instances.');
    }

    if (nyxx.ready) {
      await _syncWithInteractions();
    } else {
      nyxx.onReady.listen((event) async {
        await _syncWithInteractions();
      });
    }
  }

  @override
  Future<void> onBotStop(INyxx nyxx, Logger logger) async {
    await _onPostCallController.close();
    await _onPreCallController.close();
    await _onCommandErrorController.close();
  }

  Future<void> _syncWithInteractions() async {
    for (final builder in await _getSlashBuilders()) {
      interactions.registerSlashCommand(builder);
    }

    interactions.sync(
        syncRule: ManualCommandSync(sync: client?.options.shardIds?.contains(0) ?? true));
  }

  Future<void> _processMessage(IMessage message) async {
    try {
      String prefix = this.prefix(message);
      StringView view = StringView(message.content);

      if (view.skipString(prefix)) {
        IChatContext context = await _messageChatContext(message, view, prefix);

        if (message.author.bot && !context.command.resolvedOptions.acceptBotCommands!) {
          return;
        }

        if (message.author.id == (client as INyxxRest).self.id &&
            !context.command.resolvedOptions.acceptSelfCommands!) {
          return;
        }

        logger.fine('Invoking command ${context.command.name} from message $message');

        await context.command.invoke(context);
      }
    } on CommandsException catch (e) {
      _onCommandErrorController.add(e);
    }
  }

  Future<void> _processChatInteraction(
    ISlashCommandInteractionEvent interactionEvent,
    ChatCommand command,
  ) async {
    try {
      IChatContext context = await _interactionChatContext(interactionEvent, command);

      if (context.command.resolvedOptions.autoAcknowledgeInteractions!) {
        Timer(Duration(seconds: 2), () async {
          try {
            await interactionEvent.acknowledge(
              hidden: context.command.resolvedOptions.hideOriginalResponse!,
            );
          } on AlreadyRespondedError {
            // ignore: command has responded itself
          }
        });
      }

      logger.fine('Invoking command ${context.command.name} '
          'from interaction ${interactionEvent.interaction.token}');

      await context.command.invoke(context);
    } on CommandsException catch (e) {
      _onCommandErrorController.add(e);
    }
  }

  Future<void> _processUserInteraction(
      ISlashCommandInteractionEvent interactionEvent, UserCommand command) async {
    try {
      UserContext context = await _interactionUserContext(interactionEvent, command);

      if (options.autoAcknowledgeInteractions) {
        Timer(Duration(seconds: 2), () async {
          try {
            await interactionEvent.acknowledge(
              hidden: options.hideOriginalResponse,
            );
          } on AlreadyRespondedError {
            // ignore: command has responded itself
          }
        });
      }

      logger.fine('Invoking command ${context.command.name} '
          'from interaction ${interactionEvent.interaction.token}');

      await context.command.invoke(context);
    } on CommandsException catch (e) {
      _onCommandErrorController.add(e);
    }
  }

  Future<void> _processMessageInteraction(
      ISlashCommandInteractionEvent interactionEvent, MessageCommand command) async {
    try {
      MessageContext context = await _interactionMessageContext(interactionEvent, command);

      if (options.autoAcknowledgeInteractions) {
        Timer(Duration(seconds: 2), () async {
          try {
            await interactionEvent.acknowledge(
              hidden: options.hideOriginalResponse,
            );
          } on AlreadyRespondedError {
            // ignore: command has responded itself
          }
        });
      }

      logger.fine('Invoking command ${context.command.name} '
          'from interaction ${interactionEvent.interaction.token}');

      await context.command.invoke(context);
    } on CommandsException catch (e) {
      _onCommandErrorController.add(e);
    }
  }

  Future<void> _processAutocompleteInteraction(
    IAutocompleteInteractionEvent interactionEvent,
    FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext) callback,
    ChatCommand command,
  ) async {
    try {
      AutocompleteContext context = await _autocompleteContext(interactionEvent, command);

      try {
        Iterable<ArgChoiceBuilder>? choices = await callback(context);

        if (choices != null) {
          interactionEvent.respond(choices.toList());
        }
      } on Exception catch (e) {
        throw AutocompleteFailedException(e, context);
      }
    } on CommandsException catch (e) {
      _onCommandErrorController.add(e);
    }
  }

  Future<IChatContext> _messageChatContext(
      IMessage message, StringView contentView, String prefix) async {
    ChatCommand command = getCommand(contentView) ?? (throw CommandNotFoundException(contentView));

    ITextChannel channel = await message.channel.getOrDownload();

    IGuild? guild;
    IMember? member;
    IUser user;
    if (message.guild != null) {
      guild = await message.guild!.getOrDownload();

      member = message.member;
      user = await member!.user.getOrDownload();
    } else {
      user = message.author as IUser;
    }

    return MessageChatContext(
      commands: this,
      guild: guild,
      channel: channel,
      member: member,
      user: user,
      command: command,
      client: client!,
      prefix: prefix,
      message: message,
      rawArguments: contentView.remaining,
    );
  }

  Future<IChatContext> _interactionChatContext(
      ISlashCommandInteractionEvent interactionEvent, ChatCommand command) async {
    ISlashCommandInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    Map<String, dynamic> rawArguments = <String, dynamic>{};

    for (final option in interactionEvent.args) {
      rawArguments[option.name] = option.value;
    }

    return InteractionChatContext(
      commands: this,
      guild: await interaction.guild?.getOrDownload(),
      channel: await interaction.channel.getOrDownload(),
      member: member,
      user: user,
      command: command,
      client: client!,
      interaction: interaction,
      rawArguments: rawArguments,
      interactionEvent: interactionEvent,
    );
  }

  Future<UserContext> _interactionUserContext(
      ISlashCommandInteractionEvent interactionEvent, UserCommand command) async {
    ISlashCommandInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    IUser targetUser = client!.users[interaction.targetId] ??
        await client!.httpEndpoints.fetchUser(interaction.targetId!);

    IGuild? guild = await interaction.guild?.getOrDownload();

    return UserContext(
      commands: this,
      client: client!,
      interactionEvent: interactionEvent,
      interaction: interaction,
      command: command,
      channel: await interaction.channel.getOrDownload(),
      member: member,
      user: user,
      guild: guild,
      targetUser: targetUser,
      targetMember: guild?.members[targetUser.id] ?? await guild?.fetchMember(targetUser.id),
    );
  }

  Future<MessageContext> _interactionMessageContext(
      ISlashCommandInteractionEvent interactionEvent, MessageCommand command) async {
    ISlashCommandInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    IGuild? guild = await interaction.guild?.getOrDownload();

    return MessageContext(
      commands: this,
      client: client!,
      interactionEvent: interactionEvent,
      interaction: interaction,
      command: command,
      channel: await interaction.channel.getOrDownload(),
      member: member,
      user: user,
      guild: guild,
      targetMessage: interaction.channel.getFromCache()!.messageCache[interaction.targetId] ??
          await interaction.channel.getFromCache()!.fetchMessage(interaction.targetId!),
    );
  }

  Future<AutocompleteContext> _autocompleteContext(
    IAutocompleteInteractionEvent interactionEvent,
    ChatCommand command,
  ) async {
    ISlashCommandInteraction interaction = interactionEvent.interaction;

    IMember? member = interaction.memberAuthor;
    IUser user;
    if (member != null) {
      user = await member.user.getOrDownload();
    } else {
      user = interaction.userAuthor!;
    }

    return AutocompleteContext(
      commands: this,
      guild: await interaction.guild?.getOrDownload(),
      channel: await interaction.channel.getOrDownload(),
      member: member,
      user: user,
      command: command,
      client: client!,
      interaction: interaction,
      interactionEvent: interactionEvent,
      option: interactionEvent.focusedOption,
      currentValue: interactionEvent.focusedOption.value.toString(),
    );
  }

  Future<Iterable<SlashCommandBuilder>> _getSlashBuilders() async {
    List<SlashCommandBuilder> builders = [];

    for (final command in children) {
      if (!_shouldGenerateBuildersFor(command)) {
        continue;
      }

      AbstractCheck allChecks = Check.all(command.checks);

      Iterable<GuildCheck> guildChecks = command.checks.whereType<GuildCheck>();

      if (guildChecks.length > 1) {
        throw Exception('Cannot have more than one Guild Check per Command');
      }

      Iterable<Snowflake?> guildIds = guildChecks.isNotEmpty ? guildChecks.first.guildIds : [null];

      for (final guildId in guildIds) {
        if (command is IChatCommandComponent) {
          SlashCommandBuilder builder = SlashCommandBuilder(
            command.name,
            command.description,
            List.of(
              _processHandlerRegistration(command.getOptions(this), command),
            ),
            canBeUsedInDm: await allChecks.allowsDm,
            requiredPermissions: await allChecks.requiredPermissions,
            guild: guildId ?? guild,
            type: SlashCommandType.chat,
          );

          if (command is ChatCommand && command.resolvedType != CommandType.textOnly) {
            builder.registerHandler((interaction) => _processChatInteraction(interaction, command));

            _processAutocompleteHandlerRegistration(builder.options, command);
          }

          builders.add(builder);
        } else if (command is UserCommand) {
          SlashCommandBuilder builder = SlashCommandBuilder(
            command.name,
            null,
            [],
            canBeUsedInDm: await allChecks.allowsDm,
            requiredPermissions: await allChecks.requiredPermissions,
            guild: guildId ?? guild,
            type: SlashCommandType.user,
          );

          builder.registerHandler((interaction) => _processUserInteraction(interaction, command));

          builders.add(builder);
        } else if (command is MessageCommand) {
          SlashCommandBuilder builder = SlashCommandBuilder(
            command.name,
            null,
            [],
            canBeUsedInDm: await allChecks.allowsDm,
            requiredPermissions: await allChecks.requiredPermissions,
            guild: guildId ?? guild,
            type: SlashCommandType.message,
          );

          builder
              .registerHandler((interaction) => _processMessageInteraction(interaction, command));

          builders.add(builder);
        }
      }
    }

    return builders;
  }

  bool _shouldGenerateBuildersFor(ICommandRegisterable<IContext> child) {
    if (child is IChatCommandComponent) {
      if (child.hasSlashCommand) {
        return true;
      }

      return child is ChatCommand && child.type != CommandType.textOnly;
    }

    return true;
  }

  Iterable<CommandOptionBuilder> _processHandlerRegistration(
    Iterable<CommandOptionBuilder> options,
    IChatCommandComponent current,
  ) {
    for (final builder in options) {
      if (builder.type == CommandOptionType.subCommand) {
        ChatCommand command =
            current.children.where((child) => child.name == builder.name).first as ChatCommand;

        builder.registerHandler((interaction) => _processChatInteraction(interaction, command));

        _processAutocompleteHandlerRegistration(builder.options!, command);
      } else if (builder.type == CommandOptionType.subCommandGroup) {
        _processHandlerRegistration(
          builder.options!,
          current.children.where((child) => child.name == builder.name).first
              as IChatCommandComponent,
        );
      }
    }
    return options;
  }

  void _processAutocompleteHandlerRegistration(
    Iterable<CommandOptionBuilder> options,
    ChatCommand command,
  ) {
    Iterator<CommandOptionBuilder> builderIterator = options.iterator;

    Iterable<ParameterData> parameters = loadFunctionData(command.execute)
        .parametersData
        // Skip context parameter
        .skip(1);

    Iterator<ParameterData> parameterIterator = parameters.iterator;

    while (builderIterator.moveNext() && parameterIterator.moveNext()) {
      Converter<dynamic>? converter = parameterIterator.current.converterOverride ??
          getConverter(parameterIterator.current.type);

      FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext)? autocompleteCallback =
          parameterIterator.current.autocompleteOverride ?? converter?.autocompleteCallback;

      if (autocompleteCallback != null) {
        builderIterator.current.registerAutocompleteHandler(
            (event) => _processAutocompleteInteraction(event, autocompleteCallback, command));
      }
    }
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
    _converters[T] = converter;
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
  Converter<dynamic>? getConverter(Type type, {bool logWarn = true}) {
    if (_converters.containsKey(type)) {
      return _converters[type]!;
    }

    List<Converter<dynamic>> assignable = [];
    List<Converter<dynamic>> superClasses = [];

    for (final key in _converters.keys) {
      if (isAssignableTo(key, type)) {
        assignable.add(_converters[key]!);
      } else if (isAssignableTo(type, key)) {
        superClasses.add(_converters[key]!);
      }
    }

    for (final converter in superClasses) {
      // Converters for types that superclass the target type might return an instance of the
      // target type.
      assignable.add(CombineConverter(converter, (superInstance, context) {
        if (isAssignableTo(superInstance.runtimeType, type)) {
          return superInstance;
        }
        return null;
      }));
    }

    if (assignable.isNotEmpty) {
      if (logWarn) {
        logger.warning('Using assembled converter for type $type. If this is intentional, you '
            'should register a custom converter for that type using '
            '`addConverter(getConverter($type, logWarn: false) as Converter<$type>)`');
      }
      return FallbackConverter(assignable);
    }
    return null;
  }

  @override
  void addCommand(ICommandRegisterable<IContext> command) {
    if (command is IChatCommandComponent) {
      if (_chatCommands.containsKey(command.name)) {
        throw CommandRegistrationError('Command with name "${command.name}" already exists');
      }

      for (final alias in command.aliases) {
        if (_chatCommands.containsKey(alias)) {
          throw CommandRegistrationError('Command with alias "$alias" already exists');
        }
      }

      command.parent = this;

      _chatCommands[command.name] = command;
      for (final alias in command.aliases) {
        _chatCommands[alias] = command;
      }

      for (final child in command.walkCommands() as Iterable<IChatCommandComponent>) {
        logger.info('Registered command "${child.fullName}"');
      }
    } else if (command is UserCommand) {
      if (_userCommands.containsKey(command.name)) {
        throw CommandRegistrationError('User Command with name "${command.name}" already exists');
      }

      _userCommands[command.name] = command;

      command.parent = this;

      logger.info('Registered User Command "${command.name}"');
    } else if (command is MessageCommand) {
      if (_messageCommands.containsKey(command.name)) {
        throw CommandRegistrationError(
            'Message Command with name "${command.name}" already exists');
      }

      _messageCommands[command.name] = command;

      command.parent = this;

      logger.info('Registered Message Command "${command.name}"');
    } else {
      logger.warning('Unknown command type "${command.runtimeType}"');
    }

    command.onPreCall.listen(_onPreCallController.add);
    command.onPostCall.listen(_onPostCallController.add);

    if (client?.ready ?? false) {
      logger.warning('Registering commands after bot is ready might cause global commands to be '
          'deleted');
      _syncWithInteractions();
    }
  }

  @override
  ChatCommand? getCommand(StringView view) {
    String name = view.getWord();

    if (_chatCommands.containsKey(name)) {
      IChatCommandComponent child = _chatCommands[name]!;

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
  Iterable<ICommand> walkCommands() sync* {
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
