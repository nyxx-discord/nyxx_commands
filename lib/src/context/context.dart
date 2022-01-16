import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/commands/interfaces.dart';

abstract class IContext {
  /// The [CommandsPlugin] that triggered this context's execution.
  CommandsPlugin get commands;

  /// The [IGuild] in which this context was executed, if any.
  IGuild? get guild;

  /// The channel in which this context was executed.
  ITextChannel get channel;

  /// The member that triggered this context's execution, if any.
  ///
  /// This will notably be null when a command is run in a DM channel.
  /// If [guild] is not null, this is guaranteed to also be not null.
  IMember? get member;

  /// The user that triggered this context's execution.
  IUser get user;

  /// The command triggered in this context.
  ICommand get command;

  /// The [INyxx] client from which this command was dispatched
  INyxx get client;

  /// Send a response to the command.
  ///
  /// Setting `private` to true will ensure only the user that invoked the command sees the
  /// response:
  /// - For message contexts, a DM is sent to the invoking user;
  /// - For interaction contexts, an ephemeral response is used.
  Future<IMessage> respond(MessageBuilder builder, {bool private = false});
}
