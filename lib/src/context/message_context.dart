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
import 'package:nyxx_interactions/src/models/interaction.dart';
import 'package:nyxx_interactions/src/events/interaction_event.dart';

import '../commands.dart';
import '../commands/message_command.dart';
import 'component_wrappers.dart';
import 'interaction_context.dart';

/// Representsa  context in which a [MessageCommand] was executed.
class MessageContext
    with InteractionContextMixin, ComponentWrappersMixin
    implements IInteractionContext {
  /// The messsage that the user selected when running this command.
  final IMessage targetMessage;

  @override
  final ITextChannel channel;

  @override
  final INyxx client;

  @override
  final MessageCommand command;

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

  /// Create a new [MessageContext].
  MessageContext({
    required this.targetMessage,
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
  String toString() => 'MessageContext[interaction=${interaction.token}, message=$targetMessage}]';
}
