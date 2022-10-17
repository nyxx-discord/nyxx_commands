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

import '../commands/message_command.dart';
import '../util/mixins.dart';
import 'base.dart';

/// A context in which a [MessageCommand] was executed.
///
/// You might also be interested in:
/// - [IInteractionCommandContext], the base class for all commands executed from an interaction.
class MessageContext extends ContextBase
    with InteractionRespondMixin, InteractiveMixin
    implements IInteractionCommandContext {
  @override
  final MessageCommand command;

  @override
  final ISlashCommandInteraction interaction;

  @override
  final ISlashCommandInteractionEvent interactionEvent;

  /// The message that the user selected when running this command.
  final IMessage targetMessage;

  /// Create a new [MessageContext].
  MessageContext({
    required this.targetMessage,
    required this.command,
    required this.interaction,
    required this.interactionEvent,
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
  });
}
