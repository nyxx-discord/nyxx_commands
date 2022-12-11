import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'commands.dart';
import 'commands/chat_command.dart';
import 'commands/message_command.dart';
import 'commands/user_command.dart';
import 'context/autocomplete_context.dart';
import 'context/base.dart';
import 'context/chat_context.dart';
import 'context/component_context.dart';
import 'errors.dart';
import 'mirror_utils/mirror_utils.dart';
import 'util/util.dart';
import 'util/view.dart';

class EventManager {
  final CommandsPlugin commands;

  final Map<DartType<dynamic>,
      Map<ComponentId, Completer<dynamic /* covariant IComponentContext */ >>> _listeners = {};

  EventManager(this.commands);

  Future<T> _nextComponentEvent<T>(ComponentId id) {
    assert(T != dynamic);

    final type = DartType<T>();
    _listeners[type] ??= {};

    final completer = Completer<T>();
    _listeners[type]![id] ??= completer;

    if (id.expiresAt != null) {
      Timer(id.expiresIn!, () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException(null), StackTrace.current);
        }

        stopListeningFor(id);
      });
    }

    return completer.future;
  }

  Future<void>
      _processComponentEvent<T extends IComponentInteractionEvent, U extends IComponentContext>(
    T event,
    FutureOr<U> Function(T) converter,
  ) async {
    final id = ComponentId.parse(event.interaction.customId);

    if (id == null) {
      return;
    }

    U context = await converter(event);

    if (id.status != ComponentIdStatus.ok) {
      throw UnhandledInteractionException(context, id);
    }

    if (id.allowedUser != null && context.user.id != id.allowedUser) {
      throw UnhandledInteractionException(context, id.withStatus(ComponentIdStatus.wrongUser));
    }

    final listenerType = DartType<U>();
    final completer = _listeners[listenerType]?[id];

    if (completer == null) {
      throw UnhandledInteractionException(context, id.withStatus(ComponentIdStatus.noHandlerFound));
    }

    completer.complete(context);
    stopListeningFor(id);
  }

  Future<ButtonComponentContext> nextButtonEvent(ComponentId id) => _nextComponentEvent(id);

  Future<MultiselectComponentContext<List<String>>> nextMultiselectEvent(ComponentId id) =>
      _nextComponentEvent(id);

  Future<void> processButtonEvent(IButtonInteractionEvent event) => _processComponentEvent(
        event,
        commands.contextManager.createButtonComponentContext,
      );

  Future<void> processMultiselectEvent(IMultiselectInteractionEvent event) =>
      _processComponentEvent<IMultiselectInteractionEvent,
          MultiselectComponentContext<List<String>>>(
        event,
        (event) => commands.contextManager
            .createMultiselectComponentContext(event, event.interaction.values),
      );

  void stopListeningFor(ComponentId id) {
    for (final listenerMap in _listeners.values) {
      listenerMap.remove(id);
    }
  }

  Future<void> processMessage(IMessage message) async {
    Pattern prefix = await commands.prefix!(message);
    StringView view = StringView(message.content);

    Match? matchedPrefix = view.skipPattern(prefix);

    if (matchedPrefix != null) {
      IChatContext context = await commands.contextManager
          .createMessageChatContext(message, view, matchedPrefix.group(0)!);

      if (message.author.bot && !context.command.resolvedOptions.acceptBotCommands!) {
        return;
      }

      if (message.author.id == (commands.client as INyxxRest).self.id &&
          !context.command.resolvedOptions.acceptSelfCommands!) {
        return;
      }

      logger.fine('Invoking command ${context.command.name} from message $message');

      await context.command.invoke(context);
    }
  }

  Future<void> processInteractionCommand(IInteractionCommandContext context) async {
    if (context.command.resolvedOptions.autoAcknowledgeInteractions!) {
      Duration? timeout = context.command.resolvedOptions.autoAcknowledgeDuration;

      if (timeout == null) {
        Duration latency = const Duration(seconds: 1);

        final client = commands.client;
        if (client is INyxxWebsocket) {
          latency = client.shardManager.gatewayLatency;
        }

        timeout = const Duration(seconds: 3) - latency * 2;
      }

      timeout -= DateTime.now().difference(context.interactionEvent.receivedAt);

      Timer(timeout, () async {
        try {
          await context.acknowledge();
        } on AlreadyRespondedError {
          // ignore: command has responded itself
        }
      });
    }

    logger.fine('Invoking command ${context.command.name} '
        'from interaction ${context.interactionEvent.interaction.token}');

    await context.command.invoke(context);
  }

  Future<void> processChatInteraction(
    ISlashCommandInteractionEvent interactionEvent,
    ChatCommand command,
  ) async =>
      processInteractionCommand(
        await commands.contextManager.createInteractionChatContext(interactionEvent, command),
      );

  Future<void> processUserInteraction(
    ISlashCommandInteractionEvent interactionEvent,
    UserCommand command,
  ) async =>
      processInteractionCommand(
        await commands.contextManager.createUserContext(interactionEvent, command),
      );

  Future<void> processMessageInteraction(
    ISlashCommandInteractionEvent interactionEvent,
    MessageCommand command,
  ) async =>
      processInteractionCommand(
        await commands.contextManager.createMessageContext(interactionEvent, command),
      );

  Future<void> processAutocompleteInteraction(
    IAutocompleteInteractionEvent interactionEvent,
    FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext) callback,
    ChatCommand command,
  ) async {
    AutocompleteContext context =
        await commands.contextManager.createAutocompleteContext(interactionEvent, command);

    try {
      Iterable<ArgChoiceBuilder>? choices = await callback(context);

      interactionEvent.respond(choices?.toList() ?? []);
    } on Exception catch (e) {
      throw AutocompleteFailedException(e, context);
    }
  }
}
