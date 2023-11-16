import 'dart:async';

import 'package:nyxx/nyxx.dart';

import '../checks/checks.dart';
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
    implements Command<UserContext> {
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

  @override
  final Map<Locale, String>? localizedNames;

  /// Create a new [UserCommand].
  UserCommand(
    this.name,
    this.execute, {
    Iterable<AbstractCheck> checks = const [],
    this.options = const CommandOptions(),
    this.localizedNames,
  }) {
    for (final check in checks) {
      this.check(check);
    }
  }

  @override
  Future<void> invoke(UserContext context) async {
    for (final check in checks) {
      if (!await check.check(context)) {
        throw CheckFailedException(check, context);
      }
    }

    _preCallController.add(context);

    try {
      await execute(context);
    } catch (e) {
      throw UncaughtException(e, context);
    }

    _postCallController.add(context);
  }
}
