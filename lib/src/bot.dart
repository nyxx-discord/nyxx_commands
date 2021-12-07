part of nyxx_commands;

/// Optional bot and client settings.
class BotOptions extends ClientOptions {
  /// Whether to log [CommandsException]s that occur when received from [Bot.onCommandError].
  bool logErrors;

  /// Whether to automatically acknowledge slash command interactions upon receiving them. If you
  /// set this to false, you *must* respond to the interaction yourself, or the command will fail.
  bool autoAcknowledgeInteractions;

  /// Create a new [BotOptions] instance.
  BotOptions({
    AllowedMentions? allowedMentions,
    int? shardCount,
    int messageCacheSize = 100,
    int largeThreshold = 50,
    bool compressedGatewayPayloads = true,
    bool guildSubscriptions = true,
    PresenceBuilder? initialPresence,
    ShutdownHook? shutdownHook,
    ShutdownShardHook? shutdownShardHook,
    bool dispatchRawShardEvent = false,
    this.logErrors = true,
    this.autoAcknowledgeInteractions = true,
  }) : super(
          allowedMentions: allowedMentions,
          shardCount: shardCount,
          messageCacheSize: messageCacheSize,
          largeThreshold: largeThreshold,
          compressedGatewayPayloads: compressedGatewayPayloads,
          guildSubscriptions: guildSubscriptions,
          initialPresence: initialPresence,
          shutdownHook: shutdownHook,
          shutdownShardHook: shutdownShardHook,
          dispatchRawShardEvent: dispatchRawShardEvent,
        );
}

/// The base bot class. This is used to listen to and register commands.
///
/// Extends [Nyxx] so you can use this as you would any other Nyxx client.
///
/// Note that although this class uses [GroupMixin], attempting to access [name], [description],
/// [aliases] or any operation dependant on these will result in an [UnsupportedError] being thrown.
class Bot extends Nyxx with GroupMixin {
  final String Function(Message) _prefixFor;

  final StreamController<CommandsException> _onCommandErrorController =
      StreamController.broadcast();

  /// A [Stream] of exceptions that occur when processing [Command]s
  late final Stream<CommandsException> onCommandError = _onCommandErrorController.stream;

  final Map<Type, Converter> _converters = {};

  /// The [Interactions] instance that this bot uses for managing slash commands.
  late final Interactions interactions;

  late final BotOptions _options = options as BotOptions;

  final Logger _commandsLogger = Logger('Commands');

  /// The guild that registered commands will be restricted to. Use for testing, and disable when
  /// deploying the bot.
  Snowflake? guild;

  @override
  String get name => throw UnsupportedError('get name');
  @override
  String get description => throw UnsupportedError('get description');
  @override
  Iterable<String> get aliases => throw UnsupportedError('get aliases');

  /// Create a new [Bot] instance.
  Bot(
    String token,
    int intents, {
    String? prefix,
    String Function(Message)? prefixFunction,
    this.guild,
    BotOptions? options,
    CacheOptions? cacheOptions,
    bool ignoreExceptions = true,
    bool useDefaultLogger = true,
  })  : _prefixFor = (prefixFunction ?? (m) => prefix!),
        super(
          token,
          intents,
          options: options ?? BotOptions(),
          cacheOptions: cacheOptions,
          ignoreExceptions: ignoreExceptions,
          useDefaultLogger: useDefaultLogger,
        ) {
    if ((prefix ?? prefixFunction) == null) {
      throw CommandsError('At least one of prefix or prefixFunction must be set');
    }

    if (prefix != null && prefixFunction != null) {
      throw CommandsError('At most one of prefix and prefixFunction can be set at once');
    }

    registerDefaultConverters(this);

    onMessageReceived.listen((event) => _processMessage(event.message));

    if (_options.logErrors) {
      onCommandError.listen((error) {
        _commandsLogger
          ..warning('Uncaught exception in command')
          ..shout(error);
      });
    }

    onReady.listen((event) async {
      for (final builder in await _getSlashBuilders()) {
        interactions.registerSlashCommand(builder);
      }

      interactions.sync();
    });

    // Interactions expects to be instanciated before onReady is dispatched.
    interactions = Interactions(this);
  }

  Future<void> _processMessage(Message message) async {
    try {
      String prefix = _prefixFor(message);
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
    SlashCommandInteractionEvent interactionEvent,
    Command command,
  ) async {
    try {
      if (_options.autoAcknowledgeInteractions) {
        await interactionEvent.acknowledge();
      }

      Context context = await _interactionContext(interactionEvent, command);

      _commandsLogger.fine('Invoking command ${context.command.name} '
          'from interaction ${interactionEvent.interaction.token}');

      await context.command.invoke(this, context);
    } on CommandsException catch (e) {
      _onCommandErrorController.add(e);
    }
  }

  Future<Context> _messageContext(Message message, StringView contentView, String prefix) async {
    Command command = getCommand(contentView) ?? (throw CommandNotFoundException(contentView));

    TextChannel channel = await message.channel.getOrDownload();

    Guild? guild;
    Member? member;
    User user;
    if (message is GuildMessage) {
      guild = await (channel as GuildChannel).guild.getOrDownload();

      member = message.member;
      user = await member.user.getOrDownload();
    } else {
      user = message.author as User;
    }

    return MessageContext(
      bot: this,
      guild: guild,
      channel: channel,
      member: member,
      user: user,
      command: command,
      prefix: prefix,
      message: message,
      rawArguments: contentView.remaining,
    );
  }

  Future<Context> _interactionContext(
      SlashCommandInteractionEvent interactionEvent, Command command) async {
    SlashCommandInteraction interaction = interactionEvent.interaction;

    Member? member = interaction.memberAuthor;
    User user;
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
      bot: this,
      guild: await interaction.guild?.getOrDownload(),
      channel: await interaction.channel.getOrDownload(),
      member: member,
      user: user,
      command: command,
      interaction: interaction,
      rawArguments: rawArguments,
      interactionEvent: interactionEvent,
    );
  }

  Future<Iterable<SlashCommandBuilder>> _getSlashBuilders() async {
    List<SlashCommandBuilder> builders = [];

    for (final child in children) {
      if (child.hasSlashCommand || (child is Command && child.type != CommandType.textOnly)) {
        Map<Snowflake, ICommandPermissionBuilder> uniquePermissions = {};

        for (final check in child.checks) {
          Iterable<ICommandPermissionBuilder> checkPermissions = await check.permissions;

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
                    ICommandPermissionBuilder.role(permission.id, hasPermission: false);
              } else {
                uniquePermissions[permission.id] =
                    ICommandPermissionBuilder.user(permission.id, hasPermission: false);
              }

              continue;
            }

            uniquePermissions[permission.id] = permission;
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
  Converter? converterFor(Type type, {bool logWarn = true}) {
    if (_converters.containsKey(type)) {
      return _converters[type]!;
    }

    TypeMirror targetMirror = reflectType(type);

    List<Converter> assignable = [];
    List<Converter> superClasses = [];

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
                '`bot.addConverter(bot.converterFor($type, logWarn: false) as Converter<$type>)`');
      }
      return FallbackConverter(assignable);
    }
    return null;
  }

  @override
  void registerChild(GroupMixin child) {
    super.registerChild(child);

    if (super.ready) {
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
      'Bot[commands=${List.of(walkCommands())}, converters=${List.of(_converters.values)}]';
}
