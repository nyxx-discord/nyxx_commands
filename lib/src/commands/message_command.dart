import 'dart:async';

import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_commands/src/checks/checks.dart';
import 'package:nyxx_commands/src/commands/interfaces.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_commands/src/context/message_context.dart';
import 'package:nyxx_commands/src/errors.dart';
import 'package:nyxx_commands/src/util/mixins.dart';

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
