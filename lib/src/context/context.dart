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
import '../commands/interfaces.dart';

/// A context in which a command was executed.
///
/// Contains data about how and where the command was executed, and provides a simple interfaces for
/// responding to commands.
abstract class IContext {
  /// The instance of [CommandsPlugin] which created this context.
  CommandsPlugin get commands;

  /// The guild in which the command was executed, or `null` if invoked outside of a guild.
  IGuild? get guild;

  /// The channel in which the command was executed.
  ITextChannel get channel;

  /// The member that executed the command, or `null` if invoked outside of a guild.
  IMember? get member;

  /// The user that executed the command.
  IUser get user;

  /// The command that was executed.
  ICommand get command;

  /// The client that emitted the event triggering this command.
  INyxx get client;

  /// Send a response to the command.
  ///
  /// If [private] is set to `true`, then the response will only be made visible to the user that
  /// invoked the command. In interactions, this is done by sending an ephemeral response, in text
  /// commands this is handled by sending a Private Message to the user.
  ///
  /// You might also be interested in:
  /// - [IInteractionContext.acknowledge], for acknowledging interactions without resopnding.
  Future<IMessage> respond(MessageBuilder builder, {bool private = false});

  /// Wait for a user to make a selection from a multiselect menu, then return the result of that
  /// interaction.
  ///
  /// If [authorOnly] is `true`, only events triggered by the author of this context will be
  /// returned, but other interactions will still be acknowledged.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout].
  Future<IMultiselectInteractionEvent> getSelection(MultiselectBuilder selectionMenu,
      {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)});

  /// Wait for a user to press on a button, then return the result of that interaction.
  ///
  /// This method specifically listens for interactions on items of [buttons], ignoring other button
  /// presses.
  ///
  /// If [authorOnly] is `true`, only events triggered by the author of this context will be
  /// returned, but other interactions will still be acknowledged.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout].
  ///
  /// You might also be interested in:
  /// - [getConfirmation], a shortcut for getting user confirmation from buttons.
  Future<IButtonInteractionEvent> getButtonPress(Iterable<ButtonBuilder> buttons,
      {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)});

  /// Send a message prompting a user for confirmation, then return whether the user accepted the
  /// choice.
  ///
  /// If [authorOnly] is `true`, only events triggered by the author of this context will be
  /// returned, but other interactions will still be acknowledged.
  ///
  /// If [timeout] is set, this method will complete with an error after [timeout].
  ///
  /// [confirmMessage] and [denyMessage] can be set to change the text displayed on the "confirm"
  /// and "deny" buttons.
  Future<bool> getConfirmation(MessageBuilder message,
      {bool authorOnly = true,
      Duration? timeout = const Duration(minutes: 12),
      String confirmMessage = 'Yes',
      String denyMessage = 'No'});
}
