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
import 'package:nyxx_commands/src/options.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'checks/checks.dart';
import 'commands/slash_command.dart';
import 'commands/group.dart';
import 'context/context.dart';
import 'converters/converter.dart';
import 'errors.dart';
import 'util/view.dart';

/// The base plugin class. Add this to your [INyxx] instance with [INyxx.registerPlugin] to use
/// `nyxx_commands`.
///
/// Although this class mixes [GroupMixin], not all properties of [GroupMixin] are availible and
/// will throw an [UnsupportedError] upon being accessed or called.
abstract class CommandsPlugin extends BasePlugin with GroupMixin {
  /// The current prefix for this [CommandsPlugin].
  ///
  /// This is called for each message sent in any of [client]'s Guilds or Direct Messages to
  /// determine the prefix that message has to match to be parsed and interpreted as a command.
  String Function(IMessage) get prefix;

  /// A [Stream] of [CommandsException]s that are emitted during execution of a command.
  Stream<CommandsException> get onCommandError;

  /// The [IInteractions] instance that this [CommandsPlugin] uses to manage commands.
  ///
  /// Use this instance if you wish to use `nyxx_interactions` features along with `nyxx_commands`.
  /// This instance's [IInteractions.sync] is called automatically when [client] is ready, so there
  /// is no need to call it yourself.
  IInteractions get interactions;

  /// The options this [CommandsPlugin] uses.
  CommandsOptions get options;

  /// The guild for this [CommandsPlugin]. Unless a guild override is present (using [GuildCheck]),
  /// all commands registered by this bot will be registered in this guild.
  ///
  /// This does not prevent commands from being executed from elsewhere and should only be used for
  /// testing. Set to `null` to register commands globally.
  Snowflake? get guild;

  /// The client that this [CommandsPlugin] was added to.
  INyxx? get client;

  /// Add a [Converter] to this [CommandsPlugin]'s converters.
  void addConverter<T>(Converter<T> converter);

  /// Get the converter for a given [Type].
  ///
  /// If no converter registered with [addConverter] or present in the default converter set can be
  /// used to parse arguments of type [target], a new [Converter] will be created with all the
  /// converters thhat *might* convert to [target].
  ///
  /// If this occurs and [logWarn] is set to false, a warning will be issued.
  Converter<dynamic>? getConverter(Type target, {bool logWarn = false});

  /// Create a new instance of [CommandsPlugin] to be used as a plugin on [INyxx] instances.
  factory CommandsPlugin({
    required String Function(IMessage) prefix,
    Snowflake? guild,
    CommandsOptions options = const CommandsOptions(),
  }) =>
      CommandsPluginImpl(prefix: prefix, guild: guild, options: options);
}

class CommandsPluginImpl extends BasePlugin with GroupMixin implements CommandsPlugin {
  @override
  final String Function(IMessage) prefix;

  final StreamController<CommandsException> _onCommandErrorController =
      StreamController.broadcast();

  @override
  late final Stream<CommandsException> onCommandError = _onCommandErrorController.stream;

  final Map<Type, Converter<dynamic>> _converters = {};

  @override
  late final IInteractions interactions;

  @override
  final CommandsOptions options;

  final Logger _commandsLogger = Logger('Commands');

  @override
  Snowflake? guild;

  @override
  INyxx? client;

  @override
  String get name => throw UnsupportedError('get name');
  @override
  String get description => throw UnsupportedError('get description');
  @override
  Iterable<String> get aliases => throw UnsupportedError('get aliases');

  CommandsPluginImpl({
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
    SlashCommand command,
  ) async {
    try {
      Context context = await _interactionContext(interactionEvent, command);

      if (options.autoAcknowledgeInteractions) {
        Timer(Duration(seconds: 2), () async {
          try {
            await interactionEvent.acknowledge(
              hidden: context.command.hideOriginalResponse ?? options.hideOriginalResponse,
            );
          } on AlreadyRespondedError {
            // ignore: command has responded itself
          }
        });
      }

      _commandsLogger.fine('Invoking command ${context.command.name} '
          'from interaction ${interactionEvent.interaction.token}');

      await context.command.invoke(this, context);
    } on CommandsException catch (e) {
      _onCommandErrorController.add(e);
    }
  }

  Future<Context> _messageContext(IMessage message, StringView contentView, String prefix) async {
    SlashCommand command = getCommand(contentView) ?? (throw CommandNotFoundException(contentView));

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
      ISlashCommandInteractionEvent interactionEvent, SlashCommand command) async {
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
      if (child.hasSlashCommand || (child is SlashCommand && child.type != CommandType.textOnly)) {
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

          if (child is SlashCommand) {
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
            _processInteraction(interaction, current.childrenMap[builder.name] as SlashCommand));
      } else if (builder.type == CommandOptionType.subCommandGroup) {
        _processHandlerRegistration(builder.options!, current.childrenMap[builder.name]!);
      }
    }
    return options;
  }

  @override
  void addConverter<T>(Converter<T> converter) {
    _converters[T] = converter;
  }

  @override
  Converter<dynamic>? getConverter(Type type, {bool logWarn = true}) {
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
  void addCommand(GroupMixin command) {
    super.addCommand(command);

    if (client?.ready ?? false) {
      _commandsLogger
          .warning('Registering commands after bot is ready might cause global commands to be '
              'deleted');
      interactions.sync();
    }

    for (final child in command.walkCommands()) {
      _commandsLogger.info('Registered command "${child.fullName}"');
    }
  }

  @override
  String toString() =>
      'CommandsPlugin[commands=${List.of(walkCommands())}, converters=${List.of(_converters.values)}]';
}
