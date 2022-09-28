//  Copyright 2021 Abitofevrything and others.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../checks/checks.dart';
import '../commands.dart';
import '../commands/chat_command.dart';
import '../commands/interfaces.dart';
import '../commands/options.dart';
import '../context/base.dart';
import '../context/component_context.dart';
import '../converters/converter.dart';
import '../errors.dart';
import '../mirror_utils/mirror_utils.dart';
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
    required String componentId,
    required Duration? timeout,
    required bool authorOnly,
  }) async {
    stream = stream.where((event) => event.interaction.customId == componentId);

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
  Future<ButtonComponentContext> getButtonPress(
    String componentId, {
    Duration? timeout,
    bool authorOnly = true,
  }) async {
    if (delegate != null) {
      return delegate!.getButtonPress(componentId, timeout: timeout, authorOnly: authorOnly);
    }

    ButtonComponentContext context =
        await commands.contextManager.createButtonComponentContext(await _getInteractionEvent(
      commands.interactions.events.onButtonEvent,
      componentId: componentId,
      timeout: timeout,
      authorOnly: authorOnly,
    ));

    context._parent = this;
    _delegate = context;

    return context;
  }

  @override
  Future<MultiselectComponentContext<T>> getSelection<T>(
    String componentId, {
    Duration? timeout,
    bool authorOnly = true,
    Converter<T>? converterOverride,
  }) async {
    if (delegate != null) {
      return delegate!.getSelection(
        componentId,
        timeout: timeout,
        authorOnly: authorOnly,
        converterOverride: converterOverride,
      );
    }

    IMultiselectInteractionEvent event = await _getInteractionEvent(
      commands.interactions.events.onMultiselectEvent,
      componentId: componentId,
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
      await parse(commands, _nearestCommandContext, StringView(rawContext.selected), DartType<T>()),
    );

    context._parent = this;
    _delegate = context;

    return context;
  }

  @override
  Future<MultiselectComponentContext<List<T>>> getMultiSelection<T>(
    String componentId, {
    Duration? timeout,
    bool authorOnly = true,
    Converter<T>? converterOverride,
  }) async {
    if (delegate != null) {
      return delegate!.getMultiSelection(
        componentId,
        authorOnly: authorOnly,
        converterOverride: converterOverride,
        timeout: timeout,
      );
    }

    IMultiselectInteractionEvent event = await _getInteractionEvent(
      commands.interactions.events.onMultiselectEvent,
      componentId: componentId,
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
      (rawContext) =>
          parse(commands, _nearestCommandContext, StringView(rawContext.selected), DartType<T>()),
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
      await interactionEvent.respond(builder, hidden: level.hideInteraction);
      return interactionEvent.getOriginalResponse();
    }
  }

  @override
  Future<void> acknowledge({ResponseLevel? level}) async {
    _responseLevel = level ??= _nearestCommandContext.command.resolvedOptions.defaultResponseLevel!;
    await interactionEvent.acknowledge(hidden: level.hideInteraction);
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
