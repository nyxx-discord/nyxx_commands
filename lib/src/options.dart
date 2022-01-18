import 'package:nyxx_commands/src/commands/options.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

/// Optional commands options.
class CommandsOptions implements CommandOptions {
  /// Whether to log [CommandsException]s that occur when received from
  /// [CommandsPlugin.onCommandError].
  final bool logErrors;

  /// A custom [InteractionBackend] to use when creating the [IInteractions] instance.
  final InteractionBackend? backend;

  @override
  final bool acceptBotCommands;

  @override
  final bool acceptSelfCommands;

  @override
  final bool autoAcknowledgeInteractions;

  @override
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
