import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/commands/chat_command.dart';
import 'package:nyxx_commands/src/commands/message_command.dart';
import 'package:nyxx_commands/src/commands/user_command.dart';
import 'package:nyxx_commands/src/context/autocomplete_context.dart';
import 'package:nyxx_commands/src/context/base.dart';
import 'package:nyxx_commands/src/context/chat_context.dart';
import 'package:nyxx_commands/src/errors.dart';
import 'package:nyxx_commands/src/util/view.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

class EventManager {
  final CommandsPlugin commands;

  EventManager(this.commands);

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
