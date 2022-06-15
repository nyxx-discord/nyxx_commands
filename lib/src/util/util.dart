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

import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

import '../context/autocomplete_context.dart';
import '../converters/converter.dart';
import 'view.dart';

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

  /// The localized descriptions for the command.
  final Map<Locale, String>? localizedDescription;

  /// Create a new [Description].
  ///
  /// This is intended to be used as an `@Description(...)` annotation, and has no functionality as
  /// a standalone class.
  const Description(this.value, [this.localizedDescription]);

  @override
  String toString() => 'Description[value="$value", localizedDescription=$localizedDescription]';
}

/// An annotation used to restrict input to a set of choices for a given parameter.
///
/// Note that this is only a client-side verification for Slash Commands only, input from text
/// commands might not be one of the options.
///
/// For example, adding three choices to a command:
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (
///     IChatContext context,
///     @Choices({'Foo': 'foo', 'Bar': 'bar', 'Baz': 'baz'}) String message,
///   ) async {
///     context.respond(MessageBuilder.content(message));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/156936191-d35e18d0-5e03-414d-938e-b14c80071175.png)
class Choices {
  /// The choices for this command.
  ///
  /// The keys are what is displayed in the Discord UI when the user selects your command and the
  /// values are what actually get sent to your command.
  ///
  /// The values can be either [String]s or [int]s.
  ///
  /// You might also be interested in:
  /// - [ArgChoiceBuilder], the nyxx_interactions builder these entries are converted to.
  final Map<String, dynamic> choices;

  /// Create a new [Choices].
  ///
  /// This is intended to be used as an `@Choices(...)` annotation, and has no functionality as
  /// a standalone class.
  const Choices(this.choices);

  /// Get the builders that this [Choices] represents.
  Iterable<ArgChoiceBuilder> get builders =>
      choices.entries.map((entry) => ArgChoiceBuilder(entry.key, entry.value));

  @override
  String toString() => 'Choices[choices=$choices]';
}

/// An annotation used to change the name displayed in the Discord UI for a given command argument.
///
/// For example, changing the name of an argument from 'foo' to 'message':
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (
///     IChatContext context,
///     @Name('message') String foo,
///   ) async {
///     context.respond(MessageBuilder.content(foo));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/156937204-bbcd5c95-ff0f-40c2-944d-9988fd7b6a60.png)
class Name {
  /// The custom name to use.
  final String name;

  /// The localized names to use.
  /// ```dart
  /// ChatCommand test = ChatCommand(
  ///  'hi',
  ///  'A test command',
  ///  (
  ///   IChatContext context,
  ///   @Name('message', {Locale.german: 'hallo'}) String foo,
  ///  ) async => context.respond(MessageBuilder.content(foo));
  /// );
  /// ```
  /// Will be displayed as 'hallo' in German, like so:
  /// 
  /// ![](https://user-images.githubusercontent.com/74512338/173841767-6e2c5215-ebc3-4a89-a2ac-8115949e2f0b.png)
  final Map<Locale, String>? localizedNames;

  /// Create a new [Name].
  ///
  /// This is intended to be used as an `@Name(...)` annotation, and has no functionality as
  /// a standalone class.
  const Name(this.name, [this.localizedNames]);

  @override
  String toString() => 'Name[name=$name, localizedNames=$localizedNames]';
}

/// An annotation used to specify the converter to use for an argument, overriding the default
/// converter for that type.
///
/// See example/example.dart for an example on how to use this annotation.
class UseConverter {
  /// The converter to use.
  final Converter<dynamic> converter;

  /// Create a new [UseConverter].
  ///
  /// This is intended to be used as an `@UseConverter(...)` annotation, and has no functionality as
  /// a standalone class.
  const UseConverter(this.converter);

  @override
  String toString() => 'UseConverter[converter=$converter]';
}

/// An annotation used to override the callback used to handle autocomplete events for a specific
/// argument.
///
/// For example, using the top-level function `foo` as an autocomplete handler:
/// ```dart
/// ChatCommand test = ChatCommand(
///   'test',
///   'A test command',
///   (
///     IChatContext context,
///     @Autocomplete(foo) String bar,
///   ) async {
///     context.respond(MessageBuilder.content(bar));
///   },
/// );
///
/// commands.addCommand(test);
/// ```
///
/// You might also be interested in:
/// - [Converter.autoCompleteCallback], the way to register autocomplete handlers for all arguments
///   of a given type.
class Autocomplete {
  /// The autocomplete handler to use.
  final FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext) callback;

  /// Create a new [Autocomplete].
  ///
  /// This is intended to be used as an `@Autocomplete(...)` annotation, and has no functionality as
  /// a standalone class.
  const Autocomplete(this.callback);
}

final RegExp _mentionPattern = RegExp(r'^<@!?([0-9]{15,20})>');

/// A wrapper function for prefixes that allows commands to be invoked with a mention prefix.
///
/// For example:
/// ```dart
/// CommandsPlugin commands = CommandsPlugin(
///   prefix: mentionOr((_) => '!'),
/// );
///
/// // Add a basic `test` command...
/// ```
///
/// ![](https://user-images.githubusercontent.com/54505189/156937410-73d19cc5-c018-40e4-97dd-b7fcc0be0b7d.png)
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

/// A wrapper function for prefixes that allows commands to be invoked from messages without a
/// prefix in Direct Messages.
///
/// For example:
/// ```dart
/// CommandsPlugin commands = CommandsPlugin(
///   prefix: dmOr((_) => '!'),
/// );
///
/// // Add a basic `test` command...
/// ```
/// ![](https://user-images.githubusercontent.com/54505189/156937528-df54a2ba-627d-4f54-b0bc-ad7cb6321965.png)
/// ![](https://user-images.githubusercontent.com/54505189/156937561-9df9e6cf-6595-465d-895a-aaca5d6ff066.png)
String Function(IMessage) dmOr(String Function(IMessage) defaultPrefix) {
  return (message) {
    String found = defaultPrefix(message);

    if (message.guild != null || StringView(message.content).skipString(found)) {
      return found;
    }

    return '';
  };
}

/// A pattern all command and argument names should match.
///
/// For more inforrmation on naming restrictions, check the
/// [Discord documentation](https://discord.com/developers/docs/interactions/application-commands#application-command-object-application-command-naming).
final RegExp commandNameRegexp = RegExp(
  r'^[-_\p{L}\p{N}\p{sc=Deva}\p{sc=Thai}]{1,32}$',
  unicode: true,
);

final Map<Function, dynamic> idMap = {};

/// A special function that can be wrapped around another function in order to tell nyxx_commands
/// how to identify the funcion at compile time.
///
/// This function is used to identify a callback function so that compiled nyxx_commands can extract
/// the type & annotation data for that function.
///
/// It is a compile-time error for two [id] invocations to share the same [id] parameter.
/// It is a runtime error in compiled nyxx_commands to create a [ChatCommand] with a non-wrapped
/// function.
T id<T extends Function>(dynamic id, T fn) {
  idMap[fn] = id;

  return fn;
}
