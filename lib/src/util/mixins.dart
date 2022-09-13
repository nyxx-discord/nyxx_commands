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
import 'package:nyxx_commands/src/context/component_context.dart';
import 'package:nyxx_commands/src/converters/converter.dart';
import 'package:nyxx_commands/src/util/view.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../checks/checks.dart';
import '../commands.dart';
import '../commands/chat_command.dart';
import '../commands/interfaces.dart';
import '../commands/options.dart';
import '../context/base.dart';
import '../errors.dart';

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
      hideOriginalResponse: options.hideOriginalResponse ?? parentOptions.hideOriginalResponse,
      type: options.type ?? parentType,
    );
  }
}

mixin InteractiveMixin implements IInteractiveContext, IContextData {
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
    Duration? timeout = const Duration(minutes: 10),
    bool authorOnly = true,
  }) async =>
      commands.contextManager.createButtonComponentContext(await _getInteractionEvent(
        commands.interactions.events.onButtonEvent,
        componentId: componentId,
        timeout: timeout,
        authorOnly: authorOnly,
      ));

  @override
  Future<MultiselectComponentContext<T>> getSelection<T>(
    String componentId, {
    Duration? timeout = const Duration(minutes: 10),
    bool authorOnly = true,
    Converter<T>? converterOverride,
  }) async {
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

    return commands.contextManager.createMultiselectComponentContext(
      event,
      // This isn't correct, rawContext will never be an ICommandContext.
      // TODO: Traverse tree to find nearest ICommandContext.
      await parse(commands, rawContext as ICommandContext, StringView(rawContext.selected), T) as T,
    );
  }

  @override
  Future<MultiselectComponentContext<List<T>>> getMultiSelection<T>(
    String componentId, {
    Duration? timeout = const Duration(minutes: 10),
    bool authorOnly = true,
    Converter<T>? converterOverride,
  }) async {
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
          // This isn't correct, rawContext will never be an ICommandContext.
          // TODO: Traverse tree to find nearest ICommandContext.
          parse(commands, rawContext as ICommandContext, StringView(rawContext.selected), T)
              as Future<T>,
    ));

    return commands.contextManager.createMultiselectComponentContext(
      event,
      values,
    );
  }
}
