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

/// Convert a camelCase string to kebab-case.
///
/// This is used to convert camelCase Dart identifiers to kebab-case Discord Slash Command argument
/// names.
///
/// You might also be interested in:
/// - [Name], for setting a custom name to use for slash command argument names.
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

/// An annotation used to add a description to Slash Command arguments.
///
/// For example, these two snippets of code produce different results:
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (IChatContext context, String message) async {
///     context.respond(MessageBuilder.content(message));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
/// and
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (
///     IChatContext context,
///     @Description('The message to send') String message,
///   ) async {
///     context.respond(MessageBuilder.content(message));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/156934401-67535127-d768-4687-b4b4-d279e4362e16.png)
/// ![](https://user-images.githubusercontent.com/54505189/156934465-18693d88-66f4-41a0-8615-f7d18293fb86.png)
class Description {
  /// The value of the description.
  final String value;

  /// Create a new [Description].
  ///
  /// This is intended to be used as an `@Description(...)` annotation, and has no functionality as
  /// a standalone class.
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
