import 'package:nyxx_commands/src/context/base.dart';
import 'package:nyxx_commands/src/util/mixins.dart';
import 'package:nyxx_interactions/src/models/interaction.dart';
import 'package:nyxx_interactions/src/events/interaction_event.dart';

/// A context in which a user submitted a modal.
class ModalContext extends ContextBase
    with InteractionRespondMixin, InteractiveMixin
    implements IInteractionInteractiveContext {
  @override
  final IModalInteraction interaction;

  @override
  final IModalInteractionEvent interactionEvent;

  /// Create a new [ModalContext].
  ModalContext({
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
    required this.interaction,
    required this.interactionEvent,
  });
}
