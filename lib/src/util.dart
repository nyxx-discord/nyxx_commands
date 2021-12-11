import 'package:nyxx_interactions/interactions.dart';

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
