import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../commands.dart';

/// Represents a check on a command.
///
/// A *check* is a function that is executed when a command is about to be invoked. A check can
/// either fail or succeed; if any of a command's checks fail then the execution of that command is
/// cancelled.
///
/// You might also be interested in:
/// - [Check], which allows you to construct checks with a simple callback;
/// - [Checked.check], which allows you to add checks to a command or command group;
/// - [CheckFailedException], the exception that is thrown and added to
///   [CommandsPlugin.onCommandError] when a check fails.
abstract class AbstractCheck {
  /// The name of this check.
  ///
  /// The name of a check has no effect. Instead, it can be used by the developer to identify the
  /// check that failed when a [CheckFailedException] is thrown.
  final String name;

  /// Create a new [AbstractCheck].
  ///
  /// Most developers will not need to extend [AbstractCheck] themselves. Instead, [Check] is more
  /// appropriate for checks that do not need to maintain state.
  AbstractCheck(this.name);

  /// Validate [context] against this check.
  ///
  /// If `true` is returned from this method, this check is considered to be *successful*, in which
  /// case the next check on the command is checked. Else, if `false` is returned, this check is
  /// considered to have *failed*, and the command will not be executed.
  ///
  /// This check's state should not be changed in [check]; instead, developers should use
  /// [preCallHooks] and [postCallHooks] to update the check's state.
  FutureOr<bool> check(CommandContext context);

  /// Whether this check will allow commands to be executed in DM channels.
  ///
  /// If this is `false`, users will be unable to execute slash commands in DM channels with the
  /// bot. However, users might still execute a text [ChatCommand] in DMs, so further validation in
  /// the check itself is required.
  ///
  /// You might also be interested in:
  /// - [requiredPermissions], for fine-tuning how commands can be executed in a guild.
  FutureOr<bool> get allowsDm;

  /// The permissions required from members to pass this check.
  ///
  /// If this is `null` (or `Future<Null>`), all members will be allowed to execute the command.
  ///
  /// Members that do not have at least one of these permissions will see the command as unavailable
  /// in their Discord client. However, users might still execute a text [ChatCommand], so further
  /// validation in the check itself is required.
  ///
  /// You might also be interested in:
  /// - [allowsDm], for controlling whether a command can be executed in a DM;
  /// - [Permissions], for finding the integer that represents a certain permission.
  FutureOr<Flags<Permissions>?> get requiredPermissions;

  /// An iterable of callbacks executed before a command is executed but after all the checks for
  /// that command have succeeded.
  ///
  /// These callbacks should be used to update this check's state.
  ///
  /// You might also be interested in:
  /// - [CallHooked.onPreCall], for registering arbitrary callbacks to be executed before a command
  ///   is executed but after all checks have succeeded;
  /// - [CommandsPlugin.onCommandError], where a [CheckFailedException] is added when a check for a
  ///   command fails.
  Iterable<void Function(CommandContext)> get preCallHooks;

  /// An iterable of callbacks executed after a command is executed.
  ///
  /// These callbacks should be used to update this check's state.
  ///
  /// You might also be interested in:
  /// - [CallHooked.onPostCall], for registering arbitrary callbacks to be executed after a command
  ///   is executed but after all checks have succeeded.
  Iterable<void Function(CommandContext)> get postCallHooks;

  @override
  String toString() => 'Check[name=$name]';
}

/// A simple, stateless check for commands.
///
/// See [AbstractCheck] for a description of what a *check* is.
///
/// A [Check] is a simple check with no state, which validates [CommandContext]s with a single
/// callback.
/// The check succeeds if the callback returns `true` and fails if the callback returns `false`.
///
/// For example, to only allow users with "evrything" in their name to execute a command:
/// ```dart
/// Check check = Check(
///   (context) => context.user.username.contains('evrything'),
/// );
///
/// commands.addCommand(ChatCommand(
///   'test',
///   'A test command',
///   (IChatContext context) => context.respond(MessageBuilder.content('Hi there!')),
///   checks: [check],
/// ));
///
/// commands.onCommandError.listen((error) {
///   if (error is CheckFailedException) {
///     error.context.respond(MessageBuilder.content("Sorry, you can't use that command!"));
///   }
/// });
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/153870085-6d27e4d2-1392-420e-9634-aa75648b93f1.png)
///
/// Since some checks are so common, nyxx_commands provides a set of in-built checks that also
/// integrate with the [Discord Slash Command Permissions](https://discord.com/developers/docs/interactions/application-commands#permissions)
/// API:
/// - [GuildCheck], for checking if a command was invoked in a specific guild.
///
/// You might also be interested in:
/// - [Check.any], [Check.deny] and [Check.all], for modifying the behaviour of checks;
/// - [AbstractCheck], which allows developers to create checks with state.
class Check extends AbstractCheck {
  final FutureOr<bool> Function(CommandContext) _check;

  @override
  final FutureOr<bool> allowsDm;

  @override
  final FutureOr<Flags<Permissions>?> requiredPermissions;

  /// Create a new [Check].
  ///
  /// [_check] should be a callback that returns `true` or `false` to indicate check success or
  /// failure respectively. [_check] should not throw to indicate failure.
  ///
  /// [name] can optionally be provided and will be used in error messages to identify this check.
  Check(
    this._check, {
    String name = 'Check',
    this.allowsDm = true,
    this.requiredPermissions,
  }) : super(name);

  /// Creates a check that succeeds if any of [checks] succeeds.
  ///
  /// When this check is queried, each of [checks] is queried and if any are successful then this
  /// check is successful. If all of [checks] fail, then this check is failed.
  ///
  /// Sometimes, developers might want to apply a check to all commands of a certain type. Instead
  /// of adding a check on each command of that type, nyxx_commands provides checks that will
  /// succeed when the context being checked is of a certain type:
  /// - [InteractionCommandCheck], to check if the context originated from an interaction;
  /// - [ChatCommandCheck], to check if the command being invoked is a chat command;
  /// - [MessageChatCommandCheck], to check if the context originated from a text message (only
  ///   applies to chat commands);
  /// - [InteractionChatCommandCheck], to check if the command being executed is a chat command and
  ///   that the context originated from an interaction;
  /// - [MessageCommandCheck], to check if the command being executed is a Message Command;
  /// - [UserCommandCheck], to check if the command being executed is a User Command.
  ///
  /// For example, to only apply a check only to commands invoked from a message command:
  ///
  /// ```dart
  /// commands.check(Check.any([
  ///   InteractionCommandCheck(),
  ///   Check((context) => context.user.username.contains('evrything')),
  /// ]));
  ///
  /// commands.addCommand(ChatCommand(
  ///   'test',
  ///   'A test command',
  ///   (IChatContext context) => context.respond(MessageBuilder.content('Hi there!')),
  /// ));
  ///
  /// commands.onCommandError.listen((error) {
  ///   if (error is CheckFailedException) {
  ///     error.context.respond(MessageBuilder.content("Sorry, you can't use that command!"));
  ///   }
  /// });
  /// ```
  ///
  /// ![](https://user-images.githubusercontent.com/54505189/153872224-b8a5f752-3ced-44ab-95f7-e6bb8058ba79.png)
  static AbstractCheck any(Iterable<AbstractCheck> checks, [String? name]) =>
      _AnyCheck(checks, name);

  /// Creates a check that succeeds if [check] fails.
  ///
  /// Note that [AbstractCheck.preCallHooks] and [AbstractCheck.postCallHooks] will therefore be executed if [check]
  /// *fails*, and not when [check] succeeds. Therefore, developers should take care that [check]
  /// does not assume it succeeded in its call hooks.
  static AbstractCheck deny(AbstractCheck check, {String? name}) => _DenyCheck(check, name: name);

  /// Creates a check that succeeds if all of [checks] succeed.
  ///
  /// This can be used to group checks that are commonly used together into a single, reusable
  /// check.
  static AbstractCheck all(Iterable<AbstractCheck> checks, {String? name}) =>
      _GroupCheck(checks, name: name);

  @override
  FutureOr<bool> check(CommandContext context) => _check(context);

  @override
  Iterable<void Function(CommandContext context)> get postCallHooks => [];

  @override
  Iterable<void Function(CommandContext context)> get preCallHooks => [];
}

class _AnyCheck extends AbstractCheck {
  Iterable<AbstractCheck> checks;

  final Expando<AbstractCheck> _successfulChecks = Expando();

  _AnyCheck(this.checks, [String? name])
      : super(name ?? 'Any of [${checks.map((e) => e.name).join(', ')}]') {
    if (checks.isEmpty) {
      throw Exception('Cannot check any of no checks');
    }
  }

  @override
  FutureOr<bool> check(CommandContext context) async {
    for (final check in checks) {
      FutureOr<bool> result = check.check(context);

      if (result is bool && result) {
        _successfulChecks[context] = check;
        return true;
      } else if (await result) {
        _successfulChecks[context] = check;
        return true;
      }
    }
    return false;
  }

  @override
  Iterable<void Function(CommandContext)> get preCallHooks => [
        (context) {
          AbstractCheck? actualCheck = _successfulChecks[context];

          if (actualCheck == null) {
            logger.warning("Context $context shouldn't have passed checks; actualCheck is null");
            return;
          }

          for (final hook in actualCheck.preCallHooks) {
            hook(context);
          }
        }
      ];

  @override
  Iterable<void Function(CommandContext)> get postCallHooks => [
        (context) {
          AbstractCheck? actualCheck = _successfulChecks[context];

          if (actualCheck == null) {
            logger.warning("Context $context shouldn't have passed checks; actualCheck is null");
            return;
          }

          for (final hook in actualCheck.postCallHooks) {
            hook(context);
          }
        }
      ];

  @override
  Future<bool> get allowsDm async {
    for (final check in checks) {
      if (await check.allowsDm) {
        return true;
      }
    }

    return false;
  }

  @override
  Future<Flags<Permissions>?> get requiredPermissions async {
    Flags<Permissions> result = Permissions(0);

    for (final check in checks) {
      final permissions = await check.requiredPermissions;

      if (permissions == null) {
        return null;
      }

      result |= permissions;
    }

    return result;
  }
}

class _DenyCheck extends Check {
  final AbstractCheck source;

  _DenyCheck(this.source, {String? name})
      : super(
          name: name ?? 'Denied ${source.name}',
          (context) async => !(await source.check(context)),
        );

  // It may seem counterintuitive to call the success hooks if the source check failed, and this is
  // a situation where there is no proper solution. Here, we assume that the source check will
  // reset its state on failure after failure, so calling the hooks is desireable.
  @override
  Iterable<void Function(CommandContext)> get preCallHooks => source.preCallHooks;

  @override
  Iterable<void Function(CommandContext)> get postCallHooks => source.postCallHooks;

  @override
  FutureOr<bool> get allowsDm async => !await source.allowsDm;

  @override
  FutureOr<Flags<Permissions>?> get requiredPermissions async {
    final permissions = await source.requiredPermissions;

    if (permissions == null) {
      return null;
    }

    return ~permissions & Permissions.allPermissions;
  }
}

class _GroupCheck extends Check {
  final Iterable<AbstractCheck> checks;

  _GroupCheck(this.checks, {String? name})
      : super(
          name: name ?? 'All of [${checks.map((e) => e.name).join(', ')}]',
          (context) async {
            Iterable<FutureOr<bool>> results = checks.map((e) => e.check(context));

            Iterable<Future<bool>> asyncResults = results.whereType<Future<bool>>();
            Iterable<bool> syncResults = results.whereType<bool>();

            return !syncResults.contains(false) &&
                !(await Future.wait(asyncResults)).contains(false);
          },
        );

  @override
  Iterable<void Function(CommandContext)> get preCallHooks =>
      checks.map((e) => e.preCallHooks).expand((_) => _);

  @override
  Iterable<void Function(CommandContext)> get postCallHooks =>
      checks.map((e) => e.postCallHooks).expand((_) => _);

  @override
  FutureOr<bool> get allowsDm async {
    for (final check in checks) {
      if (!await check.allowsDm) {
        return false;
      }
    }

    return true;
  }

  @override
  FutureOr<Flags<Permissions>?> get requiredPermissions async {
    Iterable<Flags<Permissions>> permissions = (await Future.wait(
      checks.map(
        (e) => Future.value(
          e.requiredPermissions,
        ),
      ),
    ))
        .whereType<Flags<Permissions>>();

    if (permissions.isEmpty) {
      return null;
    }

    Flags<Permissions> result = Permissions.allPermissions;

    for (final permission in permissions) {
      result &= permission;
    }

    return result;
  }
}
