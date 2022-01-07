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
import 'package:nyxx_commands/src/converter.dart';
import 'package:nyxx_commands/src/view.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

/// The function used to convert camelCase identifiers to Discord compatible kebab-case names
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

/// A decorator used to specify descriptions of [Command] arguments.
class Description {
  /// The value of this description
  final String value;

  /// Create a new instance to describe an element, like so:
  /// ```dart
  /// Command(
  ///   'test',
  ///   'A test command',
  ///   (Context context, @Description('Your name') name) async {
  ///     await context.respond('Hello, $name!');
  ///   }
  /// );
  /// ```
  ///
  /// Descriptions must be between 1-100 characters in length.
  const Description(this.value);

  @override
  String toString() => 'Description[value="$value"]';
}

/// A decorator used to specify choices for [Command] arguments.
///
/// This overrides the [Converter.choices] for the argument type.
class Choices {
  /// The choices for this argument.
  ///
  /// These are converted to [ArgChoiceBuilder]s at runtime.
  /// Keys must be [int]s or [String]s.
  final Map<String, dynamic> choices;

  /// Create a new instance to specify choices for an argument, like so:
  /// ```dart
  /// Command(
  ///   'test',
  ///   'A test command',
  ///   (
  ///     Context context,
  ///     @Choices({'One': 1, 'Two': 2, 'Three': 3}) int input
  ///   ) async {
  ///     await context.respond('You chose the number $input!');
  ///   }
  /// )
  /// ```
  const Choices(this.choices);

  /// Converts the entries in [choices] to [ArgChoiceBuilder]s.
  Iterable<ArgChoiceBuilder> get builders =>
      choices.entries.map((entry) => ArgChoiceBuilder(entry.key, entry.value));

  @override
  String toString() => 'Choices[choices=$choices]';
}

/// A decorator used to specify the Discord name of [Command] arguments.
///
/// This overrides the default, which is to convert camelCase names to kebab-case.
class Name {
  /// The name for this argument.
  ///
  /// This must match [commandNameRegexp].
  final String name;

  /// Create a new instance to specify the name of an argument, like so:
  /// ```dart
  /// Command(
  ///   'test',
  ///   'A test command',
  ///   (
  ///     Context context,
  ///     @Name('name') int input
  ///   ) async {
  ///     await context.respond('Hello, $input!');
  ///   }
  /// )
  /// ```
  const Name(this.name);

  @override
  String toString() => 'Name[name=$name]';
}

/// A decorator used to specify converter overrides for [Command] arguments.
///
/// This overrides the default converter for that type.
class UseConverter {
  /// The converter used instead of the default converter.
  ///
  /// This must return a type compatible with the argument, or a [CommandRegistrationError] will be
  /// thrown.
  final Converter<dynamic> converter;

  /// Create a new instance to specify a converter override, like so:
  /// ```dart
  /// const Converter<String> nonEmptyStringConverter = CombineConverter(
  ///   stringConverter,
  ///   filterInput,
  /// );
  ///
  /// Command betterSay = Command(
  ///   'better-say',
  ///   'A better version of the say command',
  ///   (
  ///     Context context,
  ///     @UseConverter(nonEmptyStringConverter) String input,
  ///   ) {
  ///     context.respond(MessageBuilder.content(input));
  ///   },
  /// );
  /// ```
  const UseConverter(this.converter);

  @override
  String toString() => 'UseConverter[converter=$converter]';
}

final RegExp _mentionPattern = RegExp(r'^<@!?([0-9]{15,20})>');

/// A Function that can be used as an input to [CommandsPlugin.prefix] to allow invoking commands by
/// mentioning the bot.
///
/// The [defaultPrefix] parameter will be used if the message does not start with a mention.
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

/// A Function that can be used  as an input to [CommandsPlugin.prefix] to allow users to optionally
/// omit the prefix if the command is ran in a DM with the bot.
///
/// The [defaultPrefix] parameter will be used if the message was sent in a guild or if the message
/// starts with the prefix returned anyways.
String Function(IMessage) dmOr(String Function(IMessage) defaultPrefix) {
  return (message) {
    String found = defaultPrefix(message);

    if (message.guild != null || StringView(message.content).skipString(found)) {
      return found;
    }

    return '';
  };
}
