import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

/// A check that succeeds if the context was created from an interaction.
///
/// This is generally used in combination with [Check.any] and/or [Check.deny] to only apply another
/// check to contexts created from interaction, while still registering this check to
/// [CommandsPlugin].
///
/// See [Check.any] for an example of how to implement this.
///
/// You might also be interested in:
/// - [MessageCommandCheck], for checking that the command being invoked is a [MessageCommand];
/// - [UserCommandCheck], for checking that the command being invoked is a [UserCommand];
/// - [ChatCommandCheck], for checking that the command being invoked is a [ChatCommand].
class InteractionCommandCheck extends Check {
  /// Create a new [InteractionChatCommandCheck].
  InteractionCommandCheck() : super((context) => context is IInteractionContext);
}

class MessageCommandCheck extends Check {
  MessageCommandCheck() : super((context) => context is MessageContext);
}

class UserCommandCheck extends Check {
  UserCommandCheck() : super((context) => context is UserCommandCheck);
}

/// A check that succeeds if the command being invoked is a [ChatCommand].
///
/// This is generally used in combination with [Check.any] and/or [Check.deny] to only apply another
/// check to [ChatCommand]s, while still registering this check to [CommandsPlugin].
///
/// See [Check.any] for an example of how to implement this.
///
/// You might also be interested in:
/// - [InteractionChatCommandCheck], for checking that the command being executed is a [ChatCommand]
///   and that it was invoked from an interaction;
/// - [MessageChatCommandCheck], for checking that the command being executed is a [ChatCommand] and
///   that it was invoked from a text message;
/// - [InteractionCommandCheck], for checking that a command was invoked from an interaction.
class ChatCommandCheck extends Check {
  /// Create a new [ChatCommandCheck].
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
