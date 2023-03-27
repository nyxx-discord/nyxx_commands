/// A framework for easily creating slash commands and text commands for Discord using the nyxx library.
library nyxx_commands;

export 'src/checks/checks.dart' show AbstractCheck, Check;
export 'src/checks/context_type.dart'
    show
        ChatCommandCheck,
        InteractionCommandCheck,
        InteractionChatCommandCheck,
        MessageChatCommandCheck,
        MessageCommandCheck,
        UserCommandCheck;
export 'src/checks/cooldown.dart' show CooldownCheck, CooldownType;
export 'src/checks/guild.dart' show GuildCheck;
export 'src/checks/permissions.dart' show PermissionsCheck;
export 'src/checks/user.dart' show RoleCheck, UserCheck;
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
    show IChatContext, IChatContextData, InteractionChatContext, MessageChatContext;
export 'src/context/context_manager.dart' show ContextManager;
export 'src/context/base.dart'
    show
        ICommandContext,
        ICommandContextData,
        IContextData,
        IInteractionCommandContext,
        IInteractionContextData,
        IInteractionCommandContextData,
        IInteractionInteractiveContext,
        IInteractiveContext,
        ResponseLevel;
export 'src/context/message_context.dart' show MessageContext;
export 'src/context/modal_context.dart' show ModalContext;
export 'src/context/user_context.dart' show UserContext;
export 'src/converters/built_in.dart'; // Barrel file, exports are already filtered
export 'src/converters/combine.dart' show CombineConverter;
export 'src/converters/converter.dart' show Converter, registerDefaultConverters, parse;
export 'src/converters/fallback.dart' show FallbackConverter;
export 'src/converters/simple.dart' show SimpleConverter;
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
        ContextualException,
        ConverterFailedException,
        InteractionTimeoutException,
        NoConverterException,
        NotEnoughArgumentsException,
        ParsingException,
        UncaughtCommandsException,
        UncaughtException,
        UnhandledInteractionException;
export 'src/event_manager.dart' show EventManager;
export 'src/mirror_utils/mirror_utils.dart' show RuntimeType;
export 'src/options.dart' show CommandsOptions;
export 'src/util/util.dart'
    show
        Autocomplete,
        Choices,
        ComponentId,
        ComponentIdStatus,
        Description,
        Name,
        UseConverter,
        commandNameRegexp,
        convertToKebabCase,
        dmOr,
        id,
        mentionOr;
export 'src/util/view.dart' show StringView;
