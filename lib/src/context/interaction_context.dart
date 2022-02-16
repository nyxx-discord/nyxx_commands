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

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

abstract class IInteractionContext implements IContext {
  /// The [ISlashCommandInteraction] that triggered this context's execution.
  ISlashCommandInteraction get interaction;

  /// The [ISlashCommandInteractionEvent] that triggered this context's exeecution.
  ISlashCommandInteractionEvent get interactionEvent;

  /// Send a response to the command.
  ///
  /// Setting `private` to true will ensure only the user that invoked the command sees the
  /// response:
  /// - For message contexts, a DM is sent to the invoking user;
  /// - For interaction contexts, an ephemeral response is used.
  ///
  /// You can set [hidden] to `true` to send an ephemeral response. Setting [hidden] to a value
  /// different that [CommandsOptions.hideOriginalResponse] will result in unusual behaviour if this
  /// method is invoked more than two seconds after command execution starts.
  /// Calling [acknowledge] less than two seconds after command execution starts with the same value
  /// for [hidden] as this invocation will prevent this unusual behaviour from happening.
  ///
  /// [hidden] will override the value of [private] if both are provided.
  @override
  Future<IMessage> respond(MessageBuilder builder, {bool private = false, bool? hidden});

  /// Acknowledge the underlying [interactionEvent].
  ///
  /// This allows you to acknowledge the interaction with a different hidden state that
  /// [CommandsOptions.hideOriginalResponse].
  ///
  /// If unspecified, [hidden] will be set to [CommandsOptions.hideOriginalResponse].
  ///
  /// Prefer using this method over calling [ISlashCommandInteractionEvent.acknowledge] on
  /// [interactionEvent] as this method will fix any unusual behaviour with [respond].
  ///
  /// If called within 2 seconds of command execution, this will override the auto-acknowledge
  /// induced by [CommandsOptions.autoAcknowledgeInteractions].
  /// If called  after 2 seconds, an [AlreadyRespondedError] will be thrown as nyxx_commands will
  /// automatically responded to avoid a token timeout.
  Future<void> acknowledge({bool? hidden});
}

mixin InteractionContextMixin implements IInteractionContext {
  bool _hasCorrectlyAcked = false;
  late bool _originalAckHidden = commands.options.hideOriginalResponse;

  @override
  Future<IMessage> respond(MessageBuilder builder, {bool private = false, bool? hidden}) async {
    hidden ??= private;

    if (_hasCorrectlyAcked) {
      return interactionEvent.sendFollowup(builder, hidden: hidden);
    } else {
      _hasCorrectlyAcked = true;
      try {
        await interactionEvent.acknowledge(hidden: hidden);
      } on AlreadyRespondedError {
        // interaction was already ACKed by timeout or [acknowledge], hidden state of ACK might not
        // be what we expect
        if (_originalAckHidden != hidden) {
          await interactionEvent
              .sendFollowup(MessageBuilder.content(MessageBuilder.clearCharacter));
          if (!_originalAckHidden) {
            // If original response was hidden, we can't delete it
            await interactionEvent.deleteOriginalResponse();
          }
        }
      }
      return interactionEvent.sendFollowup(builder, hidden: hidden);
    }
  }

  @override
  Future<void> acknowledge({bool? hidden}) async {
    await interactionEvent.acknowledge(hidden: hidden ?? commands.options.hideOriginalResponse);
    _originalAckHidden = hidden ?? commands.options.hideOriginalResponse;
  }
}
