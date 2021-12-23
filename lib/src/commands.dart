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

import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'checks.dart';
import 'command.dart';
import 'context.dart';
import 'converter.dart';
import 'errors.dart';
import 'group.dart';
import 'view.dart';

/// Optional commands options.
class CommandsOptions {
  /// Whether to log [CommandsException]s that occur when received from
  /// [CommandsPlugin.onCommandError].
  final bool logErrors;

  /// Whether to automatically acknowledge slash command interactions if they are not acknowledged
  /// or responded to within 2s of command invocation.
  ///
  /// If you set this to false, you *must* respond to the interaction yourself, or the command will fail.
  final bool autoAcknowledgeInteractions;

  /// Whether to process commands coming from bot users on Discord.
  final bool acceptBotCommands;

  /// Whether to process commands coming from the bot's own user.
  ///
  /// Setting this to `true` might result in infinite loops.
  /// [acceptBotCommands] must also be set to true for this to have any effect.
  final bool acceptSelfCommands;

  /// A custom [InteractionBackend] to use when creating the [IInteractions] instance.
  final InteractionBackend? backend;

  /// Whether to set the EPHEMERAL flag in the original response to interaction events.
  ///
  /// This only has an effect is [autoAcknowledgeInteractions] is set to `true`.
  final bool hideOriginalResponse;

  /// Create a new [CommandsOptions] instance.
  const CommandsOptions({
    this.logErrors = true,
    this.autoAcknowledgeInteractions = true,
    this.acceptBotCommands = false,
    this.acceptSelfCommands = false,
    this.backend,
    this.hideOriginalResponse = true,
  });
}

/// The base plugin class. This is used to listen to and register commands.
///
/// Note that although this class uses [GroupMixin], attempting to access [name], [description],
/// [aliases] or any operation dependant on these will result in an [UnsupportedError] being thrown.
class CommandsPlugin extends BasePlugin with GroupMixin {
  /// This bot's prefix function
  final String Function(IMessage) prefix;

  final StreamController<CommandsException> _onCommandErrorController =
      StreamController.broadcast();

  /// A [Stream] of exceptions that occur when processing [Command]s
  late final Stream<CommandsException> onCommandError = _onCommandErrorController.stream;

  final Map<Type, Converter<dynamic>> _converters = {};

  /// The [IInteractions] instance that this bot uses for managing slash commands.
  late final IInteractions interactions;

  /// The options for this [CommandsPlugin] instance.
  late final CommandsOptions options;

  final Logger _commandsLogger = Logger('Commands');

  /// The guild that registered commands will be restricted to. Use for testing, and disable when
  /// deploying the bot.
  Snowflake? guild;

  /// The [INyxx] client this plugin is registered on
  INyxx? client;

  @override
  String get name => throw UnsupportedError('get name');
  @override
  String get description => throw UnsupportedError('get description');
  @override
  Iterable<String> get aliases => throw UnsupportedError('get aliases');

  /// Create a new [CommandsPlugin] instance.
  CommandsPlugin({
    required this.prefix,
    this.guild,
    this.options = const CommandsOptions(),
  }) {
    registerDefaultConverters(this);

    if (options.logErrors) {
      onCommandError.listen((error) {
        _commandsLogger
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
      for (final builder in await _getSlashBuilders()) {
        interactions.registerSlashCommand(builder);
      }

      interactions.sync();
    } else {
      nyxx.onReady.listen((event) async {
        for (final builder in await _getSlashBuilders()) {
          interactions.registerSlashCommand(builder);
        }

        interactions.sync();
      });
    }
  }

  Future<void> _processMessage(IMessage message) async {
    if (message.author.bot && !options.acceptBotCommands) {
      return;
    }

    if (message.author.id == (client as INyxxRest).self.id && !options.acceptSelfCommands) {
      return;
    }

    try {
      String prefix = this.prefix(message);
      StringView view = StringView(message.content);

      if (view.skipString(prefix)) {
        Context context = await _messageContext(message, view, prefix);

        _commandsLogger.fine('Invoking command ${context.command.name} from message $message');

        await context.command.invoke(this, context);
      }
    } on CommandsException catch (e) {
      _onCommandErrorController.add(e);
    }
  }

  Future<void> _processInteraction(
    ISlashCommandInteractionEvent interactionEvent,
    Command command,
  ) async {
    try {
      if (options.autoAcknowledgeInteractions) {
        Timer(Duration(seconds: 2), () async {
          try {
            await interactionEvent.acknowledge(hidden: options.hideOriginalResponse);
          } on AlreadyRespondedError {
            // ignore: command has responded itself
          }
        });
      }

      Context context = await _interactionContext(interactionEvent, command);

      _commandsLogger.fine('Invoking command ${context.command.name} '
          'from interaction ${interactionEvent.interaction.token}');

      await context.command.invoke(this, context);
    } on CommandsException catch (e) {
      _onCommandErrorController.add(e);
    }
  }

  Future<Context> _messageContext(IMessage message, StringView contentView, String prefix) async {
    Command command = getCommand(contentView) ?? (throw CommandNotFoundException(contentView));

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

    return MessageContext(
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

  Future<Context> _interactionContext(
      ISlashCommandInteractionEvent interactionEvent, Command command) async {
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

    return InteractionContext(
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

  Future<Iterable<SlashCommandBuilder>> _getSlashBuilders() async {
    List<SlashCommandBuilder> builders = [];

    for (final child in children) {
      if (child.hasSlashCommand || (child is Command && child.type != CommandType.textOnly)) {
        Map<Snowflake, CommandPermissionBuilderAbstract> uniquePermissions = {};

        for (final check in child.checks) {
          Iterable<CommandPermissionBuilderAbstract> checkPermissions = await check.permissions;

          for (final permission in checkPermissions) {
            if (uniquePermissions.containsKey(permission.id) &&
                uniquePermissions[permission.id]!.hasPermission != permission.hasPermission) {
              _commandsLogger.warning(
                'Check "${check.name}" is in conflict with a previous check on '
                'permissions for '
                '${permission.id.id == 0 ? 'the default permission' : 'id ${permission.id}'}. '
                'Permission has been set to false to prevent unintended usage.',
              );

              if (permission is RoleCommandPermissionBuilder) {
                uniquePermissions[permission.id] =
                    CommandPermissionBuilderAbstract.role(permission.id, hasPermission: false);
              } else {
                uniquePermissions[permission.id] =
                    CommandPermissionBuilderAbstract.user(permission.id, hasPermission: false);
              }

              continue;
            }

            uniquePermissions[permission.id] = permission;
          }
        }

        if (uniquePermissions.length == 1 && uniquePermissions.containsKey(Snowflake.zero())) {
          if (uniquePermissions[Snowflake.zero()]!.hasPermission == false) {
            continue;
          }
        }

        Iterable<GuildCheck> guilds = child.checks.whereType<GuildCheck>();

        if (guilds.length > 1) {
          throw Exception('Cannot have more than one Guild Check per Command');
        }

        Iterable<Snowflake?> guildIds = guilds.isNotEmpty ? guilds.first.guildIds : [null];

        for (final guildId in guildIds) {
          SlashCommandBuilder builder = SlashCommandBuilder(
            child.name,
            child.description,
            List.of(
              _processHandlerRegistration(child.getOptions(this), child),
            ),
            defaultPermissions: uniquePermissions[Snowflake.zero()]?.hasPermission ?? true,
            permissions: List.of(
              uniquePermissions.values.where((permission) => permission.id != Snowflake.zero()),
            ),
            guild: guildId ?? guild,
          );

          if (child is Command) {
            builder.registerHandler((interaction) => _processInteraction(interaction, child));
          }

          builders.add(builder);
        }
      }
    }

    return builders;
  }

  Iterable<CommandOptionBuilder> _processHandlerRegistration(
    Iterable<CommandOptionBuilder> options,
    GroupMixin current,
  ) {
    for (final builder in options) {
      if (builder.type == CommandOptionType.subCommand) {
        builder.registerHandler((interaction) =>
            _processInteraction(interaction, current.childrenMap[builder.name] as Command));
      } else if (builder.type == CommandOptionType.subCommandGroup) {
        _processHandlerRegistration(builder.options!, current.childrenMap[builder.name]!);
      }
    }
    return options;
  }

  /// Add a [Converter] to this bot.
  void addConverter<T>(Converter<T> converter) {
    _converters[T] = converter;
  }

  /// If it exists, get the [Converter] for a given type.
  ///
  /// If no direct converter for the specified [Type] is found, a [FallbackConverter] will be
  /// assebled with all converters that might be able to provide the requested type indirectly.
  ///
  /// If [logWarn] is `true`, a warning will be issued when using an assembled converter.
  Converter<dynamic>? converterFor(Type type, {bool logWarn = true}) {
    if (_converters.containsKey(type)) {
      return _converters[type]!;
    }

    TypeMirror targetMirror = reflectType(type);

    List<Converter<dynamic>> assignable = [];
    List<Converter<dynamic>> superClasses = [];

    for (final key in _converters.keys) {
      TypeMirror keyMirror = reflectType(key);

      if (keyMirror.isAssignableTo(targetMirror)) {
        assignable.add(_converters[key]!);
      } else if (targetMirror.isAssignableTo(keyMirror)) {
        superClasses.add(_converters[key]!);
      }
    }

    for (final converter in superClasses) {
      // Converters for types that superclass the target type might return an instance of the
      // target type.
      assignable.add(CombineConverter(converter, (superInstance, context) {
        if (reflect(superInstance).type.isAssignableTo(targetMirror)) {
          return superInstance;
        }
        return null;
      }));
    }

    if (assignable.isNotEmpty) {
      if (logWarn) {
        _commandsLogger
            .warning('Using assembled converter for type $type. If this is intentional, you '
                'should register a custom converter for that type using '
                '`addConverter(converterFor($type, logWarn: false) as Converter<$type>)`');
      }
      return FallbackConverter(assignable);
    }
    return null;
  }

  @override
  void registerChild(GroupMixin child) {
    super.registerChild(child);

    if (client?.ready ?? false) {
      _commandsLogger
          .warning('Registering commands after bot is ready might cause global commands to be '
              'deleted');
      interactions.sync();
    }

    for (final command in child.walkCommands()) {
      _commandsLogger.info('Registered command "${command.fullName}"');
    }
  }

  @override
  String toString() =>
      'CommandsPlugin[commands=${List.of(walkCommands())}, converters=${List.of(_converters.values)}]';
}
