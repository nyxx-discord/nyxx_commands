import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/commands/command.dart';

abstract class Context {
  /// The [CommandsPlugin] that triggered this context's execution.
  final CommandsPlugin commands;

  /// The [IGuild] in which this context was executed, if any.
  final IGuild? guild;

  /// The channel in which this context was executed.
  final ITextChannel channel;

  /// The member that triggered this context's execution, if any.
  ///
  /// This will notably be null when a command is run in a DM channel.
  /// If [guild] is not null, this is guaranteed to also be not null.
  final IMember? member;

  /// The user that triggered this context's execution.
  final IUser user;

  /// The command triggered in this context.
  final Command command;

  /// The [INyxx] client from which this command was dispatched
  final INyxx client;

  Context({
    required this.commands,
    required this.guild,
    required this.channel,
    required this.member,
    required this.user,
    required this.command,
    required this.client,
  });

  /// Send a response to the command.
  ///
  /// Setting `private` to true will ensure only the user that invoked the command sees the
  /// response:
  /// - For message contexts, a DM is sent to the invoking user;
  /// - For interaction contexts, an ephemeral response is used.
  Future<IMessage> respond(MessageBuilder builder, {bool private = false});
}
