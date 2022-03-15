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

import 'dart:async';

import '../checks/checks.dart';
import '../context/context.dart';
import '../context/message_context.dart';
import '../errors.dart';
import '../util/mixins.dart';
import 'interfaces.dart';
import 'options.dart';

/// Represents a [Discord Message Command](https://discord.com/developers/docs/interactions/application-commands#message-commands).
///
/// [MessageCommand]s are commands that can be invoked on a target message from the Discord client.
///
/// For example, a simple command that replies to the target message:
/// ```dart
/// MessageCommand test = MessageCommand(
///   'Test',
///   (MessageContext context) {
///     context.respond(
///       MessageBuilder()
///         ..content = 'This was the target message!'
///         ..replyBuilder = ReplyBuilder.fromMessage(context.targetMessage),
///     );
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/154338942-233ce3b0-5ccc-46f5-bf68-4e6dbaf8cdcd.png)
///
/// You might also be interested in:
/// - [CommandsPlugin.addCommand], for adding commands to your bot;;
/// - [ChatCommand], for creating chat commands;
/// - [UserCommand], for creating user commands.
class MessageCommand
    with ParentMixin<MessageContext>, CheckMixin<MessageContext>, OptionsMixin<MessageContext>
    implements ICommand<MessageContext> {
  @override
  final String name;

  final StreamController<MessageContext> _preCallController = StreamController.broadcast();
  final StreamController<MessageContext> _postCallController = StreamController.broadcast();

  @override
  late final Stream<MessageContext> onPreCall = _preCallController.stream;

  @override
  late final Stream<MessageContext> onPostCall = _postCallController.stream;

  @override
  final Function(MessageContext) execute;

  @override
  final CommandOptions options;

  /// Create a new [MessageCommand].
  MessageCommand(
    this.name,
    this.execute, {
    Iterable<AbstractCheck> checks = const [],
    this.options = const CommandOptions(),
  }) {
    for (final check in checks) {
      this.check(check);
    }
  }

  @override
  Future<void> invoke(IContext context) async {
    if (context is! MessageContext) {
      return;
    }

    for (final check in checks) {
      if (!await check.check(context)) {
        throw CheckFailedException(check, context);
      }
    }

    _preCallController.add(context);

    try {
      await execute(context);
    } on Exception catch (e) {
      throw UncaughtException(e, context);
    }

    _postCallController.add(context);
  }
}
