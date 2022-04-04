//  Copyright 2021 Abitofevrything and others.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

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
  /// - [IInteractionContext.acknowledge], for manually acknowledging interactions.
  final bool? autoAcknowledgeInteractions;

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

  /// Whether to hide the response from other users when the command is invoked from an interaction.
  ///
  /// This sets the EPHEMERAL flag on interactions responses when [IContext.respond] is used.
  ///
  /// You might also be interested in:
  /// - [IInteractionContext.respond], which can override this setting by setting the `hidden` flag.
  final bool? hideOriginalResponse;

  /// Create a set of command options.
  ///
  /// Options set to `null` will be inherited from the parent.
  const CommandOptions({
    this.autoAcknowledgeInteractions,
    this.acceptBotCommands,
    this.acceptSelfCommands,
    this.hideOriginalResponse,
  });
}
