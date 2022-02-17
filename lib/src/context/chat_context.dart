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

/// Represents a context in which a [ChatCommand] was invoked.
///
/// You might also be interested in:
/// - [MessageChatContext], for chat commands invoked from text messages;
/// - [InteractionChatContext], for chat commands invoked from slash commands.
abstract class IChatContext implements IContext {
  /// The arguments parsed from the user input.
  ///
  /// The arguments are ordered by the order in which they appear in the function delcaration. Since
  /// slash commands can specify optional arguments in any order, optional arguments declared before
  /// the last provided argument will be set to their default value (or `null` if unspecified).
  ///
  /// You might also be interested in:
  /// - [ChatCommand.execute], the function that dictates the order in which arguments are provided;
  /// - [Converter], the means by which these arguments are parsed.
  Iterable<dynamic> get arguments;

  /// Set the arguments used by this context.
  ///
  /// Should not be used unless you are implementing your own commannd handler.
  set arguments(Iterable<dynamic> value);

  @override
  ChatCommand get command;
}

class MessageChatContext with ComponentWrappersMixin implements IChatContext {
  final String prefix;

  final IMessage message;

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

class InteractionChatContext
    with InteractionContextMixin, ComponentWrappersMixin
    implements IChatContext, IInteractionContext {
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
