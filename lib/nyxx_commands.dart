/// A framework for easily creating slash commands and text commands for Discord using the
/// [nyxx](https://pub.dev/packages/nyxx) library.
library nyxx_commands;

export 'src/checks.dart'
    show AbstractCheck, Check, GuildCheck, RoleCheck, UserCheck, CooldownCheck, CooldownType;
export 'src/command.dart' show Command, CommandType, commandNameRegexp;
export 'src/commands.dart' show CommandsPlugin, CommandsOptions;
export 'src/context.dart' show Context, InteractionContext, MessageContext;
export 'src/converter.dart'
    show
        Converter,
        CombineConverter,
        FallbackConverter,
        // ignore: deprecated_member_use_from_same_package
        discordTypes,
        boolConverter,
        categoryGuildChannelConverter,
        doubleConverter,
        guildChannelConverter,
        intConverter,
        memberConverter,
        mentionableConverter,
        roleConverter,
        snowflakeConverter,
        stageVoiceChannelConverter,
        stringConverter,
        textGuildChannelConverter,
        userConverter,
        voiceGuildChannelConverter,
        parse,
        registerDefaultConverters;
export 'src/errors.dart'
    show
        CommandsException,
        CommandsError,
        BadInputException,
        CheckFailedException,
        CommandInvocationException,
        CommandNotFoundException,
        CommandRegistrationError,
        NoConverterException,
        NotEnoughArgumentsException,
        ParsingException,
        UncaughtException;
export 'src/group.dart' show Group, GroupMixin;
export 'src/util.dart'
    show Choices, Description, Name, UseConverter, convertToKebabCase, mentionOr, dmOr;
export 'src/view.dart' show StringView;
