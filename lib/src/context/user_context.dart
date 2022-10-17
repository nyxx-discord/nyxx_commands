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

import '../commands/user_command.dart';
import '../util/mixins.dart';
import 'base.dart';

/// A context in which a [UserCommand] was executed.
///
/// You might also be interested in:
/// - [IInteractionCommandContext], the base class for all commands executed from an interaction.
class UserContext extends ContextBase
    with InteractionRespondMixin, InteractiveMixin
    implements IInteractionCommandContext {
  @override
  final UserCommand command;

  @override
  final ISlashCommandInteraction interaction;

  @override
  final ISlashCommandInteractionEvent interactionEvent;

  /// The member that was selected by the user when running the command if the command was invoked
  /// in a guild, `null` otherwise.
  final IMember? targetMember;

  /// The user that was selected by the user when running the command.
  final IUser targetUser;

  /// Create a new [UserContext].
  UserContext({
    required this.targetMember,
    required this.targetUser,
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
