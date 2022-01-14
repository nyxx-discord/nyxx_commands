import 'dart:async';

import 'package:nyxx_commands/src/checks/checks.dart';
import 'package:nyxx_commands/src/commands/command.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/context/user_context.dart';
import 'package:nyxx_commands/src/errors.dart';

class UserCommand implements ICommand {
  @override
  final String name;

  @override
  String get description => '';

  @override
  final Function(UserContext) execute;

  @override
  final List<AbstractCheck> checks = [];

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
