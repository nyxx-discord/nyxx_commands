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
