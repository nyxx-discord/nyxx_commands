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
import 'package:random_string/random_string.dart';

import 'context.dart';

mixin ComponentWrappersMixin implements IContext {
  @override
  Future<IMultiselectInteractionEvent> getSelection(MultiselectBuilder selectionMenu,
          {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)}) =>
      commands.interactions.events.onMultiselectEvent
          .where((event) => event.interaction.customId == selectionMenu.customId)
          .map((event) => event..acknowledge())
          .where(
            (event) =>
                !authorOnly ||
                (event.interaction.memberAuthor ?? event.interaction.userAuthor as SnowflakeEntity)
                        .id ==
                    user.id,
          )
          .timeout(
            timeout ?? Duration(),
            onTimeout: timeout != null ? null : (sink) {},
          )
          .first;

  @override
  Future<IButtonInteractionEvent> getButtonPress(Iterable<ButtonBuilder> buttons,
          {bool authorOnly = true, Duration? timeout = const Duration(minutes: 12)}) =>
      commands.interactions.events.onButtonEvent
          .where((event) =>
              buttons.map((button) => button.customId).contains(event.interaction.customId))
          .map((event) => event..acknowledge())
          .where(
            (event) =>
                !authorOnly ||
                (event.interaction.memberAuthor ?? event.interaction.userAuthor as SnowflakeEntity)
                        .id ==
                    user.id,
          )
          .timeout(
            timeout ?? Duration(),
            onTimeout: timeout != null ? null : (sink) {},
          )
          .first;

  @override
  Future<bool> getConfirmation(
    MessageBuilder message, {
    bool authorOnly = true,
    Duration? timeout = const Duration(minutes: 12),
    String confirmMessage = 'Yes',
    String denyMessage = 'No',
  }) async {
    ComponentMessageBuilder componentMessageBuilder = ComponentMessageBuilder()
      ..allowedMentions = message.allowedMentions
      ..attachments = message.attachments
      ..content = message.content
      ..embeds = message.embeds
      ..files = message.files
      ..replyBuilder = message.replyBuilder
      ..tts = message.tts;

    if (message is ComponentMessageBuilder) {
      componentMessageBuilder.componentRows = message.componentRows;
    } else {
      componentMessageBuilder.componentRows = [];
    }

    ButtonBuilder confirmButton =
        ButtonBuilder(confirmMessage, randomAlpha(10), ButtonStyle.success);

    ButtonBuilder denyButton = ButtonBuilder(denyMessage, randomAlpha(10), ButtonStyle.danger);

    componentMessageBuilder.addComponentRow(ComponentRowBuilder()
      ..addComponent(confirmButton)
      ..addComponent(denyButton));

    await respond(componentMessageBuilder);

    IButtonInteractionEvent event = await getButtonPress([confirmButton, denyButton]);
    return event.interaction.customId == confirmButton.customId;
  }
}
