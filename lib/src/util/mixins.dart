import 'dart:async';
import 'dart:math';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../checks/checks.dart';
import '../commands.dart';
import '../commands/chat_command.dart';
import '../commands/interfaces.dart';
import '../commands/options.dart';
import '../context/base.dart';
import '../context/component_context.dart';
import '../context/modal_context.dart';
import '../converters/converter.dart';
import '../errors.dart';
import '../mirror_utils/mirror_utils.dart';
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

  @override
  Future<ButtonComponentContext> awaitButtonPress(ComponentId componentId) async {
    if (delegate != null) {
      return delegate!.awaitButtonPress(componentId);
    }

    try {
      ButtonComponentContext context = await commands.eventManager.nextButtonEvent(componentId);

      context._parent = this;
      _delegate = context;

      return context;
    } on TimeoutException catch (e, s) {
      throw InteractionTimeoutException(
        'Timed out waiting for button press on component $componentId',
        _nearestCommandContext,
      )..stackTrace = s;
    }
  }

  @override
  Future<MultiselectComponentContext<T>> awaitSelection<T>(
    ComponentId componentId, {
    Converter<T>? converterOverride,
  }) async {
    if (delegate != null) {
      return delegate!.awaitSelection(
        componentId,
        converterOverride: converterOverride,
      );
    }

    MultiselectComponentContext<List<String>> rawContext =
        await commands.eventManager.nextMultiselectEvent(componentId);

    MultiselectComponentContext<T> context =
        await commands.contextManager.createMultiselectComponentContext(
      rawContext.interactionEvent,
      await parse(
        commands,
        _nearestCommandContext,
        StringView(rawContext.selected.single, isRestBlock: true),
        DartType<T>(),
      ),
    );

    context._parent = this;
    _delegate = context;

    return context;
  }

  @override
  Future<MultiselectComponentContext<List<T>>> awaitMultiSelection<T>(
    ComponentId componentId, {
    Converter<T>? converterOverride,
  }) async {
    if (delegate != null) {
      return delegate!.awaitMultiSelection(
        componentId,
        converterOverride: converterOverride,
      );
    }

    MultiselectComponentContext<List<String>> rawContext =
        await commands.eventManager.nextMultiselectEvent(componentId);

    MultiselectComponentContext<List<T>> context =
        await commands.contextManager.createMultiselectComponentContext(
      rawContext.interactionEvent,
      await Future.wait(rawContext.selected.map(
        (value) => parse(
          commands,
          rawContext,
          StringView(value, isRestBlock: true),
          DartType<T>(),
        ),
      )),
    );

    context._parent = this;
    _delegate = context;

    return context;
  }

  @override
  Future<ButtonComponentContext> getButtonPress(IMessage message) async {
    if (_delegate != null) {
      return _delegate!.getButtonPress(message);
    }

    final componentIds = message.components
        .expand((_) => _)
        .where((element) => element.type == ComponentType.button)
        .map((component) => ComponentId.parse(component.customId))
        .toList();

    if (componentIds.any((element) => element == null)) {
      throw UncaughtCommandsException(
        'Buttons in getButtonPress must have an ID set with ComponentId.generate()',
        _nearestCommandContext,
      );
    }

    int remaining = componentIds.length;
    Completer<ButtonComponentContext> completer = Completer();

    for (final id in componentIds) {
      commands.eventManager.nextButtonEvent(id!).then((context) {
        if (completer.isCompleted) {
          return;
        }

        completer.complete(context);
      }).catchError((Object error, StackTrace stackTrace) {
        remaining--;

        if (remaining == 0 && !completer.isCompleted) {
          // All the futures failed with an exception, throw the latest one back to the user
          if (error is TimeoutException) {
            error = InteractionTimeoutException(
              'Timed out waiting for button press on message ${message.id}',
              _nearestCommandContext,
            );
          }

          completer.completeError(error, stackTrace);
        }
      });
    }

    ButtonComponentContext context = await completer.future;

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
    toButton ??= commands.getConverter(DartType<T>())?.toButton;

    if (toButton == null) {
      throw UncaughtCommandsException(
        'No suitable method found for converting $T to ButtonBuilder.',
        _nearestCommandContext,
      );
    }

    Map<ComponentId, T> idToValue = {};

    List<ButtonBuilder> buttons = await Future.wait(values.map((value) async {
      ButtonBuilder builder = await toButton!(value);
      ButtonStyle? style = styles?[value];

      ComponentId id = ComponentId.generate(
        expirationTime: timeout,
        allowedUser: authorOnly ? user.id : null,
      );

      idToValue[id] = value;

      // We have to copy since the fields on ButtonBuilder are final.
      return ButtonBuilder(
        builder.label,
        id.toString(),
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

    final listeners =
        idToValue.keys.map((id) => commands.eventManager.nextButtonEvent(id)).toList();

    try {
      ButtonComponentContext context = await Future.any(listeners);

      context._parent = this;
      _delegate = context;

      return idToValue[context.componentId]!;
    } on TimeoutException catch (e, s) {
      throw InteractionTimeoutException(
        'Timed out waiting for button selection',
        _nearestCommandContext,
      )..stackTrace = s;
    } finally {
      for (final id in idToValue.keys) {
        commands.eventManager.stopListeningFor(id);
      }

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
    toMultiSelect ??= commands.getConverter(DartType<T>())?.toMultiselectOption;

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
      ComponentId.generate().toString(),
    );

    MultiselectOptionBuilder nextPageOption = MultiselectOptionBuilder(
      'Next page',
      ComponentId.generate().toString(),
    );

    builder = builderToComponentBuilder(builder);

    MultiselectComponentContext<List<String>>? context;
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

        final menuId = ComponentId.generate(
          expirationTime: timeout,
          allowedUser: authorOnly ? user.id : null,
        );

        menu = MultiselectBuilder(menuId.toString(), [
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

        context = await commands.eventManager.nextMultiselectEvent(menuId);

        if (context.selected.single == nextPageOption.value) {
          currentOffset += itemsPerPage;
        } else if (context.selected.single == prevPageOption.value) {
          currentOffset -= itemsPerPage;
        }
      } while (context.selected.single == nextPageOption.value ||
          context.selected.single == prevPageOption.value);

      return idToValue[context.selected.single]!;
    } on TimeoutException catch (e, s) {
      throw InteractionTimeoutException(
        'TImed out waiting for selection',
        _nearestCommandContext,
      )..stackTrace = s;
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
    toMultiSelect ??= commands.getConverter(DartType<T>())?.toMultiselectOption;

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

    ComponentId menuId = ComponentId.generate(
      expirationTime: timeout,
      allowedUser: authorOnly ? user.id : null,
    );

    MultiselectBuilder menu = MultiselectBuilder(menuId.toString(), options);
    ComponentRowBuilder row = ComponentRowBuilder()..addComponent(menu);

    (builder as ComponentMessageBuilder).addComponentRow(row);

    IMessage message = await respond(builder, level: level);

    try {
      MultiselectComponentContext<List<String>> context =
          await commands.eventManager.nextMultiselectEvent(menuId);

      return context.selected.map((id) => idToValue[id]!).toList();
    } on TimeoutException catch (e, s) {
      throw InteractionTimeoutException(
        'TImed out waiting for selection',
        _nearestCommandContext,
      )..stackTrace = s;
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

  @override
  Future<IMessage> respond(MessageBuilder builder, {ResponseLevel? level}) async {
    if (_delegate != null) {
      return _delegate!.respond(builder, level: level);
    }

    level ??= _nearestCommandContext.command.resolvedOptions.defaultResponseLevel!;

    if (_hasResponded) {
      // We've already responded, just send a followup.
      return interactionEvent.sendFollowup(builder, hidden: level.hideInteraction);
    }

    _hasResponded = true;

    if (_responseLevel != null && !_responseLevel!.hideInteraction != level.hideInteraction) {
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
      // expect. Instead, we override them and set the builder to have to components.
      builder = builderToComponentBuilder(builder)..componentRows ??= [];

      await interactionEvent.respond(builder, hidden: level.hideInteraction);
      return interactionEvent.getOriginalResponse();
    }
  }

  @override
  Future<void> acknowledge({ResponseLevel? level}) async {
    _responseLevel = level ??= _nearestCommandContext.command.resolvedOptions.defaultResponseLevel!;
    await interactionEvent.acknowledge(hidden: level.hideInteraction);
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

    ModalBuilder builder = ModalBuilder(ComponentId.generate().toString(), title);
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
