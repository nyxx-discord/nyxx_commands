import 'dart:async';

import 'package:nyxx_commands/src/checks/checks.dart';
import 'package:nyxx_commands/src/commands/command.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/context/message_context.dart';
import 'package:nyxx_commands/src/errors.dart';

class MessageCommand implements ICommand {
  @override
  final String name;

  @override
  String get description => '';

  @override
  final List<AbstractCheck> checks = [];

  final StreamController<MessageContext> _preCallController = StreamController.broadcast();
  final StreamController<MessageContext> _postCallController = StreamController.broadcast();

  @override
  late final Stream<MessageContext> onPreCall = _preCallController.stream;

  @override
  late final Stream<MessageContext> onPostCall = _postCallController.stream;

  @override
  final Function(MessageContext) execute;

  MessageCommand(
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
