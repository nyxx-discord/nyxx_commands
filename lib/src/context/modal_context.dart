import 'package:nyxx/nyxx.dart';

import '../context/base.dart';
import '../util/mixins.dart';

/// A context in which a user submitted a modal.
class ModalContext extends ContextBase with InteractionRespondMixin, InteractiveMixin implements InteractionInteractiveContext {
  @override
  final ModalSubmitInteraction interaction;

  /// Create a new [ModalContext].
  ModalContext({
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
    required this.interaction,
  });

  Iterable<SubmittedTextInputComponent> _expandComponents(SubmittedComponent component) sync* {
    switch (component) {
      case SubmittedActionRowComponent(:final components):
        yield* components.expand(_expandComponents);
      case SubmittedTextInputComponent c:
        yield c;
      case SubmittedLabelComponent(:final component):
        yield* _expandComponents(component);
      case SubmittedSelectMenuComponent():
      case SubmittedTextDisplayComponent():
      case SubmittedRadioGroupComponent():
      case SubmittedCheckboxGroupComponent():
      case SubmittedCheckboxComponent():
        return;
    }
  }

  /// Get the value the user inputted in a text input component based on its [id].
  ///
  /// Throws a [StateError] if no component with the given [id] exist in the modal.
  String? operator [](String id) => interaction.data.components.expand(_expandComponents).singleWhere((element) => element.customId == id).value;
}
