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
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../context/context.dart';

/// The base class for all interaction-triggered contexts in nyxx_ccommands.
///
/// Contains data allowing access to the underlying interaction that triggered the context's
/// creation.
// TODO: Rename this class to IInteractionContext
abstract class IInteractionContextBase {
  /// The interaction that triggered this context's creation.
  ISlashCommandInteraction get interaction;

  /// The interaction event that triggered this context's creation.
  InteractionEventAbstract get interactionEvent;
}

/// Represents a context that originated from an interaction.
// TODO: Rename this class to IInterationCommandContext
abstract class IInteractionContext implements IContext, IInteractionContextBase {
  /// Send a response to the command.
  ///
  /// If [private] is set to `true`, then the response will only be made visible to the user that
  /// invoked the command. In interactions, this is done by sending an ephemeral response, in text
  /// commands this is handled by sending a Private Message to the user.
  ///
  /// If [hidden] is set to `true`, the response will be ephemeral (hidden). However, unlike
  /// [hidden], not setting [hidden] will result in the value from
  /// [CommandOptions.hideOriginalResponse] being used instead. [hidden] will override [private].
  ///
  /// You might also be interested in:
  /// - [acknowledge], for acknowledging interactions without resopnding.
  @override
  Future<IMessage> respond(MessageBuilder builder, {bool private = false, bool? hidden});

  /// Acknowledge the underlying interaction without yet sending a response.
  ///
  /// While the `hidden` and `private` arguments are guaranteed to hide/show the resulting response,
  /// slow commands might sometimes show strange behaviour in their responses. Acknowledging the
  /// interaction early with the correct value for [hidden] can prevent this behaviour.
  ///
  /// You might also be interested in:
  /// - [respond], for sending a full response.
  Future<void> acknowledge({bool? hidden});

  @override
  ISlashCommandInteractionEvent get interactionEvent;
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
