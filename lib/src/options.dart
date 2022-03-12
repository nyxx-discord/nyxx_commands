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

import 'package:nyxx_interactions/nyxx_interactions.dart';

import 'commands/options.dart';

/// Options that modify how the [CommandsPlugin] instance works.
///
/// You might also be interested in:
/// - [CommandOptions], the options for individual [IOptions] instances.
class CommandsOptions implements CommandOptions {
  /// Whether to automatically log exceptions.
  ///
  /// If this is `true`, exceptions added to [CommandsPlugin.onCommandError] will be added to
  /// nyxx_commands' [Logger], which can then be printed. If this is `false`, no logs will be
  /// created.
  ///
  /// You might also be interested in:
  /// - [Logging], a plugin to automatically print logs to the console.
  final bool logErrors;

  /// The [InteractionBackend] to use for creating the [IInteractions] instance.
  ///
  /// If this is set to null, then a [WebsocketInteractionBackend] will automatically be created,
  /// using the client the [CommandsPlugin] was added to as the client.
  final InteractionBackend? backend;

  @override
  final bool acceptBotCommands;

  @override
  final bool acceptSelfCommands;

  @override
  final bool autoAcknowledgeInteractions;

  @override
  final bool hideOriginalResponse;

  /// Create a new set of [CommandsOptions].
  const CommandsOptions({
    this.logErrors = true,
    this.autoAcknowledgeInteractions = true,
    this.acceptBotCommands = false,
    this.acceptSelfCommands = false,
    this.backend,
    this.hideOriginalResponse = true,
  });
}
