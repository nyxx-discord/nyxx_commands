import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/commands/user_command.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/context/interaction_context.dart';
import 'package:nyxx_interactions/src/models/interaction.dart';
import 'package:nyxx_interactions/src/events/interaction_event.dart';

/// Represents a [Context] in which a [UserCommand] was executed.
class UserContext extends Context with InteractionContext {
  /// The target member for this context.
  final IMember? targetMember;

  /// The target user for this context, or the user representing [targetMember].
  final IUser targetUser;

  @override
  final ITextChannel channel;

  @override
  final INyxx client;

  @override
  final UserCommand command;

  @override
  final CommandsPlugin commands;

  @override
  final IGuild? guild;

  @override
  final IMember? member;

  @override
  final IUser user;

  @override
  final ISlashCommandInteraction interaction;

  @override
  final ISlashCommandInteractionEvent interactionEvent;

  UserContext({
    required this.targetMember,
    required this.targetUser,
    required this.channel,
    required this.client,
    required this.command,
    required this.commands,
    required this.guild,
    required this.member,
    required this.user,
    required this.interaction,
    required this.interactionEvent,
  });

  @override
  String toString() => 'UserContext[interaction=${interaction.token}, target=$targetUser]';
}
