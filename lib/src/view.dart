part of nyxx_commands;

const Map<String, String> _quotes = {
  '"': '"',
  "'": "'",
  '‘': '’',
  '‚': '‛',
  '“': '”',
  '„': '‟',
  '⹂': '⹂',
  '「': '」',
  '『': '』',
  '〝': '〞',
  '﹁': '﹂',
  '﹃': '﹄',
  '＂': '＂',
  '｢': '｣',
  '«': '»',
  '‹': '›',
  '《': '》',
  '〈': '〉',
};

/// A wrapper class to facilitate operations on a [String].
///
/// A pointer is used to indicate the index at which this view is currently operating at.
/// All operations on this view leave an entry in its history, and can be undone using [undo].
class StringView {
  /// The [String] this view represents.
  final String buffer;

  /// The current index of this views pointer.
  int index = 0;

  /// A list of indices this view was at before operations, ordered from least recent first to most
  /// recent last.
  List<int> history = [];

  /// Construct a new [StringView] on [buffer].
  StringView(this.buffer);

  /// The size of this views [buffer] length.
  int get end => buffer.length;

  /// Whether this view is at EOF, i.e if the current pointer has reached the end of the [buffer].
  bool get eof => index >= end;

  /// The character at the current [index] in [buffer].
  String get current => buffer[index];

  /// Whether the current character is whitespace.
  ///
  /// Accounts for escaping of spaces.
  bool get isWhitespace => current == ' ' && !isEscaped(index);

  /// The remaining data in [buffer] after the current [index].
  String get remaining => buffer.substring(index);

  /// Check if the data after the pointer matches [s], and move the pointer beyond it if it does.
  /// Retuns true if the string matches [s] and false otherwise.
  bool skipString(String s) {
    if (index + s.length < end && buffer.substring(index, index + s.length) == s) {
      history.add(index);
      index += s.length;
      return true;
    }
    return false;
  }

  /// Moves the pointer past any whitespace until the next non-whitespace character or EOF is found.
  void skipWhitespace() {
    history.add(index);
    while (!eof && isWhitespace) {
      index++;
    }
  }

  /// Returns true if the character at [index] is escaped and false otherwise.
  bool isEscaped(int index) {
    if (index == 0 || index >= end) {
      return false;
    } else {
      return buffer[index - 1] == r'\' && !isEscaped(index - 1);
    }
  }

  /// Get the next word after the pointer.
  ///
  /// A word is a substring of [buffer] containing only non-whitespace or escaped whitespace
  /// characters, and surrounded by whitespace.
  ///
  /// This method escapes characters in its result.
  String getWord() {
    skipWhitespace();

    int start = index;

    while (!eof && !isWhitespace) {
      index++;
    }

    return escape(start, index);
  }

  /// Get the next quoted word after the pointer.
  ///
  /// A quoted word is the same as a word, unless the word starts with an opening quote. In that
  /// case, a quoted word is a substring of [buffer] preceded by an opening quote and ending with
  /// the character followed by next non-escaped matching closing quote.
  ///
  /// This method escapes characters in its result, and moves the pointer past the closing quote
  /// before returning.
  String getQuotedWord() {
    skipWhitespace();

    if (_quotes.containsKey(current)) {
      String closingQuote = _quotes[current]!;

      index++;
      int start = index;

      while (!eof && (current != closingQuote || isEscaped(index))) {
        index++;
      }

      if (eof) {
        throw ParsingException('Unclosed quote at position $start');
      }

      String escaped = escape(start, index);

      index++; // Skip closing quote

      return escaped;
    } else {
      return getWord();
    }
  }

  /// Escape characters in [buffer] from [start] to [index].
  String escape(int start, int end) {
    String raw = buffer.substring(start, index);

    int currentIndex = start;
    return raw.split('').fold('', (ret, s) {
      currentIndex++;

      if (isEscaped(currentIndex)) {
        return ret;
      }
      return ret + s;
    });
  }

  /// Undo the last operation on this view.
  ///
  /// Can be called repeatedly to undo multiple operations.
  void undo() {
    if (history.isNotEmpty) {
      index = history.removeLast();
    }
  }

  /// Create a copy of this [StringView] with a matching [buffer], [index] and [history].
  StringView copy() {
    StringView res = StringView(buffer)
      ..history = history
      ..index = index;
    return res;
  }

  @override
  String toString() {
    return 'StringView[index=$index (current="${eof ? '<eof>' : current}"), end=$end, buffer="$buffer"]';
  }
}
