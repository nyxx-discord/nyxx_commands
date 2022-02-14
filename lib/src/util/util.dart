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
import 'package:nyxx_commands/src/converters/converter.dart';
import 'package:nyxx_commands/src/util/view.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

String convertToKebabCase(String camelCase) {
  Iterable<String> split = camelCase.split('');
  String res = '';

  for (final char in split) {
    if (char != char.toLowerCase() && res.isNotEmpty) {
      res += '-';
    }
    res += char.toLowerCase();
  }

  return res;
}

class Description {
  final String value;

  const Description(this.value);

  @override
  String toString() => 'Description[value="$value"]';
}

class Choices {
  final Map<String, dynamic> choices;

  const Choices(this.choices);

  Iterable<ArgChoiceBuilder> get builders =>
      choices.entries.map((entry) => ArgChoiceBuilder(entry.key, entry.value));

  @override
  String toString() => 'Choices[choices=$choices]';
}

class Name {
  final String name;

  const Name(this.name);

  @override
  String toString() => 'Name[name=$name]';
}

class UseConverter {
  final Converter<dynamic> converter;

  const UseConverter(this.converter);

  @override
  String toString() => 'UseConverter[converter=$converter]';
}

final RegExp _mentionPattern = RegExp(r'^<@!?([0-9]{15,20})>');

String Function(IMessage) mentionOr(String Function(IMessage) defaultPrefix) {
  return (message) {
    RegExpMatch? match = _mentionPattern.firstMatch(message.content);

    if (match != null && message.client is INyxxWebsocket) {
      if (int.parse(match.group(1)!) == (message.client as INyxxWebsocket).self.id.id) {
        return match.group(0)!;
      }
    }

    return defaultPrefix(message);
  };
}

String Function(IMessage) dmOr(String Function(IMessage) defaultPrefix) {
  return (message) {
    String found = defaultPrefix(message);

    if (message.guild != null || StringView(message.content).skipString(found)) {
      return found;
    }

    return '';
  };
}

final RegExp commandNameRegexp = RegExp(r'^[\w-]{1,32}$', unicode: true);
