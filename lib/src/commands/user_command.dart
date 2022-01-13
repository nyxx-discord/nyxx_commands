import 'dart:async';

import 'package:nyxx_commands/src/checks/checks.dart';
import 'package:nyxx_commands/src/commands/command.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/context/user_context.dart';
import 'package:nyxx_commands/src/errors.dart';

abstract class UserCommand implements Command {
  @override
  Function(UserContext) get execute;
}

class UserCommandImpl implements UserCommand {
  @override
  final String name;

  @override
  final String description;

  @override
  final Function(UserContext) execute;

  @override
  final List<AbstractCheck> checks = [];

  final StreamController<UserContext> preCallController = StreamController.broadcast();
  final StreamController<UserContext> postCallController = StreamController.broadcast();

  @override
  late final Stream<UserContext> onPreCall = preCallController.stream;

  @override
  late final Stream<UserContext> onPostCall = postCallController.stream;

  UserCommandImpl(
    this.name,
    this.description,
    this.execute, {
    Iterable<AbstractCheck> checks = const [],
  }) {
    for (final check in checks) {
      this.check(check);
    }
  }

  @override
  Future<void> invoke(Context context) async {
    if (context is! UserContext) {
      return;
    }

    for (final check in checks) {
      if (!await check.check(context)) {
        throw CheckFailedException(check, context);
      }
    }

    preCallController.add(context);

    try {
      await execute(context);
    } on Exception catch (e) {
      throw UncaughtException(e, context);
    }

    postCallController.add(context);
  }

  @override
  void check(AbstractCheck check) {
    checks.add(check);

    for (final preCallHook in check.preCallHooks) {
      onPreCall.listen(preCallHook);
    }

    for (final postCallHook in check.postCallHooks) {
      onPostCall.listen(postCallHook);
    }
  }
}
