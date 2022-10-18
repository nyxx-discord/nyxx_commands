import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../../context/base.dart';
import '../../context/chat_context.dart';
import '../../util/view.dart';
import '../combine.dart';
import '../converter.dart';
import '../fallback.dart';
import 'snowflake.dart';

IAttachment? snowflakeToAttachment(Snowflake id, IContextData context) {
  Iterable<IAttachment>? attachments;
  if (context is InteractionChatContext) {
    attachments = context.interaction.resolved?.attachments ?? [];
  } else if (context is MessageChatContext) {
    attachments = context.message.attachments;
  }

  if (attachments == null) {
    return null;
  }

  try {
    return attachments.singleWhere((attachment) => attachment.id == id);
  } on StateError {
    return null;
  }
}

IAttachment? convertAttachment(StringView view, IContextData context) {
  String fileName = view.getQuotedWord();

  Iterable<IAttachment>? attachments;
  if (context is InteractionChatContext) {
    attachments = context.interaction.resolved?.attachments;
  } else if (context is MessageChatContext) {
    attachments = context.message.attachments;
  }

  if (attachments == null) {
    return null;
  }

  Iterable<IAttachment> exactMatch = attachments.where(
    (attachment) => attachment.filename == fileName,
  );

  Iterable<IAttachment> caseInsensitive = attachments.where(
    (attachment) => attachment.filename.toLowerCase() == fileName.toLowerCase(),
  );

  Iterable<IAttachment> partialMatch = attachments.where(
    (attachment) => attachment.filename.toLowerCase().startsWith(fileName.toLowerCase()),
  );

  for (final list in [exactMatch, caseInsensitive, partialMatch]) {
    if (list.length == 1) {
      return list.first;
    }
  }

  return null;
}

MultiselectOptionBuilder attachmentToMultiselectOption(IAttachment attachment) =>
    MultiselectOptionBuilder(
      attachment.filename,
      attachment.id.toString(),
    );

ButtonBuilder attachmentToButton(IAttachment attachment) => ButtonBuilder(
      attachment.filename,
      '',
      ButtonStyle.primary,
    );

/// A converter that converts input to an [IAttachment].
///
/// This will first attempt to parse the input to a snowflake that will then be resolved as the ID
/// of one of the attachments in the message or interaction. If this fails, then the attachment will
/// be looked up by name.
///
/// This converter has a Discord Slash Command argument type of [CommandOptionType.attachment].
const Converter<IAttachment> attachmentConverter = FallbackConverter(
  [
    CombineConverter<Snowflake, IAttachment>(snowflakeConverter, snowflakeToAttachment),
    Converter(convertAttachment),
  ],
  type: CommandOptionType.attachment,
  toMultiselectOption: attachmentToMultiselectOption,
  toButton: attachmentToButton,
);
