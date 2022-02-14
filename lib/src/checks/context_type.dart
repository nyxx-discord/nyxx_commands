import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

class InteractionCommandCheck extends Check {
  InteractionCommandCheck() : super((context) => context is IInteractionContext);
}

class MessageCommandCheck extends Check {
  MessageCommandCheck() : super((context) => context is MessageContext);
}

class UserCommandCheck extends Check {
  UserCommandCheck() : super((context) => context is UserCommandCheck);
}

class ChatCommandCheck extends Check {
  ChatCommandCheck() : super((context) => context is IChatContext);
}

class InteractionChatCommandCheck extends Check {
  InteractionChatCommandCheck() : super((context) => context is InteractionChatContext);
}

class MessageChatCommandCheck extends Check {
  MessageChatCommandCheck() : super((context) => context is MessageChatContext);

  @override
  Future<Iterable<CommandPermissionBuilderAbstract>> get permissions => Future.value([
        CommandPermissionBuilderAbstract.role(Snowflake.zero(), hasPermission: false),
      ]);
}
