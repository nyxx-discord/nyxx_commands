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

import 'commands/chat_command.dart';
import 'commands/options.dart';
import 'context/base.dart';

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

  /// Whether to infer the default command type.
  ///
  /// If this is `true` and [type] is [CommandType.all], then the root command type used will be
  /// [CommandType.slashOnly] if [CommandsPlugin.prefix] is not specified. If
  /// [CommandsPlugin.prefix] is specified, the root command type will be left as-is.
  final bool inferDefaultCommandType;

  @override
  final bool acceptBotCommands;

  @override
  final bool acceptSelfCommands;

  @override
  final bool autoAcknowledgeInteractions;

  @override
  final ResponseLevel defaultResponseLevel;

  @override
  final CommandType type;

  @override
  final bool caseInsensitiveCommands;

  @override
  final Duration? autoAcknowledgeDuration;

  /// Create a new set of [CommandsOptions].
  const CommandsOptions({
    this.logErrors = true,
    this.autoAcknowledgeInteractions = true,
    this.autoAcknowledgeDuration,
    this.acceptBotCommands = false,
    this.acceptSelfCommands = false,
    this.backend,
    this.defaultResponseLevel = ResponseLevel.public,
    this.type = CommandType.all,
    this.inferDefaultCommandType = true,
    this.caseInsensitiveCommands = true,
  });
}
