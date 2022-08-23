import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../commands/message_command.dart';
import '../util/component_wrappers.dart';
import 'base.dart';

/// Represents a  context in which a [MessageCommand] was executed.
class MessageContext extends ContextBase
    with InteractionRespondMixin, ComponentWrappersMixin
    implements IInteractionCommandContext {
  @override
  final MessageCommand command;

  @override
  final ISlashCommandInteraction interaction;

  @override
  final ISlashCommandInteractionEvent interactionEvent;

  /// The message that the user selected when running this command.
  final IMessage targetMessage;

  /// Create a new [MessageContext].
  MessageContext({
    required this.targetMessage,
    required this.command,
    required this.interaction,
    required this.interactionEvent,
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
  });
}
