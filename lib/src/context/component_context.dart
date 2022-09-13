import 'package:nyxx_commands/src/context/base.dart';
import 'package:nyxx_commands/src/util/mixins.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

abstract class IComponentContextData implements IInteractionContextData {
  @override
  IComponentInteractionEvent get interactionEvent;

  @override
  IComponentInteraction get interaction;

  String get componentId;
}

abstract class IComponentContext implements IComponentContextData, IInteractionInteractiveContext {}

class ButtonComponentContext extends ContextBase
    with InteractionRespondMixin, InteractiveMixin
    implements IComponentContext {
  @override
  final IButtonInteraction interaction;

  @override
  final IButtonInteractionEvent interactionEvent;

  @override
  String get componentId => interaction.customId;

  ButtonComponentContext({
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

class MultiselectComponentContext<T> extends ContextBase
    with InteractionRespondMixin, InteractiveMixin
    implements IComponentContext {
  @override
  final IMultiselectInteraction interaction;

  @override
  final IMultiselectInteractionEvent interactionEvent;

  @override
  String get componentId => interaction.customId;

  final T selected;

  MultiselectComponentContext({
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
    required this.interaction,
    required this.interactionEvent,
    required this.selected,
  });
}
