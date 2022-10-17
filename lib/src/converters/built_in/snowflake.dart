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
