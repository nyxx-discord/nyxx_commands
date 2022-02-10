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

/// A framework for easily creating slash commands and text commands for Discord using the
/// [nyxx](https://pub.dev/packages/nyxx) library.
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
export 'src/context/chat_context.dart'
    show IChatContext, InteractionChatContext, MessageChatContext;
export 'src/context/context.dart' show IContext;
export 'src/context/message_context.dart' show MessageContext;
export 'src/context/user_context.dart' show UserContext;
export 'src/converters/converter.dart'
    show
        CombineConverter,
        Converter,
        FallbackConverter,
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
        Id,
        Name,
        UseConverter,
        commandNameRegexp,
        convertToKebabCase,
        dmOr,
        mentionOr;
export 'src/util/view.dart' show StringView;
