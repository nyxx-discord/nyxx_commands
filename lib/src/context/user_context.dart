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
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/commands/user_command.dart';
import 'package:nyxx_commands/src/context/component_wrappers.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/context/interaction_context.dart';
import 'package:nyxx_interactions/src/models/interaction.dart';
import 'package:nyxx_interactions/src/events/interaction_event.dart';

/// Represents a [IContext] in which a [UserCommand] was executed.
class UserContext
    with InteractionContextMixin, ComponentWrappersMixin
    implements IInteractionContext {
  /// The target member for this context.
  final IMember? targetMember;

  /// The target user for this context, or the user representing [targetMember].
  final IUser targetUser;

  @override
  final ITextChannel channel;

  @override
  final INyxx client;

  @override
  final UserCommand command;

  @override
  final CommandsPlugin commands;

  @override
  final IGuild? guild;

  @override
  final IMember? member;

  @override
  final IUser user;

  @override
  final ISlashCommandInteraction interaction;

  @override
  final ISlashCommandInteractionEvent interactionEvent;

  UserContext({
    required this.targetMember,
    required this.targetUser,
    required this.channel,
    required this.client,
    required this.command,
    required this.commands,
    required this.guild,
    required this.member,
    required this.user,
    required this.interaction,
    required this.interactionEvent,
  });

  @override
  String toString() => 'UserContext[interaction=${interaction.token}, target=$targetUser]';
}
