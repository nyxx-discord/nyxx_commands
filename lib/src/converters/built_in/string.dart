import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../converter.dart';

String? convertString(StringView view, IContextData context) => view.getQuotedWord();
MultiselectOptionBuilder stringToMultiselectOption(String value) =>
    MultiselectOptionBuilder(value, value);
ButtonBuilder stringToButton(String value) => ButtonBuilder(value, '', ButtonStyle.primary);

/// A [Converter] that converts input to a [String].
///
/// This converter returns the next space-separated word in the input, or, if the next word in the
/// input is quoted, the next quoted section of the input.
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.string].
const Converter<String> stringConverter = Converter<String>(
  convertString,
  type: CommandOptionType.string,
  toMultiselectOption: stringToMultiselectOption,
  toButton: stringToButton,
);
