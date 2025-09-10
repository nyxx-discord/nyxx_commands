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

  /// Get the value the user inputted in a component based on its [id].
  ///
  /// Throws a [StateError] if no component with the given [id] exist in the modal.
  String? operator [](String id) => interaction.data.components
      .expand((component) => component is ActionRowComponent ? component.components : [component])
      .whereType<TextInputComponent>()
      .singleWhere((element) => element.customId == id)
      .value;
}
