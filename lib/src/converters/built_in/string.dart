import 'package:nyxx/nyxx.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../converter.dart';

String? convertString(StringView view, ContextData context) => view.getQuotedWord();

SelectMenuOptionBuilder stringToSelectMenuOption(String value) => SelectMenuOptionBuilder(
      label: value,
      value: value,
    );

ButtonBuilder stringToButton(String value) => ButtonBuilder(
      style: ButtonStyle.primary,
      label: value,
      customId: '',
    );

/// A [Converter] that converts input to a [String].
///
/// This converter returns the next space-separated word in the input, or, if the next word in the
/// input is quoted, the next quoted section of the input.
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.string].
const Converter<String> stringConverter = Converter<String>(
  convertString,
  type: CommandOptionType.string,
  toSelectMenuOption: stringToSelectMenuOption,
  toButton: stringToButton,
);
