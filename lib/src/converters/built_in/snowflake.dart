import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../../context/base.dart';
import '../../util/view.dart';
import '../converter.dart';

final RegExp _snowflakePattern = RegExp(r'^(?:<(?:@(?:!|&)?|#)([0-9]{15,20})>|([0-9]{15,20}))$');

Snowflake? convertSnowflake(StringView view, IContextData context) {
  String word = view.getQuotedWord();
  if (!_snowflakePattern.hasMatch(word)) {
    return null;
  }

  final RegExpMatch match = _snowflakePattern.firstMatch(word)!;

  // 1st group will catch mentions, second will catch raw IDs
  return Snowflake(match.group(1) ?? match.group(2));
}

MultiselectOptionBuilder snowflakeToMultiselectOption(Snowflake snowflake) =>
    MultiselectOptionBuilder(
      snowflake.toString(),
      snowflake.toString(),
    );

ButtonBuilder snowflakeToButton(Snowflake snowflake) => ButtonBuilder(
      snowflake.toString(),
      '',
      ButtonStyle.primary,
    );

/// A converter that converts input to a [Snowflake].
///
/// This converter will parse user mentions, member mentions, channel mentions or raw integers as
/// snowflakes.
const Converter<Snowflake> snowflakeConverter = Converter<Snowflake>(
  convertSnowflake,
  toMultiselectOption: snowflakeToMultiselectOption,
  toButton: snowflakeToButton,
);
