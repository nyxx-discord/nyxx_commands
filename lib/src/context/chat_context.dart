import 'package:nyxx/nyxx.dart';

import '../commands/chat_command.dart';
import '../util/mixins.dart';
import 'base.dart';

/// Data about a context in which a [ChatCommand] was executed.
///
/// You might also be interested in:
/// - [ChatContext], which exposes functionality for interacting with this context;
/// - [CommandContext], the base class for all contexts representing a command execution.
abstract interface class ChatContextData implements CommandContext {
  @override
  ChatCommand get command;
}

/// A context in which a [ChatCommand] was executed.
///
/// Contains data about how and where the command was executed, and provides a simple interfaces for
/// responding to commands.
///
/// You might also be interested in:
/// - [MessageChatContext], a context in which a [ChatCommand] was executed from a text message;
/// - [InteractionChatContext], a context in which a [ChatCommand] was executed from an interaction.
abstract interface class ChatContext implements ChatContextData, CommandContext {
  /// The arguments parsed from the user input.
  ///
  /// The arguments are ordered by the order in which they appear in the function declaration. Since
  /// slash commands can specify optional arguments in any order, optional arguments declared before
  /// the last provided argument will be set to their default value (or `null` if unspecified).
  ///
  /// You might also be interested in:
  /// - [ChatCommand.execute], the function that dictates the order in which arguments are provided;
  /// - [Converter], the means by which these arguments are parsed.
  // Arguments are only initialized during command execution, so we put them here to avoid them
  // being accessed before that.
  List<dynamic> get arguments;

  /// Set the arguments used by this context.
  ///
  /// Should not be used unless you are implementing your own command handler.
  set arguments(List<dynamic> value);
}

abstract class ChatContextBase extends ContextBase with InteractiveMixin implements ChatContext {
  @override
  late final List<dynamic> arguments;

  @override
  final ChatCommand command;

  ChatContextBase({
    required this.command,
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
  });
}

/// A context in which a [ChatCommand] was invoked from a text message.
///
/// You might also be interested in:
/// - [InteractionChatContext], a context in which a [ChatCommand] was executed from an interaction;
/// - [ChatContext], the base class for all context representing the execution of a [ChatCommand].
class MessageChatContext extends ChatContextBase with MessageRespondMixin {
  /// The message that triggered this command.
  @override
  final Message message;

  /// The prefix that was used to invoke this command.
  ///
  /// You might also be interested in:
  /// - [CommandsPlugin.prefix], the function called to determine the prefix to use for a given
  ///   message.
  final String prefix;

  /// The unparsed arguments from the message.
  ///
  /// This is the content of the message stripped of the [prefix] and the full command name.
  ///
  /// You might also be interested in:
  /// - [arguments], for getting the parsed arguments from this context.
  final String rawArguments;

  /// Create a new [MessageChatContext].
  MessageChatContext({
    required this.message,
    required this.prefix,
    required this.rawArguments,
    required super.command,
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
  });
}

/// A context in which a [ChatCommand] was invoked from an interaction.
///
/// You might also be interested in:
/// - [MessageChatContext], a context in which a [ChatCommand] was executed from a text message;
/// - [ChatContext], the base class for all context representing the execution of a [ChatCommand].
class InteractionChatContext extends ChatContextBase
    with InteractionRespondMixin
    implements InteractionCommandContext {
  @override
  final ApplicationCommandInteraction interaction;

  /// The unparsed arguments from the interaction.
  ///
  /// You might also be interested in:
  /// - [arguments], for getting the parsed arguments from this context.
  final Map<String, dynamic> rawArguments;

  /// Create a new [InteractionChatContext].
  InteractionChatContext({
    required this.rawArguments,
    required this.interaction,
    required super.command,
    required super.user,
    required super.member,
    required super.guild,
    required super.channel,
    required super.commands,
    required super.client,
  });
}
