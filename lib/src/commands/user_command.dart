import 'dart:async';

import 'package:nyxx_commands/src/checks/checks.dart';
import 'package:nyxx_commands/src/commands/interfaces.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/context/user_context.dart';
import 'package:nyxx_commands/src/errors.dart';
import 'package:nyxx_commands/src/util/mixins.dart';

class UserCommand
    with ParentMixin<UserContext>, CheckMixin<UserContext>
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

  UserCommand(
    this.name,
    this.execute, {
    Iterable<AbstractCheck> checks = const [],
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
