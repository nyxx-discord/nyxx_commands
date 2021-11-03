part of nyxx_commands;

/// The function used to convert camelCase identifiers to Discord compatible kebab-case names
String convertToKebabCase(String camelCase) {
  List<String> split = camelCase.split('');
  String res = '';

  for (final char in split) {
    if (char != char.toLowerCase() && res.isNotEmpty) {
      res += '-';
    }
    res += char.toLowerCase();
  }

  return res;
}

/// A command check
typedef CommandCheckType = bool Function(Context);

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
}
