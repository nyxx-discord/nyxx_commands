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
  ISlashCommandInteraction get interaction;

  ISlashCommandInteractionEvent get interactionEvent;

  @override
  Future<IMessage> respond(MessageBuilder builder, {bool private = false, bool? hidden});

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
