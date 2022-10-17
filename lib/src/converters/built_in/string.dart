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
