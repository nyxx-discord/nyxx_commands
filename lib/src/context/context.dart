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
import 'package:nyxx_commands/src/commands/interfaces.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

/// The base context class.
///
/// A context is an environment in which a command is executed, and provides access to data about
/// how and where the command was executed.
abstract class IContext {
  /// The [CommandsPlugin] that triggered this context's execution.
  CommandsPlugin get commands;

  /// The [IGuild] in which this context was executed, if any.
  IGuild? get guild;

  /// The channel in which this context was executed.
  ITextChannel get channel;

  /// The member that triggered this context's execution, if any.
  ///
  /// This will notably be null when a command is run in a DM channel.
  /// If [guild] is not null, this is guaranteed to also be not null.
  IMember? get member;

  /// The user that triggered this context's execution.
  IUser get user;

  /// The command triggered in this context.
  ICommand get command;

  /// The [INyxx] client from which this command was dispatched
  INyxx get client;

  /// Send a response to the command.
  ///
  /// Setting `private` to true will ensure only the user that invoked the command sees the
  /// response:
  /// - For message contexts, a DM is sent to the invoking user;
  /// - For interaction contexts, an ephemeral response is used.
  Future<IMessage> respond(MessageBuilder builder, {bool private = false});

  /// Wait for a user to make a selection on a dropdown menu, and return the event.
  ///
  /// If [authorOnly] is set to `true`, only selections made by the author of this context will
  /// be returned.
  ///
  /// [selectionMenu] must have [MultiselectBuilder.customId] set to differentiate it from other
  /// dropdown menus.
  ///
  /// This method does not send any messages; you must send the message yourself.
  ///
  /// If [timeout] is provided, this method will return an error after the specified time, allowing
  /// you to respond before this context's token expires.
  ///
  /// All events triggered by [selectionMenu] are acknowledged until this method returns.
  Future<IMultiselectInteractionEvent> getSelection(MultiselectBuilder selectionMenu,
      {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)});

  /// Wait for a user to press a button, and return the event.
  ///
  /// If [authorOnly] is set to `true`, only button presses made by the author of this context will
  /// be returned.
  ///
  /// Each element of [buttons] must have [ButtonBuilder.customId] set to differentiate it from
  /// other buttons.
  ///
  /// This method does not send any messages; you must send the message yourself.
  ///
  /// If [timeout] is provided, this method will return an error after the specified time, allowing
  /// you to respond before this context's token expires.
  ///
  /// All events triggered by any of [buttons] are acknowledged until this method returns.
  Future<IButtonInteractionEvent> getButtonPress(Iterable<ButtonBuilder> buttons,
      {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)});

  /// Send [message] with a confirmation and rejection button, wait for a response, and return the
  /// response as a boolean.
  ///
  /// If [authorOnly] is set to `true`, only button presses made by the author of this context will
  /// be returned.
  ///
  /// If [timeout] is provided, this method will return an error after the specified time, allowing
  /// you to respond before this context's token expires.
  ///
  /// All events triggered by any of the buttons sent with the message are acknowledged until this
  /// method returns.
  Future<bool> getConfirmation(MessageBuilder message,
      {bool authorOnly = true,
      Duration? timeout = const Duration(minutes: 12),
      String confirmMessage = 'Yes',
      String denyMessage = 'No'});
}
