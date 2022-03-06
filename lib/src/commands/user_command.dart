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
import '../context/user_context.dart';
import '../errors.dart';
import '../util/mixins.dart';
import 'interfaces.dart';
import 'options.dart';

/// Represents a [Discord User Command](https://discord.com/developers/docs/interactions/application-commands#user-commands).
///
/// [UserCommand]s are commands that can be invoked on a target user from the Discord client.
///
/// For example, a simple command that mentions the target user:
/// ```dart
/// test = UserCommand(
///   'Test',
///   (UserContext context) {
///     context.respond(MessageBuilder.content('${context.targetMember?.mention} was the target!'));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/154343978-dd0a2155-d6fb-42f1-afe5-eb9701e43122.png)
///
/// You might also be interested in:
/// - [CommandsPlugin.addCommand], for adding commands to your bot;
/// - [ChatCommand], for creating chat commands;
/// - [MessageCommand], for creating message commands.
class UserCommand
    with ParentMixin<UserContext>, CheckMixin<UserContext>, OptionsMixin<UserContext>
    implements ICommand<UserContext> {
  @override
  final String name;

  @override
  final Function(UserContext) execute;

  final StreamController<UserContext> _preCallController = StreamController.broadcast();
  final StreamController<UserContext> _postCallController = StreamController.broadcast();

  @override
  late final Stream<UserContext> onPreCall = _preCallController.stream;

  @override
  late final Stream<UserContext> onPostCall = _postCallController.stream;

  @override
  final CommandOptions options;

  /// Create a new [UserCommand].
  UserCommand(
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
    if (context is! UserContext) {
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
