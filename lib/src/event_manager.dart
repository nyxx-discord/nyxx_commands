import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:runtime_type/runtime_type.dart';

import 'commands.dart';
import 'commands/chat_command.dart';
import 'commands/message_command.dart';
import 'commands/user_command.dart';
import 'context/autocomplete_context.dart';
import 'context/base.dart';
import 'context/chat_context.dart';
import 'context/component_context.dart';
import 'errors.dart';
import 'util/util.dart';
import 'util/view.dart';

/// A handler for events incoming from nyxx and nyxx_interactions, and listeners associated with
/// those events.
///
/// This class will listen to events from nyxx and nyxx_interactions, transform them into a
/// nyxx_commands class using [CommandsPlugin.contextManager] if needed and emit them to the correct
/// command handler or listener.
class EventManager {
  /// The [CommandsPlugin] this event manager is associated with.
  final CommandsPlugin commands;

  final Map<RuntimeType<dynamic>,
      Map<ComponentId, Completer<dynamic /* covariant IComponentContext */ >>> _listeners = {};

  /// Create a new [EventManager].
  EventManager(this.commands);

  Future<T> _nextComponentEvent<T>(ComponentId id) {
    assert(T != dynamic);

    final type = RuntimeType<T>();
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

    final listenerType = RuntimeType<U>();
    final completer = _listeners[listenerType]?[id];

    if (completer == null) {
      throw UnhandledInteractionException(context, id.withStatus(ComponentIdStatus.noHandlerFound));
    }

    completer.complete(context);
    stopListeningFor(id);
  }

  /// Get a future that completes with a context representing the next interaction on the button
  /// with id [id].
  ///
  /// If [id] has an expiration time, the future will complete with an error once that time is
  /// elapsed.
  Future<ButtonComponentContext> nextButtonEvent(ComponentId id) => _nextComponentEvent(id);

  /// Get a future that completes with a context representing the next interaction on the
  /// multiselect menu with id [id].
  ///
  /// If [id] has an expiration time, the future will complete with an error once that time is
  /// elapsed.
  Future<MultiselectComponentContext<List<String>>> nextMultiselectEvent(ComponentId id) =>
      _nextComponentEvent(id);

  /// Stop listening for events from the component with id [id].
  ///
  /// Listeners waiting for events from this component will not be completed.
  void stopListeningFor(ComponentId id) {
    for (final listenerMap in _listeners.values) {
      listenerMap.remove(id);
    }
  }

  /// The handler for [IButtonInteractionEvent]s. Attach to [IEventController.onButtonEvent].
  Future<void> processButtonEvent(IButtonInteractionEvent event) => _processComponentEvent(
        event,
        commands.contextManager.createButtonComponentContext,
      );

  /// The handler for [IMultiselectInteractionEvent]s. Attach to
  /// [IEventController.onMultiselectEvent].
  Future<void> processMultiselectEvent(IMultiselectInteractionEvent event) =>
      _processComponentEvent<IMultiselectInteractionEvent,
          MultiselectComponentContext<List<String>>>(
        event,
        (event) => commands.contextManager
            .createMultiselectComponentContext(event, event.interaction.values),
      );

  /// A handler for [IMessageReceivedEvent]s. Attach to
  /// [IWebsocketEventController.onMessageReceived], and pass in the inner [IMessage] object.
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

  /// A handler for generic interaction contexts.
  ///
  /// This handler takes in a context created by another handler and executes the associated
  /// command.
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

  /// A handler for chat [ISlashCommandInteractionEvent]s. Attach to
  /// [IEventController.onSlashCommand] and pass the [ChatCommand] for which the event was
  /// triggered, or use [SlashCommandBuilder.registerHandler].
  Future<void> processChatInteraction(
    ISlashCommandInteractionEvent interactionEvent,
    ChatCommand command,
  ) async =>
      processInteractionCommand(
        await commands.contextManager.createInteractionChatContext(interactionEvent, command),
      );

  /// A handler for user [ISlashCommandInteractionEvent]s. Attach to
  /// [IEventController.onSlashCommand] and pass the [UserCommand] for which the event was
  /// triggered, or use [SlashCommandBuilder.registerHandler].
  Future<void> processUserInteraction(
    ISlashCommandInteractionEvent interactionEvent,
    UserCommand command,
  ) async =>
      processInteractionCommand(
        await commands.contextManager.createUserContext(interactionEvent, command),
      );

  /// A handler for message [ISlashCommandInteractionEvent]s. Attach to
  /// [IEventController.onSlashCommand] and pass the [MessageCommand] for which the event was
  /// triggered, or use [SlashCommandBuilder.registerHandler].
  Future<void> processMessageInteraction(
    ISlashCommandInteractionEvent interactionEvent,
    MessageCommand command,
  ) async =>
      processInteractionCommand(
        await commands.contextManager.createMessageContext(interactionEvent, command),
      );

  /// A handler for [IAutocompleteInteractionEvent]s. Attach to
  /// [IEventController.onAutocompleteEvent] and pass in the autocompletion callback and the command
  /// for which the argument is being autocompleted, or use
  /// [CommandOptionBuilder.registerAutocompleteHandler].
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
    } catch (e) {
      throw AutocompleteFailedException(e, context);
    }
  }
}
