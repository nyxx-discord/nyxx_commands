import 'package:nyxx/nyxx.dart';

import '../commands/message_command.dart';
import '../util/mixins.dart';
import 'base.dart';

/// A context in which a [MessageCommand] was executed.
///
/// You might also be interested in:
/// - [InteractionCommandContext], the base class for all commands executed from an interaction.
class MessageContext extends ContextBase with InteractionRespondMixin, InteractiveMixin implements InteractionCommandContext {
  @override
  final MessageCommand command;

  @override
  final ApplicationCommandInteraction interaction;

  /// The message that the user selected when running this command.
  final Message targetMessage;

  /// Create a new [MessageContext].
  MessageContext({
    required this.targetMessage,
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
