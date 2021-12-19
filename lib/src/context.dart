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

  /// The [Guild] in which this context was executed, if any.
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
  Future<IMessage> send(MessageBuilder builder) => channel.sendMessage(builder);

  /// Send a response to the command. This is the same as [send] but it references the original
  /// command.
  Future<IMessage> respond(MessageBuilder builder);
}

/// Represents a [Context] triggered by a message sent in a text channel.
class MessageContext extends Context {
  /// The prefix that triggered this context's execution.
  final String prefix;

  /// The [Message] that triggered this context's execution.
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

  @override
  Future<IMessage> respond(MessageBuilder builder) async {
    try {
      return await channel.sendMessage(builder..replyBuilder = ReplyBuilder.fromMessage(message));
    } on IHttpResponseError {
      return channel.sendMessage(builder..replyBuilder = null);
    }
  }

  @override
  String toString() => 'MessageContext[message=$message, message.content=${message.content}]';
}

/// Represents a [Context] triggered by a slash command ([Interaction]).
class InteractionContext extends Context {
  /// The [Interaction] that triggered this context's execution.
  final ISlashCommandInteraction interaction;

  /// The [InteractionEvent] that triggered this context's exeecution.
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

  @override
  Future<IMessage> respond(MessageBuilder builder) => interactionEvent.sendFollowup(builder);

  @override
  String toString() =>
      'InteractionContext[interaction=${interaction.token}, arguments=$rawArguments]';
}
