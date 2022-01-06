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

import 'command.dart';
import 'commands.dart';

/// Contains data about a command's execution context.
abstract class Context {
  /// The list of arguments parsed from this context.
  late final Iterable<dynamic> arguments;

  /// The [CommandsPlugin] that triggered this context's execution.
  final CommandsPlugin commands;

  /// The [IGuild] in which this context was executed, if any.
  final IGuild? guild;

  /// The channel in which this context was executed.
  final ITextChannel channel;

  /// The member that triggered this context's execution, if any.
  ///
  /// This will notably be null when a command is run in a DM channel.
  /// If [guild] is not null, this is guaranteed to also be not null.
  final IMember? member;

  /// The user that triggered this context's execution.
  final IUser user;

  /// The command triggered in this context.
  final Command command;

  /// The [INyxx] client from which this command was dispatched
  final INyxx client;

  /// Construct a new [Context]
  Context({
    required this.commands,
    required this.guild,
    required this.channel,
    required this.member,
    required this.user,
    required this.command,
    required this.client,
  });

  /// Send a message to this context's [channel].
  @Deprecated('Use context.respond(), or context.channel.sendMessage() instead')
  Future<IMessage> send(MessageBuilder builder) => channel.sendMessage(builder);

  /// Send a response to the command. This is the same as [send] but it references the original
  /// command.
  ///
  /// Setting `private` to true will ensure only the user that invoked the command sees the
  /// response:
  /// - For message contexts, a DM is sent to the invoking user;
  /// - For interaction contexts, an ephemeral response is used.
  Future<IMessage> respond(MessageBuilder builder, {bool private = false});
}

/// Represents a [Context] triggered by a message sent in a text channel.
class MessageContext extends Context {
  /// The prefix that triggered this context's execution.
  final String prefix;

  /// The [IMessage] that triggered this context's execution.
  final IMessage message;

  /// The raw [String] that was used to parse this context's arguments, i.e the [message]s content
  /// with prefix and command [Command.fullName] stripped.
  final String rawArguments;

  /// Construct a new [MessageContext]
  MessageContext({
    required CommandsPlugin commands,
    required IGuild? guild,
    required ITextChannel channel,
    required IMember? member,
    required IUser user,
    required Command command,
    required INyxx client,
    required this.prefix,
    required this.message,
    required this.rawArguments,
  }) : super(
          commands: commands,
          guild: guild,
          channel: channel,
          member: member,
          user: user,
          command: command,
          client: client,
        );

  /// Send a response to the command. This is the same as [send] but it references the original
  /// command.
  ///
  /// You can set [mention] to `false` to prevent the reply from mentionning the user.
  /// If [MessageBuilder.allowedMentions] is not `null` on [builder], [mention] will be ignored. If
  /// not, the allowed mentions for [builder] will be set to allow all, with the exception of reply
  /// mentions being set to [mention].
  @override
  Future<IMessage> respond(MessageBuilder builder,
      {bool mention = true, bool private = false}) async {
    if (private) {
      return await user.sendMessage(builder);
    } else {
      try {
        return await channel.sendMessage(builder
          ..replyBuilder = ReplyBuilder.fromMessage(message)
          ..allowedMentions ??= (AllowedMentions()
            ..allow(
              reply: mention,
              everyone: true,
              roles: true,
              users: true,
            )));
      } on IHttpResponseError {
        return channel.sendMessage(builder..replyBuilder = null);
      }
    }
  }

  @override
  String toString() => 'MessageContext[message=$message, message.content=${message.content}]';
}

/// Represents a [Context] triggered by a slash command ([ISlashCommandInteraction]).
class InteractionContext extends Context {
  /// The [ISlashCommandInteraction] that triggered this context's execution.
  final ISlashCommandInteraction interaction;

  /// The [ISlashCommandInteractionEvent] that triggered this context's exeecution.
  final ISlashCommandInteractionEvent interactionEvent;

  /// The raw arguments received from the API, mapped by name to value.
  Map<String, dynamic> rawArguments;

  /// Construct a new [InteractionContext]
  InteractionContext({
    required CommandsPlugin commands,
    required IGuild? guild,
    required ITextChannel channel,
    required IMember? member,
    required IUser user,
    required Command command,
    required INyxx client,
    required this.interaction,
    required this.rawArguments,
    required this.interactionEvent,
  }) : super(
          commands: commands,
          guild: guild,
          channel: channel,
          member: member,
          user: user,
          command: command,
          client: client,
        );

  bool _hasCorrectlyAcked = false;
  late bool _originalAckHidden = commands.options.hideOriginalResponse;

  /// Send a response to the command. This is the same as [send] but it references the original
  /// command.
  ///
  /// You can set [hidden] to `true` to send an ephemeral response. Setting [hidden] to a value
  /// different that [CommandsOptions.hideOriginalResponse] will result in unusual behaviour if this
  /// method is invoked more than two seconds after command execution starts.
  /// Calling [acknowledge] less than two seconds after command execution starts with the same value
  /// for [hidden] as this invocation will prevent this unusual behaviour from happening.
  ///
  /// [hidden] will override the value of [private] if both are provided.
  @override
  Future<IMessage> respond(MessageBuilder builder, {bool private = false, bool? hidden}) async {
    hidden ??= private;

    if (_hasCorrectlyAcked) {
      return interactionEvent.sendFollowup(builder, hidden: hidden);
    } else {
      _hasCorrectlyAcked = true;
      try {
        await interactionEvent.acknowledge(hidden: hidden);
      } on AlreadyRespondedError {
        // interaction was already ACKed by timeout or [acknowledge], hidden state of ACK might not
        // be what we expect
        if (_originalAckHidden != hidden) {
          await interactionEvent
              .sendFollowup(MessageBuilder.content(MessageBuilder.clearCharacter));
          if (!_originalAckHidden) {
            // If original response was hidden, we can't delete it
            await interactionEvent.deleteOriginalResponse();
          }
        }
      }
      return interactionEvent.sendFollowup(builder, hidden: hidden);
    }
  }

  /// Acknowledge the underlying [interactionEvent].
  ///
  /// This allows you to acknowledge the interaction with a different hidden state that
  /// [CommandsOptions.hideOriginalResponse].
  ///
  /// If unspecified, [hidden] will be set to [CommandsOptions.hideOriginalResponse].
  ///
  /// Prefer using this method over calling [ISlashCommandInteractionEvent.acknowledge] on
  /// [interactionEvent] as this method will fix any unusual behaviour with [respond].
  ///
  /// If called within 2 seconds of command execution, this will override the auto-acknowledge
  /// induced by [CommandsOptions.autoAcknowledgeInteractions].
  /// If called  after 2 seconds, an [AlreadyRespondedError] will be thrown as nyxx_commands will
  /// automatically responded to avoid a token timeout.
  Future<void> acknowledge({bool? hidden}) async {
    await interactionEvent.acknowledge(hidden: hidden ?? commands.options.hideOriginalResponse);
    _originalAckHidden = hidden ?? commands.options.hideOriginalResponse;
  }

  @override
  String toString() =>
      'InteractionContext[interaction=${interaction.token}, arguments=$rawArguments]';
}
