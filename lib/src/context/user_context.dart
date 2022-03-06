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

import '../commands.dart';
import '../commands/user_command.dart';
import '../context/component_wrappers.dart';
import '../context/interaction_context.dart';

/// Represents a context in which a [UserCommand] was executed.
class UserContext
    with InteractionContextMixin, ComponentWrappersMixin
    implements IInteractionContext {
  /// The member that was selected by the user when running the command if the command was invoked
  /// in a guild, `null` otherwise.
  final IMember? targetMember;

  /// The user that was selected by the user when running the command.
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
