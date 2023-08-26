import 'package:nyxx/nyxx.dart';

import '../../context/base.dart';
import '../../context/chat_context.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import '../fallback.dart';
import 'snowflake.dart';

Attachment? snowflakeToAttachment(Snowflake id, ContextData context) {
  Iterable<Attachment>? attachments = switch (context) {
    InteractionChatContext(:final interaction) => interaction.data.resolved?.attachments?.values,
    MessageChatContext(:final message) => message.attachments,
    _ => null,
  };

  try {
    return attachments?.singleWhere((attachment) => attachment.id == id);
  } on StateError {
    return null;
  }
}

Attachment? convertAttachment(StringView view, ContextData context) {
  String fileName = view.getQuotedWord();

  Iterable<Attachment>? attachments = switch (context) {
    InteractionChatContext(:final interaction) => interaction.data.resolved?.attachments?.values,
    MessageChatContext(:final message) => message.attachments,
    _ => null,
  };

  if (attachments == null) {
    return null;
  }

  Iterable<Attachment> exactMatch = attachments.where(
    (attachment) => attachment.fileName == fileName,
  );

  Iterable<Attachment> caseInsensitive = attachments.where(
    (attachment) => attachment.fileName.toLowerCase() == fileName.toLowerCase(),
  );

  Iterable<Attachment> partialMatch = attachments.where(
    (attachment) => attachment.fileName.toLowerCase().startsWith(fileName.toLowerCase()),
  );

  for (final list in [exactMatch, caseInsensitive, partialMatch]) {
    if (list.length == 1) {
      return list.first;
    }
  }

  return null;
}

SelectMenuOptionBuilder attachmentToMultiselectOption(Attachment attachment) =>
    SelectMenuOptionBuilder(
      label: attachment.fileName,
      value: attachment.id.toString(),
    );

ButtonBuilder attachmentToButton(Attachment attachment) => ButtonBuilder(
      style: ButtonStyle.primary,
      label: attachment.fileName,
      customId: '',
    );

/// A converter that converts input to an [IAttachment].
///
/// This will first attempt to parse the input to a snowflake that will then be resolved as the ID
/// of one of the attachments in the message or interaction. If this fails, then the attachment will
/// be looked up by name.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.attachment].
const Converter<Attachment> attachmentConverter = FallbackConverter(
  [
    CombineConverter<Snowflake, Attachment>(snowflakeConverter, snowflakeToAttachment),
    Converter(convertAttachment),
  ],
  type: CommandOptionType.attachment,
  toMultiselectOption: attachmentToMultiselectOption,
  toButton: attachmentToButton,
);
