import 'dart:async';

import 'package:nyxx/nyxx.dart';

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
      final expiresIn = id.expiresIn!;

      Timer(expiresIn, () {
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException(
              'Timed out waiting for interaction on $id',
              expiresIn,
            ),
            StackTrace.current,
          );
        }

        stopListeningFor(id);
      });
    }

    return completer.future;
  }

  Future<void> _processComponentEvent<U extends ComponentContext>(
    MessageComponentInteraction interaction,
    FutureOr<U> Function(MessageComponentInteraction) converter,
  ) async {
    final id = ComponentId.parse(interaction.data.customId);

    if (id == null) {
      return;
    }

    U context = await converter(interaction);

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
  /// select menu with id [id].
  ///
  /// If [id] has an expiration time, the future will complete with an error once that time is
  /// elapsed.
  Future<SelectMenuContext<List<String>>> nextSelectMenuEvent(ComponentId id) =>
      _nextComponentEvent(id);

  /// Stop listening for events from the component with id [id].
  ///
  /// Listeners waiting for events from this component will not be completed.
  void stopListeningFor(ComponentId id) {
    for (final listenerMap in _listeners.values) {
      listenerMap.remove(id);
    }
  }

  /// The handler for button [MessageComponentInteraction]s.
  ///
  /// Attach to [NyxxGateway.onMessageComponentInteraction] where the component is a button.
  Future<void> processButtonInteraction(MessageComponentInteraction interaction) =>
      _processComponentEvent(
        interaction,
        commands.contextManager.createButtonComponentContext,
      );

  /// The handler for select menu [MessageComponentInteraction]s.
  ///
  /// Attach to [NyxxGateway.onMessageComponentInteraction] where the component is a select menu.
  Future<void> processSelectMenuInteraction(MessageComponentInteraction interaction) =>
      _processComponentEvent<SelectMenuContext<List<String>>>(
        interaction,
        (event) => commands.contextManager.createSelectMenuContext(event, event.data.values!),
      );

  /// A handler for [MessageCreateEvent]s.
  ///
  /// Attach to [NyxxGateway.onMessageCreate].
  Future<void> processMessageCreateEvent(MessageCreateEvent event) async {
    if (commands.prefix == null) return;

    final message = event.message;

    Pattern prefix = await commands.prefix!(event);
    StringView view = StringView(message.content);

    Match? matchedPrefix = view.skipPattern(prefix);

    if (matchedPrefix != null) {
      ChatContext context = await commands.contextManager
          .createMessageChatContext(message, view, matchedPrefix.group(0)!);

      if (message.author is User &&
          (message.author as User).isBot &&
          !context.command.resolvedOptions.acceptBotCommands!) {
        return;
      }

      if (message.author.id == await event.gateway.client.users.fetchCurrentUser() &&
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
  Future<void> processInteractionCommand(InteractionCommandContext context) async {
    if (context.command.resolvedOptions.autoAcknowledgeInteractions!) {
      Duration? timeout = context.command.resolvedOptions.autoAcknowledgeDuration;

      if (timeout == null) {
        final latency = context.client.httpHandler.realLatency;
        timeout = const Duration(seconds: 3) - latency * 2;
      }

      Timer(timeout, () async {
        try {
          await context.acknowledge();
        } on AlreadyAcknowledgedError {
          // ignore: command has responded itself
        }
      });
    }

    logger.fine('Invoking command ${context.command.name} '
        'from interaction ${context.interaction.token}');

    await context.command.invoke(context);
  }

  /// A handler for chat [ApplicationCommandInteraction]s where the command is a chat command.
  ///
  /// Attach to [NyxxGateway.onApplicationCommandInteraction] where the command is a chat command.
  ///
  /// [command] is the [ChatCommand] resolved to be the target of the interaction.
  /// [options] are the options passed to the command in the [interaction], excluding subcommand
  /// options.
  Future<void> processChatInteraction(
    ApplicationCommandInteraction interaction,
    List<InteractionOption> options,
    ChatCommand command,
  ) async =>
      processInteractionCommand(
        await commands.contextManager.createInteractionChatContext(
          interaction,
          options,
          command,
        ),
      );

  /// A handler for chat [ApplicationCommandInteraction]s where the command is a user command.
  ///
  /// Attach to [NyxxGateway.onApplicationCommandInteraction] where the command is a user command.
  Future<void> processUserInteraction(
    ApplicationCommandInteraction interactionEvent,
    UserCommand command,
  ) async =>
      processInteractionCommand(
        await commands.contextManager.createUserContext(interactionEvent, command),
      );

  /// A handler for chat [ApplicationCommandInteraction]s where the command is a message command.
  ///
  /// Attach to [NyxxGateway.onApplicationCommandInteraction] where the command is a message
  /// command.
  Future<void> processMessageInteraction(
    ApplicationCommandInteraction interactionEvent,
    MessageCommand command,
  ) async =>
      processInteractionCommand(
        await commands.contextManager.createMessageContext(interactionEvent, command),
      );

  /// A handler for [ApplicationCommandAutocompleteInteraction]s.
  ///
  /// Attach to [NyxxGateway.onApplicationCommandAutocompleteInteraction].
  ///
  /// [callback] is the autocompletion callback for the focused option.
  /// [command] is the command the interaction is targeting.
  Future<void> processAutocompleteInteraction(
    ApplicationCommandAutocompleteInteraction interactionEvent,
    FutureOr<Iterable<CommandOptionChoiceBuilder<dynamic>>?> Function(AutocompleteContext) callback,
    ChatCommand command,
  ) async {
    AutocompleteContext context =
        await commands.contextManager.createAutocompleteContext(interactionEvent, command);

    try {
      Iterable<CommandOptionChoiceBuilder<dynamic>>? choices = await callback(context);

      interactionEvent.respond(choices?.toList() ?? []);
    } catch (e) {
      throw AutocompleteFailedException(e, context);
    }
  }
}
