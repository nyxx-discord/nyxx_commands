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

import 'package:nyxx_commands/src/commands/options.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

class CommandsOptions implements CommandOptions {
  final bool logErrors;

  final InteractionBackend? backend;

  @override
  final bool acceptBotCommands;

  @override
  final bool acceptSelfCommands;

  @override
  final bool autoAcknowledgeInteractions;

  @override
  final bool hideOriginalResponse;

  const CommandsOptions({
    this.logErrors = true,
    this.autoAcknowledgeInteractions = true,
    this.acceptBotCommands = false,
    this.acceptSelfCommands = false,
    this.backend,
    this.hideOriginalResponse = true,
  });
}
