/// A framework for easily creating slash commands and text commands for Discord using the nyxx library.
library nyxx_commands;

export 'src/checks/checks.dart' show AbstractCheck, Check, GuildCheck, RoleCheck, UserCheck;
export 'src/checks/context_type.dart'
    show
        ChatCommandCheck,
        InteractionCommandCheck,
        InteractionChatCommandCheck,
        MessageChatCommandCheck,
        MessageCommandCheck,
        UserCommandCheck;
export 'src/checks/cooldown.dart' show CooldownCheck, CooldownType;
export 'src/commands.dart' show CommandsPlugin;
export 'src/commands/chat_command.dart' show ChatCommand, ChatGroup, CommandType;
export 'src/commands/interfaces.dart'
    show
        ICallHooked,
        IChatCommandComponent,
        IChecked,
        ICommand,
        ICommandGroup,
        ICommandRegisterable,
        IOptions;
export 'src/commands/message_command.dart' show MessageCommand;
export 'src/commands/options.dart' show CommandOptions;
export 'src/commands/user_command.dart' show UserCommand;
export 'src/context/autocomplete_context.dart' show AutocompleteContext;
export 'src/context/chat_context.dart'
    show IChatContext, InteractionChatContext, MessageChatContext;
export 'src/context/context.dart' show IContext, IContextBase;
export 'src/context/interaction_context.dart' show IInteractionContext, IInteractionContextBase;
export 'src/context/message_context.dart' show MessageContext;
export 'src/context/user_context.dart' show UserContext;
export 'src/converters/converter.dart'
    show
        CombineConverter,
        Converter,
        DoubleConverter,
        FallbackConverter,
        GuildChannelConverter,
        IntConverter,
        NumConverter,
        attachmentConverter,
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
        registerDefaultConverters,
        parse;
export 'src/errors.dart'
    show
        AutocompleteFailedException,
        BadInputException,
        CheckFailedException,
        CommandInvocationException,
        CommandNotFoundException,
        CommandRegistrationError,
        CommandsError,
        CommandsException,
        NoConverterException,
        NotEnoughArgumentsException,
        ParsingException,
        UncaughtException;
export 'src/options.dart' show CommandsOptions;
export 'src/util/util.dart'
    show
        Choices,
        Description,
        Name,
        UseConverter,
        commandNameRegexp,
        convertToKebabCase,
        dmOr,
        mentionOr;
export 'src/util/view.dart' show StringView;
