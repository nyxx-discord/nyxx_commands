part of nyxx_commands;

/// Contains data about a command's execution context.
class Context {
  /// The list of arguments parsed from this context.
  late final List<dynamic> arguments;

  /// The bot that triggered this context's execution.
  final Bot bot;

  /// The [Guild] in which this context was executed, if any.
  final Guild? guild;

  /// The channel in which this context was executed.
  final TextChannel channel;

  /// The member that triggered this context's execution, if any.
  ///
  /// This will notably be null when a command is run in a DM channel.
  /// If [guild] is not null, this is guaranteed to also be not null.
  final Member? member;

  /// The user thatt triggered this context's execution.
  final User user;

  /// The command triggered in this context.
  final Command command;

  /// Construct a new [Context]
  Context({
    required this.bot,
    required this.guild,
    required this.channel,
    required this.member,
    required this.user,
    required this.command,
  });
}

/// Represents a [Context] triggered by a message sent in a text channel.
class MessageContext extends Context {
  /// The prefix that triggered this context's execution.
  final String prefix;

  /// The [Message] that triggered this context's execution.
  final Message message;

  /// The raw [String] that was used to parse this context's arguments, i.e the [message]s content
  /// with prefix and command [Command.fullName] stripped.
  final String rawArguments;

  /// Construct a new [MessageContext]
  MessageContext({
    required Bot bot,
    required Guild? guild,
    required TextChannel channel,
    required Member? member,
    required User user,
    required Command command,
    required this.prefix,
    required this.message,
    required this.rawArguments,
  }) : super(
          bot: bot,
          guild: guild,
          channel: channel,
          member: member,
          user: user,
          command: command,
        );
}

/// Represents a [Context] triggered by a slash command ([Interaction]).
class InteractionContext extends Context {
  /// The [Interaction] that triggered this context's execution.
  final SlashCommandInteraction interaction;

  /// The raw arguments received from the API, mapped by name to value.
  Map<String, dynamic> rawArguments;

  /// Construct a new [InteractionContext]
  InteractionContext({
    required Bot bot,
    required Guild? guild,
    required TextChannel channel,
    required Member? member,
    required User user,
    required Command command,
    required this.interaction,
    required this.rawArguments,
  }) : super(
          bot: bot,
          guild: guild,
          channel: channel,
          member: member,
          user: user,
          command: command,
        );
}
