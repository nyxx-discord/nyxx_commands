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

abstract class IContext {
  CommandsPlugin get commands;

  IGuild? get guild;

  ITextChannel get channel;

  IMember? get member;

  IUser get user;

  ICommand get command;

  INyxx get client;

  Future<IMessage> respond(MessageBuilder builder, {bool private = false});

  Future<IMultiselectInteractionEvent> getSelection(MultiselectBuilder selectionMenu,
      {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)});

  Future<IButtonInteractionEvent> getButtonPress(Iterable<ButtonBuilder> buttons,
      {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)});

  Future<bool> getConfirmation(MessageBuilder message,
      {bool authorOnly = true,
      Duration? timeout = const Duration(minutes: 12),
      String confirmMessage = 'Yes',
      String denyMessage = 'No'});
}
