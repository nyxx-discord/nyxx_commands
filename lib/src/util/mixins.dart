import 'dart:async';
import 'dart:math';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/context/modal_context.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:runtime_type/runtime_type.dart';

import '../checks/checks.dart';
import '../commands.dart';
import '../commands/chat_command.dart';
import '../commands/interfaces.dart';
import '../commands/options.dart';
import '../context/base.dart';
import '../context/component_context.dart';
import '../converters/converter.dart';
import '../errors.dart';
import '../util/util.dart';
import '../util/view.dart';

mixin ParentMixin<T extends ICommandContext> implements ICommandRegisterable<T> {
  ICommandGroup<ICommandContext>? _parent;

  @override
  ICommandGroup<ICommandContext>? get parent => _parent;

  @override
  set parent(ICommandGroup<ICommandContext>? parent) {
    if (_parent != null) {
      throw CommandRegistrationError('Cannot register command "$name" again');
    }
    _parent = parent;
  }
}

mixin CheckMixin<T extends ICommandContext> on ICommandRegisterable<T> implements IChecked {
  final List<AbstractCheck> _checks = [];

  @override
  Iterable<AbstractCheck> get checks => [...?parent?.checks, ..._checks];

  @override
  void check(AbstractCheck check) {
    _checks.add(check);

    for (final preCallHook in check.preCallHooks) {
      onPreCall.listen(preCallHook);
    }

    for (final postCallHook in check.postCallHooks) {
      onPostCall.listen(postCallHook);
    }
  }
}

mixin OptionsMixin<T extends ICommandContext> on ICommandRegisterable<T> implements IOptions {
  @override
  CommandOptions get resolvedOptions {
    if (parent == null) {
      return options;
    }

    CommandOptions parentOptions = parent is ICommandRegisterable
        ? (parent as ICommandRegisterable).resolvedOptions
        : parent!.options;

    CommandType? parentType = parentOptions.type;
    if (parent is CommandsPlugin) {
      if ((parent as CommandsPlugin).prefix == null && parentType == CommandType.all) {
        parentType = CommandType.slashOnly;
      }
    }

    return CommandOptions(
      autoAcknowledgeInteractions:
          options.autoAcknowledgeInteractions ?? parentOptions.autoAcknowledgeInteractions,
      acceptBotCommands: options.acceptBotCommands ?? parentOptions.acceptBotCommands,
      acceptSelfCommands: options.acceptSelfCommands ?? parentOptions.acceptSelfCommands,
      defaultResponseLevel: options.defaultResponseLevel ?? parentOptions.defaultResponseLevel,
      type: options.type ?? parentType,
      autoAcknowledgeDuration:
          options.autoAcknowledgeDuration ?? parentOptions.autoAcknowledgeDuration,
      caseInsensitiveCommands:
          options.caseInsensitiveCommands ?? parentOptions.caseInsensitiveCommands,
    );
  }
}

mixin InteractiveMixin implements IInteractiveContext, IContextData {
  @override
  IInteractiveContext? get parent => _parent;

  // Must narrow type to use [_nearestCommandContext].
  InteractiveMixin? _parent;

  @override
  IInteractiveContext? get delegate => _delegate;
  IInteractiveContext? _delegate;

  @override
  IInteractiveContext get latestContext => delegate?.latestContext ?? this;

  ICommandContext get _nearestCommandContext {
    if (this is ICommandContext) {
      return this as ICommandContext;
    }

    if (parent == null) {
      // This generally happens when a context is created directly from the plugin's context manager
      // and not from an existing context inside a command, which messes with functionality like
      // parsing which requires an ICommandContext to invoke converters.
      throw CommandsError(
        'Cannot use command functionality in a context created outside of a command',
      );
    }

    return _parent!._nearestCommandContext;
  }

  Future<T> _getInteractionEvent<T extends IComponentInteractionEvent>(
    Stream<T> stream, {
    List<String>? componentIds,
    List<Snowflake>? messageIds,
    required Duration? timeout,
    required bool authorOnly,
  }) async {
    assert(
      (componentIds == null) ^ (messageIds == null),
      'Exactly one of componentIds or messageIds must be set',
    );

    if (componentIds != null) {
      stream = stream.where((event) => componentIds.contains(event.interaction.customId));
    }

    if (messageIds != null) {
      stream = stream.where((event) => messageIds.contains(event.interaction.message?.id));
    }

    if (authorOnly) {
      stream = stream.where((event) {
        Snowflake interactionUserId =
            event.interaction.userAuthor?.id ?? event.interaction.memberAuthor!.id;

        return interactionUserId == user.id;
      });
    }

    Future<T> event = stream.first;

    if (timeout != null) {
      event = event.timeout(timeout);
    }

    return event;
  }

  @override
  Future<ButtonComponentContext> awaitButtonPress(
    String componentId, {
    Duration? timeout,
    bool authorOnly = true,
  }) async {
    if (delegate != null) {
      return delegate!.awaitButtonPress(componentId, timeout: timeout, authorOnly: authorOnly);
    }

    ButtonComponentContext context =
        await commands.contextManager.createButtonComponentContext(await _getInteractionEvent(
      interactions.events.onButtonEvent,
      componentIds: [componentId],
      timeout: timeout,
      authorOnly: authorOnly,
    ));

    context._parent = this;
    _delegate = context;

    return context;
  }

  @override
  Future<MultiselectComponentContext<T>> awaitSelection<T>(
    String componentId, {
    Duration? timeout,
    bool authorOnly = true,
    Converter<T>? converterOverride,
  }) async {
    if (delegate != null) {
      return delegate!.awaitSelection(
        componentId,
        timeout: timeout,
        authorOnly: authorOnly,
        converterOverride: converterOverride,
      );
    }

    IMultiselectInteractionEvent event = await _getInteractionEvent(
      interactions.events.onMultiselectEvent,
      componentIds: [componentId],
      timeout: timeout,
      authorOnly: authorOnly,
    );

    MultiselectComponentContext<String> rawContext =
        await commands.contextManager.createMultiselectComponentContext(
      event,
      event.interaction.values.single,
    );

    MultiselectComponentContext<T> context =
        await commands.contextManager.createMultiselectComponentContext(
      event,
      await parse(
        commands,
        _nearestCommandContext,
        StringView(rawContext.selected),
        RuntimeType<T>(),
      ),
    );

    context._parent = this;
    _delegate = context;

    return context;
  }

  @override
  Future<MultiselectComponentContext<List<T>>> awaitMultiSelection<T>(
    String componentId, {
    Duration? timeout,
    bool authorOnly = true,
    Converter<T>? converterOverride,
  }) async {
    if (delegate != null) {
      return delegate!.awaitMultiSelection(
        componentId,
        authorOnly: authorOnly,
        converterOverride: converterOverride,
        timeout: timeout,
      );
    }

    IMultiselectInteractionEvent event = await _getInteractionEvent(
      interactions.events.onMultiselectEvent,
      componentIds: [componentId],
      timeout: timeout,
      authorOnly: authorOnly,
    );

    List<MultiselectComponentContext<String>> rawContexts = await Future.wait(
      event.interaction.values.map(
        (value) => commands.contextManager.createMultiselectComponentContext(
          event,
          value,
        ),
      ),
    );

    List<T> values = await Future.wait(rawContexts.map(
      (rawContext) => parse(
          commands, _nearestCommandContext, StringView(rawContext.selected), RuntimeType<T>()),
    ));

    MultiselectComponentContext<List<T>> context =
        await commands.contextManager.createMultiselectComponentContext(
      event,
      values,
    );

    context._parent = this;
    _delegate = context;

    return context;
  }

  @override
  Future<ButtonComponentContext> getButtonPress(
    IMessage message, {
    bool authorOnly = true,
    ResponseLevel? level,
    Duration? timeout,
  }) async {
    if (_delegate != null) {
      return _delegate!.getButtonPress(message, authorOnly: authorOnly, level: level);
    }

    ButtonComponentContext context = await commands.contextManager.createButtonComponentContext(
      await _getInteractionEvent(
        interactions.events.onButtonEvent,
        messageIds: [message.id],
        timeout: timeout,
        authorOnly: authorOnly,
      ),
    );

    context._parent = this;
    _delegate = context;

    return context;
  }

  @override
  Future<T> getButtonSelection<T>(
    List<T> values,
    MessageBuilder builder, {
    Map<T, ButtonStyle>? styles,
    bool authorOnly = true,
    ResponseLevel? level,
    Duration? timeout,
    FutureOr<ButtonBuilder> Function(T)? toButton,
    Converter<T>? converterOverride,
  }) async {
    if (_delegate != null) {
      return _delegate!.getButtonSelection(
        values,
        builder,
        authorOnly: authorOnly,
        converterOverride: converterOverride,
        level: level,
        styles: styles,
        timeout: timeout,
        toButton: toButton,
      );
    }

    assert(
      toButton == null || converterOverride == null,
      'Cannot specify both toButton and converterOverride.',
    );

    toButton ??= converterOverride?.toButton;
    toButton ??= commands.getConverter(RuntimeType<T>())?.toButton;

    if (toButton == null) {
      throw UncaughtCommandsException(
        'No suitable method found for converting $T to ButtonBuilder.',
        _nearestCommandContext,
      );
    }

    Map<String, T> idToValue = {};

    List<ButtonBuilder> buttons = await Future.wait(values.map((value) async {
      ButtonBuilder builder = await toButton!(value);
      ButtonStyle? style = styles?[value];
      String id = createId();

      idToValue[id] = value;

      // We have to copy since the fields on ButtonBuilder are final.
      return ButtonBuilder(
        builder.label,
        id,
        style ?? builder.style,
      )
        ..disabled = builder.disabled
        ..emoji = builder.emoji;
    }));

    builder = builderToComponentBuilder(builder);

    final activeComponentRows = [...?(builder as ComponentMessageBuilder).componentRows];
    final disabledComponentRows = [...?builder.componentRows];

    while (buttons.isNotEmpty) {
      // Max 5 buttons per row
      int count = min(5, buttons.length);

      ComponentRowBuilder activeRow = ComponentRowBuilder();
      ComponentRowBuilder disabledRow = ComponentRowBuilder();

      for (final button in buttons.take(count)) {
        activeRow.addComponent(button);

        disabledRow.addComponent(
          ButtonBuilder(button.label, button.customId, button.style)
            ..disabled = true
            ..emoji = button.emoji,
        );
      }

      activeComponentRows.add(activeRow);
      disabledComponentRows.add(disabledRow);

      buttons.removeRange(0, count);
    }

    builder.componentRows = activeComponentRows;
    final message = await respond(builder, level: level);

    try {
      ButtonComponentContext context = await commands.contextManager.createButtonComponentContext(
        await _getInteractionEvent(
          interactions.events.onButtonEvent,
          componentIds: idToValue.keys.toList(),
          timeout: timeout,
          authorOnly: authorOnly,
        ),
      );

      context._parent = this;
      _delegate = context;

      return idToValue[context.componentId]!;
    } finally {
      builder.componentRows = disabledComponentRows;
      await message.edit(builder);
    }
  }

  @override
  Future<bool> getConfirmation(
    MessageBuilder builder, {
    Map<bool, String> values = const {true: 'Yes', false: 'No'},
    Map<bool, ButtonStyle> styles = const {true: ButtonStyle.success, false: ButtonStyle.danger},
    bool authorOnly = true,
    ResponseLevel? level,
    Duration? timeout,
  }) =>
      getButtonSelection(
        [true, false],
        builder,
        toButton: (value) => ButtonBuilder(
          values[value] ?? (value ? 'Yes' : 'No'),
          '',
          ButtonStyle.primary,
        ),
        styles: styles,
        authorOnly: authorOnly,
        level: level,
        timeout: timeout,
      );

  @override
  Future<T> getSelection<T>(
    List<T> choices,
    MessageBuilder builder, {
    ResponseLevel? level,
    Duration? timeout,
    bool authorOnly = true,
    FutureOr<MultiselectOptionBuilder> Function(T)? toMultiSelect,
    Converter<T>? converterOverride,
  }) async {
    if (_delegate != null) {
      return _delegate!.getSelection(
        choices,
        builder,
        authorOnly: authorOnly,
        converterOverride: converterOverride,
        level: level,
        timeout: timeout,
        toMultiSelect: toMultiSelect,
      );
    }

    assert(
      toMultiSelect == null || converterOverride == null,
      'Cannot specify both toMultiSelect and converterOverride',
    );

    toMultiSelect ??= converterOverride?.toMultiselectOption;
    toMultiSelect ??= commands.getConverter(RuntimeType<T>())?.toMultiselectOption;

    if (toMultiSelect == null) {
      throw UncaughtCommandsException(
        'No suitable method for converting $T to MultiselectOptionBuilder found',
        _nearestCommandContext,
      );
    }

    Map<String, T> idToValue = {};
    List<MultiselectOptionBuilder> options = await Future.wait(choices.map(
      (value) async {
        MultiselectOptionBuilder builder = await toMultiSelect!(value);
        idToValue[builder.value] = value;
        return builder;
      },
    ));

    MultiselectOptionBuilder prevPageOption = MultiselectOptionBuilder(
      'Previous page',
      createId(),
    );

    MultiselectOptionBuilder nextPageOption = MultiselectOptionBuilder(
      'Next page',
      createId(),
    );

    builder = builderToComponentBuilder(builder);

    MultiselectComponentContext<String>? context;
    int currentOffset = 0;

    late MultiselectBuilder menu;
    late IMessage message;

    try {
      do {
        bool hasPreviousPage = currentOffset != 0;
        int itemsPerPage = hasPreviousPage ? 24 : 25;
        bool hasNextPage = currentOffset + itemsPerPage < options.length;

        if (hasNextPage) {
          itemsPerPage -= 1;
        }

        menu = MultiselectBuilder(createId(), [
          if (hasPreviousPage) prevPageOption,
          ...options.skip(currentOffset).take(itemsPerPage),
          if (hasNextPage) nextPageOption,
        ]);

        ComponentRowBuilder row = ComponentRowBuilder()..addComponent(menu);
        if (context == null) {
          // This is the first time we're sending a message, just append the component row.
          (builder as ComponentMessageBuilder).addComponentRow(row);
        } else {
          // On later iterations, replace the last row with our newly created one.
          List<ComponentRowBuilder> rows = (builder as ComponentMessageBuilder).componentRows!;

          rows[rows.length - 1] = row;
        }

        message = await respond(builder, level: level);

        context = await awaitSelection(
          menu.customId,
          authorOnly: authorOnly,
          timeout: timeout,
        );

        if (context.selected == nextPageOption.value) {
          currentOffset += itemsPerPage;
        } else if (context.selected == prevPageOption.value) {
          currentOffset -= itemsPerPage;
        }
      } while (
          context.selected == nextPageOption.value || context.selected == prevPageOption.value);

      return idToValue[context.selected]!;
    } finally {
      menu.disabled = true;
      await message.edit(builder);
    }
  }

  @override
  Future<List<T>> getMultiSelection<T>(
    List<T> choices,
    MessageBuilder builder, {
    ResponseLevel? level,
    Duration? timeout,
    bool authorOnly = true,
    FutureOr<MultiselectOptionBuilder> Function(T)? toMultiSelect,
    Converter<T>? converterOverride,
  }) async {
    if (_delegate != null) {
      return _delegate!.getMultiSelection(
        choices,
        builder,
        authorOnly: authorOnly,
        converterOverride: converterOverride,
        level: level,
        timeout: timeout,
        toMultiSelect: toMultiSelect,
      );
    }

    toMultiSelect ??= converterOverride?.toMultiselectOption;
    toMultiSelect ??= commands.getConverter(RuntimeType<T>())?.toMultiselectOption;

    if (toMultiSelect == null) {
      throw UncaughtCommandsException(
        'No suitable method for converting $T to MultiselectOptionBuilder found',
        _nearestCommandContext,
      );
    }

    Map<String, T> idToValue = {};
    List<MultiselectOptionBuilder> options = await Future.wait(choices.map(
      (value) async {
        MultiselectOptionBuilder builder = await toMultiSelect!(value);
        idToValue[builder.value] = value;
        return builder;
      },
    ));

    builder = builderToComponentBuilder(builder);

    MultiselectBuilder menu = MultiselectBuilder(createId(), options);
    ComponentRowBuilder row = ComponentRowBuilder()..addComponent(menu);

    (builder as ComponentMessageBuilder).addComponentRow(row);

    IMessage message = await respond(builder, level: level);

    try {
      MultiselectComponentContext<List<String>> context = await awaitMultiSelection(
        menu.customId,
        authorOnly: authorOnly,
        timeout: timeout,
      );

      return context.selected.map((id) => idToValue[id]!).toList();
    } finally {
      menu.disabled = true;
      await message.edit(builder);
    }
  }
}

mixin InteractionRespondMixin
    implements IInteractionInteractiveContext, IInteractionContextData, InteractiveMixin {
  @override
  IInteractionEventWithAcknowledge get interactionEvent;

  ResponseLevel? _responseLevel;
  bool _hasResponded = false;

  Future<void> _acknowledgeLock = Future.value();

  @override
  Future<IMessage> respond(MessageBuilder builder, {ResponseLevel? level}) async {
    await _acknowledgeLock;

    if (_delegate != null) {
      return _delegate!.respond(builder, level: level);
    }

    level ??= _nearestCommandContext.command.resolvedOptions.defaultResponseLevel!;

    if (_hasResponded) {
      // We've already responded, just send a followup.
      return interactionEvent.sendFollowup(builder, hidden: level.hideInteraction);
    }

    _hasResponded = true;

    if (_responseLevel != null && _responseLevel!.hideInteraction != level.hideInteraction) {
      // We acknowledged the interaction but our original acknowledgement doesn't correspond to
      // what's being requested here.
      // It's a bit ugly, but send an empty response and delete it to match [level].

      await interactionEvent.respond(MessageBuilder.content(MessageBuilder.clearCharacter));
      await interactionEvent.deleteOriginalResponse();

      return interactionEvent.sendFollowup(builder, hidden: level.hideInteraction);
    }

    // If we want to preserve the original message a component is attached to, we can just send a
    // followup instead of a response.
    // Also, if we are requested to hide interactions, also send a followup, or
    // components will just edit the original message (making it public).
    if (level.preserveComponentMessages ||
        (level.hideInteraction == true && interaction is IComponentInteraction)) {
      if (_responseLevel == null) {
        // Need to acknowledge before we send a followup.
        await acknowledge(level: level);
      }

      return interactionEvent.sendFollowup(builder, hidden: level.hideInteraction);
    } else {
      // Using interactionEvent.respond is actually the same as editing a message in the case where
      // the interaction is a message component. In those cases, leaving `componentRows` as `null`
      // would leave the existing components on the message - which likely isn't what our users
      // expect. Instead, we override them and set the builder to have no components.
      builder = builderToComponentBuilder(builder)..componentRows ??= [];

      await interactionEvent.respond(builder, hidden: level.hideInteraction);
      return interactionEvent.getOriginalResponse();
    }
  }

  @override
  Future<void> acknowledge({ResponseLevel? level}) async {
    _responseLevel = level ??= _nearestCommandContext.command.resolvedOptions.defaultResponseLevel!;
    await (_acknowledgeLock = interactionEvent.acknowledge(hidden: level.hideInteraction));
  }

  @override
  Future<ModalContext> awaitModal(String customId, {Duration? timeout}) async {
    if (_delegate != null) {
      if (_delegate is! IInteractionInteractiveContext) {
        throw UncaughtCommandsException(
          "Couldn't delegate awaitModal() to non-interaction context",
          _nearestCommandContext,
        );
      }

      return (_delegate as IInteractionInteractiveContext).awaitModal(customId, timeout: timeout);
    }

    Future<IModalInteractionEvent> event = interactions.events.onModalEvent
        .where(
          (event) => event.interaction.customId == customId,
        )
        .first;

    if (timeout != null) {
      event = event.timeout(timeout);
    }

    ModalContext context = await commands.contextManager.createModalContext(await event);

    context._parent = this;
    _delegate = context;

    return context;
  }

  @override
  Future<ModalContext> getModal({
    required String title,
    required List<TextInputBuilder> components,
    Duration? timeout,
  }) async {
    if (_delegate != null) {
      if (_delegate is! IInteractionInteractiveContext) {
        throw UncaughtCommandsException(
          "Couldn't delegate getModal() to non-interaction context",
          _nearestCommandContext,
        );
      }

      return (_delegate as IInteractionInteractiveContext).getModal(
        title: title,
        components: components,
        timeout: timeout,
      );
    }

    final interactionEvent = this.interactionEvent;
    if (interactionEvent is! IModalResponseMixin) {
      throw UncaughtCommandsException(
        'Cannot respond to a context of type $runtimeType with a modal',
        _nearestCommandContext,
      );
    }

    ModalBuilder builder = ModalBuilder(createId(), title);
    builder.componentRows = [
      for (final input in components) ComponentRowBuilder()..addComponent(input),
    ];

    await (interactionEvent as IModalResponseMixin).respondModal(builder);

    return awaitModal(builder.customId, timeout: timeout);
  }
}

mixin MessageRespondMixin implements InteractiveMixin {
  IMessage get message;

  @override
  Future<IMessage> respond(MessageBuilder builder, {ResponseLevel? level}) async {
    if (_delegate != null) {
      return _delegate!.respond(builder, level: level);
    }

    level ??= _nearestCommandContext.command.resolvedOptions.defaultResponseLevel!;

    if (level.isDm) {
      return user.sendMessage(builder);
    }

    if (builder.replyBuilder == null) {
      builder.replyBuilder = ReplyBuilder.fromMessage(message);

      // Only update the allowed mentions if they weren't explicitly set.
      builder.allowedMentions ??= client.options.allowedMentions ?? AllowedMentions();
      // Calling [AllowedMentions.allow] here will only change anything if [level.mention] is
      // non-null, in which case we want to change it. Otherwise, this does nothing.
      builder.allowedMentions!.allow(reply: level.mention);
    }

    return channel.sendMessage(builder);
  }
}
