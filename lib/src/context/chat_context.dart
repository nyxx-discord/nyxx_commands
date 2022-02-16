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
import 'package:nyxx_commands/src/context/component_wrappers.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/context/interaction_context.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../commands.dart';
import '../commands/chat_command.dart';

/// Represents a [IContext] in which a [ChatCommand] was executed.
abstract class IChatContext implements IContext {
  /// The list of arguments parsed from this context.
  Iterable<dynamic> get arguments;
  set arguments(Iterable<dynamic> value);

  @override
  ChatCommand get command;
}

/// Represents a [IChatContext] triggered by a message sent in a text channel.
class MessageChatContext with ComponentWrappersMixin implements IChatContext {
  /// The prefix that triggered this context's execution.
  final String prefix;

  /// The [IMessage] that triggered this context's execution.
  final IMessage message;

  /// The raw [String] that was used to parse this context's arguments, i.e the [message]s content
  /// with prefix and command [ChatCommand.fullName] stripped.
  final String rawArguments;

  @override
  late final Iterable<dynamic> arguments;

  @override
  final ITextChannel channel;

  @override
  final INyxx client;

  @override
  final ChatCommand command;

  @override
  final CommandsPlugin commands;

  @override
  final IGuild? guild;

  @override
  final IMember? member;

  @override
  final IUser user;

  MessageChatContext({
    required this.prefix,
    required this.message,
    required this.rawArguments,
    required this.channel,
    required this.client,
    required this.command,
    required this.commands,
    required this.guild,
    required this.member,
    required this.user,
  });

  /// Send a response to the command.
  ///
  /// Setting `private` to true will ensure only the user that invoked the command sees the
  /// response:
  /// - For message contexts, a DM is sent to the invoking user;
  /// - For interaction contexts, an ephemeral response is used.
  ///
  /// You can set [mention] to `false` to prevent the reply from mentionning the user.
  /// If [MessageBuilder.allowedMentions] is not `null` on [builder], [mention] will be ignored. If
  /// not, the allowed mentions for [builder] will be set to allow all, with the exception of reply
  /// mentions being set to [mention].
  @override
  Future<IMessage> respond(MessageBuilder builder,
      {bool mention = true, bool private = false}) async {
    if (private) {
      return user.sendMessage(builder);
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

/// Represents a [IChatContext] triggered by a slash command ([ISlashCommandInteraction]).
class InteractionChatContext
    with InteractionContextMixin, ComponentWrappersMixin
    implements IChatContext, IInteractionContext {
  /// The raw arguments received from the API, mapped by name to value.
  final Map<String, dynamic> rawArguments;

  @override
  late final Iterable<dynamic> arguments;

  @override
  final ITextChannel channel;

  @override
  final INyxx client;

  @override
  final ChatCommand command;

  @override
  final CommandsPlugin commands;

  @override
  final IGuild? guild;

  @override
  final ISlashCommandInteraction interaction;

  @override
  final ISlashCommandInteractionEvent interactionEvent;

  @override
  final IMember? member;

  @override
  final IUser user;

  InteractionChatContext({
    required this.rawArguments,
    required this.channel,
    required this.client,
    required this.command,
    required this.commands,
    required this.guild,
    required this.interaction,
    required this.interactionEvent,
    required this.member,
    required this.user,
  });

  @override
  String toString() =>
      'InteractionContext[interaction=${interaction.token}, arguments=$rawArguments]';
}
