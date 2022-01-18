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

/// Represents a set of options that can be applied globally, per-group or per-command.
class CommandOptions {
  /// Whether to automatically acknowledge slash command interactions if they are not acknowledged
  /// or responded to within 2s of command invocation.
  ///
  /// If you set this to false, you *must* respond to the interaction yourself, or the command will fail.
  final bool? autoAcknowledgeInteractions;

  /// Whether to process commands coming from bot users on Discord.
  final bool? acceptBotCommands;

  /// Whether to process commands coming from the bot's own user.
  ///
  /// Setting this to `true` might result in infinite loops.
  /// [acceptBotCommands] must also be set to true for this to have any effect.
  final bool? acceptSelfCommands;

  /// Whether to set the EPHEMERAL flag in the original response to interaction events.
  ///
  /// This only has an effect is [autoAcknowledgeInteractions] is set to `true`.
  final bool? hideOriginalResponse;

  /// Create a new set of command options.
  const CommandOptions({
    this.autoAcknowledgeInteractions,
    this.acceptBotCommands,
    this.acceptSelfCommands,
    this.hideOriginalResponse,
  });
}
