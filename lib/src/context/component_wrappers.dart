import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/src/context/context.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:random_string/random_string.dart';

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

    List<ButtonBuilder> buttons = [
      ButtonBuilder(confirmMessage, randomAlpha(10), ComponentStyle.success),
      ButtonBuilder(denyMessage, randomAlpha(10), ComponentStyle.danger),
    ];

    componentMessageBuilder.addComponentRow(ComponentRowBuilder()
      ..addComponent(buttons[0])
      ..addComponent(buttons[1]));

    await respond(componentMessageBuilder);

    IButtonInteractionEvent event = await getButtonPress(buttons);

    return event.interaction.customId == buttons[0].customId;
  }
}
