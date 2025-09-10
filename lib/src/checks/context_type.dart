import 'package:nyxx/nyxx.dart';

import '../context/base.dart';
import '../context/chat_context.dart';
import '../context/message_context.dart';
import '../context/user_context.dart';
import 'checks.dart';

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
  InteractionCommandCheck({super.name = 'Interaction check'}) : super((context) => context is InteractionContextData);
}

/// A check that succeeds if the command being invoked is a [MessageCommand].
///
/// This is generally used in combination with [Check.any] and/or [Check.deny] to only apply another
/// check to [MessageCommand]s, while still registering this check to [CommandsPlugin].
///
/// You might also be interested in:
/// - [InteractionCommandCheck], for checking that a command was invoked from an interaction.
class MessageCommandCheck extends Check {
  /// Create a new [MessageCommandCheck].
  MessageCommandCheck({super.name = 'Message command check'}) : super((context) => context is MessageContext);
}

/// A check that succeeds if the command being invoked is a [UserCommand].
///
/// This is generally used in combination with [Check.any] and/or [Check.deny] to only apply another
/// check to [UserCommand]s, while still registering this check to [CommandsPlugin].
///
/// You might also be interested in:
/// - [InteractionCommandCheck], for checking that a command was invoked from an interaction.
class UserCommandCheck extends Check {
  /// Create a new [UserCommandCheck].
  UserCommandCheck({super.name = 'User command check'}) : super((context) => context is UserContext);
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
  ChatCommandCheck({super.name = 'Chat command check'}) : super((context) => context is ChatContext);
}

/// A check that succeeds if the command being invoked is a [ChatCommand] and that the context was
/// created from an interaction.
///
/// This is generally used in combination with [Check.any] and/or [Check.deny] to only apply another
/// check to [ChatCommand]s invoked from interactions, while still registering this check to
/// [CommandsPlugin].
///
/// See [Check.any] for an example of how to implement this.
///
/// You might also be interested in:
/// - [ChatCommandCheck], for checking that the command being executed is a [ChatCommand];
/// - [InteractionCommandCheck], for checking that a command was invoked from an interaction.
class InteractionChatCommandCheck extends Check {
  /// Create a new [InteractionChatCommandCheck].
  InteractionChatCommandCheck({super.name = 'Interaction chat command check'}) : super((context) => context is InteractionChatContext);
}

/// A check that succeeds if the command being invoked is a [ChatCommand] and that the context was
/// created from a text message.
///
/// This is generally used in combination with [Check.any] and/or [Check.deny] to only apply another
/// check to [ChatCommand]s invoked from text messages, while still registering this check to
/// [CommandsPlugin].
///
/// See [Check.any] for an example of how to implement this.
///
/// You might also be interested in:
/// - [ChatCommandCheck], for checking that the command being executed is a [ChatCommand].
class MessageChatCommandCheck extends Check {
  /// Create a new [MessageChatCommandCheck].
  MessageChatCommandCheck({super.name = 'Message chat command check'})
      : super(
          (context) => context is MessageChatContext,
          // Don't enable slash commands with this check either in DMs or in guilds.
          allowsDm: false,
          requiredPermissions: Permissions(0),
        );
}
