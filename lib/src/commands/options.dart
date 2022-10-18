import '../context/base.dart';
import 'chat_command.dart';

/// Options that modify how a command behaves.
///
/// You might also be interested in:
/// - [IOptions], the interface for entities that support options;
/// - [CommandsOptions], the settings for the entire nyxx_commands package.
class CommandOptions {
  /// Whether to automatically acknowledge interactions before they expire.
  ///
  /// Sometimes, commands can take longer to complete than expected. However, Discord interactions
  /// have a 3 second timeout after receiving them, so nyxx_commands provides an automatic way to
  /// acknowledge these interactions to extend that limit to 15 minutes if your command does not
  /// respond fast enough.
  ///
  /// Setting this to false means that you must acknowledge the interaction yourself.
  ///
  /// You might also be interested in:
  /// - [autoAcknowledgeDuration], for setting the time after which interactions will be
  ///   acknowledged.
  /// - [IInteractionInteractiveContext.acknowledge], for manually acknowledging interactions.
  final bool? autoAcknowledgeInteractions;

  /// The duration after which to automatically acknowledge interactions.
  ///
  /// Has no effect if [autoAcknowledgeInteractions] is `false`.
  ///
  /// If this is `null`, the timeout for interactions is calculated based on the bot's latency. On
  /// unstable networks, this might result in some interactions not being acknowledged, in which
  /// case setting this option might help.
  final Duration? autoAcknowledgeDuration;

  /// Whether to accept messages sent by bot accounts as possible commands.
  ///
  /// If this is set to false, then other bot users will not be able to execute commands from this
  /// bot. If set to true, messages sent by other bots will be parsed anc checked for commands like
  /// other messages sent by actual users.
  ///
  /// You might also be interested in:
  /// - [acceptSelfCommands], for this same setting but for the current client.
  final bool? acceptBotCommands;

  /// Whether to accept messages sent by the bot itself as possible commands.
  ///
  /// [acceptBotCommands] must also be set to `true` for this setting to allow the current bot to
  /// execute its own commands. If this is set to false, messages sent by the bot itself are not
  /// checked for commands. If it is true, messages sent by the bot itself will be checked for
  /// commands like other messages sent by actual users.
  ///
  /// Care should be taken when setting this to `true` as it can potentially result in infinite
  /// command loops.
  final bool? acceptSelfCommands;

  /// The [ResponseLevel] to use in commands if not explicit.
  ///
  /// Defaults to [ResponseLevel.public].
  final ResponseLevel? defaultResponseLevel;

  /// The type of [ChatCommand]s that are children of this entity.
  ///
  /// The type of a [ChatCommand] influences how it can be invoked and can be used to make chat
  /// commands executable only through Slash Commands, or only through text messages.
  final CommandType? type;

  /// Whether command fetching should be case insensitive.
  ///
  /// If this is `true`, [ChatCommand]s may be invoked by users without the command name matching
  /// the case of the input.
  ///
  /// You might also be interested in:
  /// - [IChatCommandComponent.aliases], for invoking a single command from multiple names.
  final bool? caseInsensitiveCommands;

  /// Create a set of command options.
  ///
  /// Options set to `null` will be inherited from the parent.
  const CommandOptions({
    this.autoAcknowledgeInteractions,
    this.autoAcknowledgeDuration,
    this.acceptBotCommands,
    this.acceptSelfCommands,
    this.defaultResponseLevel,
    this.type,
    this.caseInsensitiveCommands,
  });
}
