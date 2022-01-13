import 'package:nyxx_interactions/nyxx_interactions.dart';

/// Optional commands options.
class CommandsOptions {
  /// Whether to log [CommandsException]s that occur when received from
  /// [CommandsPlugin.onCommandError].
  final bool logErrors;

  /// Whether to automatically acknowledge slash command interactions if they are not acknowledged
  /// or responded to within 2s of command invocation.
  ///
  /// If you set this to false, you *must* respond to the interaction yourself, or the command will fail.
  final bool autoAcknowledgeInteractions;

  /// Whether to process commands coming from bot users on Discord.
  final bool acceptBotCommands;

  /// Whether to process commands coming from the bot's own user.
  ///
  /// Setting this to `true` might result in infinite loops.
  /// [acceptBotCommands] must also be set to true for this to have any effect.
  final bool acceptSelfCommands;

  /// A custom [InteractionBackend] to use when creating the [IInteractions] instance.
  final InteractionBackend? backend;

  /// Whether to set the EPHEMERAL flag in the original response to interaction events.
  ///
  /// This only has an effect is [autoAcknowledgeInteractions] is set to `true`.
  final bool hideOriginalResponse;

  /// Create a new [CommandsOptions] instance.
  const CommandsOptions({
    this.logErrors = true,
    this.autoAcknowledgeInteractions = true,
    this.acceptBotCommands = false,
    this.acceptSelfCommands = false,
    this.backend,
    this.hideOriginalResponse = true,
  });
}
