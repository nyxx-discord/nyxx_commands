import 'package:nyxx_commands/src/checks/checks.dart';
import 'package:nyxx_commands/src/context/context.dart';

/// The base command class. All commands created by `nyxx_commands`, whether they be slash, user,
/// message or text commands inherit from this class.
abstract class Command {
  /// The name of this command.
  ///
  /// This must match [commandNameRegex] and be composed of the lowercase variant of letters where
  /// available if this command is a slash or text command.
  String get name;

  /// The description of this command. This must be less than 100 characters in length and may not
  /// be empty.
  String get description;

  /// An [Iterable] of checks that must succeed for this command to be executed.
  Iterable<AbstractCheck> get checks;

  /// The callback function for this command.
  ///
  /// The first argument to this function must be a [Context]. Slash and text commands might have
  /// additional parameter and optional parameter, but user and message commands may not have
  /// additional parameter.
  Function get execute;

  /// The function called to invoke the command.
  Future<void> invoke(Context context);
}
