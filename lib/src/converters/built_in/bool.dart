import 'package:nyxx/nyxx.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../converter.dart';

bool? convertBool(StringView view, ContextData context) {
  String word = view.getQuotedWord();

  const Iterable<String> truthy = ['y', 'yes', '+', '1', 'true'];
  const Iterable<String> falsy = ['n', 'no', '-', '0', 'false'];

  const Iterable<String> valid = [...truthy, ...falsy];

  if (valid.contains(word.toLowerCase())) {
    return truthy.contains(word.toLowerCase());
  }

  return null;
}

SelectMenuOptionBuilder boolToMultiselectOption(bool value) => SelectMenuOptionBuilder(
      label: value ? 'True' : 'False',
      value: value.toString(),
    );

ButtonBuilder boolToButton(bool value) => ButtonBuilder(
      style: ButtonStyle.primary,
      label: value ? 'True' : 'False',
      customId: '',
    );

/// A [Converter] that converts input to a [bool].
///
/// This converter will parse the input to `true` if the next word or quoted section of the input is
/// one of `y`, `yes`, `+`, `1` or `true`. This comparison is case-insensitive.
/// This converter will parse the input to `false` if the next word or quoted section of the input
/// is one of `n`, `no`, `-`, `0` or `false`. This comparison is case-insensitive.
///
/// If the input is not one of the aforementioned words, this converter will fail.
///
/// This converter has a Discord Slash Command Argument Type of [CommandOptionType.boolean].
const Converter<bool> boolConverter = Converter<bool>(
  convertBool,
  type: CommandOptionType.boolean,
  toMultiselectOption: boolToMultiselectOption,
  toButton: boolToButton,
);
