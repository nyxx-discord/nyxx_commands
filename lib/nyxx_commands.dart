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
export 'src/context/base.dart'
    show
        ICommandContext,
        ICommandContextData,
        IContextData,
        IInteractionCommandContext,
        IInteractionContextData,
        IInteractionCommandContextData;
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
        NoConverterException,
        NotEnoughArgumentsException,
        ParsingException,
        UncaughtException;
export 'src/options.dart' show CommandsOptions;
export 'src/util/util.dart'
    show
        Autocomplete,
        Choices,
        Description,
        Name,
        UseConverter,
        commandNameRegexp,
        convertToKebabCase,
        dmOr,
        id,
        mentionOr;
export 'src/util/view.dart' show StringView;
