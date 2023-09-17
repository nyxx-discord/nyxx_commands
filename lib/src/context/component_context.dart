import 'package:nyxx_commands/src/util/util.dart';
import 'package:nyxx/nyxx.dart';

import '../util/mixins.dart';
import 'base.dart';

/// Data about a context in which a component was interacted with.
///
/// You might also be interested in:
/// - [ComponentContext], which exposes the functionality for interacting with this context.
abstract class ComponentContextData implements InteractionContextData {
  @override
  MessageComponentInteraction get interaction;

  /// The ID of the component that was interacted with.
  String get componentId;

  /// If [componentId] is a valid [ComponentId], this is the parsed version of that.
  ComponentId? get parsedComponentId;
}

/// A context in which a component was interacted with.
///
/// Contains data about which component was interacted with and exposes functionality to respond to
/// that interaction.
///
/// You might also be interested in:
/// - [ComponentContextData], which exposes the data found in this context.
abstract class ComponentContext implements ComponentContextData, InteractionInteractiveContext {}

/// A context in which a button component was interacted with.
///
/// You might also be interested in:
/// - [ComponentContext], the base class for all component contexts.
class ButtonComponentContext extends ContextBase
    with InteractionRespondMixin, InteractiveMixin
    implements ComponentContext {
  @override
  final MessageComponentInteraction interaction;

  @override
  String get componentId => interaction.data.customId;

  @override
  ComponentId? get parsedComponentId => ComponentId.parse(componentId);

  /// Create a new [ButtonComponentContext].
  ButtonComponentContext({
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
    required this.interaction,
  });
}

/// A context in which a multi-select component was interacted with.
///
/// You might also be interested in:
/// - [ComponentContext], the base class for all component contexts.
class SelectMenuContext<T> extends ContextBase
    with InteractionRespondMixin, InteractiveMixin
    implements ComponentContext {
  @override
  final MessageComponentInteraction interaction;

  @override
  String get componentId => interaction.data.customId;

  /// The item selected by the user.
  ///
  /// Will be a [List] if multiple items were selected.
  final T selected;

  @override
  ComponentId? get parsedComponentId => ComponentId.parse(componentId);

  /// Create a new [SelectMenuContext].
  SelectMenuContext({
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
    required this.interaction,
    required this.selected,
  });
}
