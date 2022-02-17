import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

/// A check that checks that an [ICommand] is invokedd from an interaction.
class InteractionCommandCheck extends Check {
  InteractionCommandCheck() : super((context) => context is IInteractionContext);
}

/// A check that checks that an [ICommand] invocation is a [MessageCommand].
class MessageCommandCheck extends Check {
  MessageCommandCheck() : super((context) => context is MessageContext);
}

/// A check that checks that an [ICommand] invocation is a [UserCommand].
class UserCommandCheck extends Check {
  UserCommandCheck() : super((context) => context is UserCommandCheck);
}

/// A check that checks that an [ICommand] invocation is a [ChatCommand].
class ChatCommandCheck extends Check {
  ChatCommandCheck() : super((context) => context is IChatContext);
}

/// A check that checks that a [ChatCommand] invocation is invoked with an [InteractionChatContext].
class InteractionChatCommandCheck extends Check {
  InteractionChatCommandCheck() : super((context) => context is InteractionChatContext);
}

/// A check that checks that a [ChatCommand] invocation is invoked with an [InteractionChatContext].
///
/// Integrates with Discord slash command permissions to deny all usage. You should probably use
/// [ChatCommand.textOnly] instead of this.
class MessageChatCommandCheck extends Check {
  MessageChatCommandCheck() : super((context) => context is MessageChatContext);

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions => Future.value([
        CommandPermissionBuilderAbstract.role(Snowflake.zero(), hasPermission: false),
      ]);
}
