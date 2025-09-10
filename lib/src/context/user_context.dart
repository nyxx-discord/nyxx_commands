import 'package:nyxx/nyxx.dart';

import '../commands/user_command.dart';
import '../util/mixins.dart';
import 'base.dart';

/// A context in which a [UserCommand] was executed.
///
/// You might also be interested in:
/// - [InteractionCommandContext], the base class for all commands executed from an interaction.
class UserContext extends ContextBase with InteractionRespondMixin, InteractiveMixin implements InteractionCommandContext {
  @override
  final UserCommand command;

  @override
  final ApplicationCommandInteraction interaction;

  /// The member that was selected by the user when running the command if the command was invoked
  /// in a guild, `null` otherwise.
  final Member? targetMember;

  /// The user that was selected by the user when running the command.
  final User targetUser;

  /// Create a new [UserContext].
  UserContext({
    required this.targetMember,
    required this.targetUser,
    required this.command,
    required this.interaction,
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
  });
}
