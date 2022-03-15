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

import '../errors.dart';

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

/// A wrapper class for [String]s which adds a cursor tracking an offset in the string.
///
/// A [StringView] allows a [String] to be consumed from start to end, as well as providing
/// operations that are especially useful for argument parsing.
class StringView {
  /// The string wrapped by this [StringView].
  ///
  /// Generally, developers will not need to access this directly. Using [getQuotedWord], [getWord]
  /// or [remaining] is preferable.
  final String buffer;

  /// The current index of the cursor in [buffer].
  int index = 0;

  /// A record of all the previous indices the cursor was at preceding an operation.
  List<int> history = [];

  /// Create a new [StringView] wrapping [buffer].
  ///
  /// The cursor will initially be positioned at the start of [buffer].
  StringView(this.buffer);

  /// The largest possible index for the cursor.
  int get end => buffer.length;

  /// Whether the entire [buffer] has been consumed.
  bool get eof => index >= end;

  /// The character at the current cursor position.
  String get current => buffer[index];

  /// Whether the current character is whitespace.
  ///
  /// In this case, *whitespace* refers to a non-escaped space character (ASCII 32).
  ///
  /// You might also be interested in:
  /// - [isEscaped], for checking if an arbitrary character is escaped;
  /// - [current], for getting the current character.
  bool get isWhitespace => current == ' ' && !isEscaped(index);

  /// The part of [buffer] that has yet to be consumed, spanning from [index] to the end of
  /// [buffer].
  ///
  /// Accessing this property does *not* consume the remaining part. If developers intend to consume
  /// the remaining part of the [buffer], they should access this property and then set [index] to
  /// [end] to indicate that the entire buffer has been consumed.
  ///
  /// You might also be interested in:
  /// - [current], for getting the current character;
  /// - [getQuotedWord], for getting the next quoted word in [buffer];
  /// - [getWord], for getting the next word in [buffer] ignoring quotes.
  String get remaining => buffer.substring(index);

  /// Skip over [s] and return `true` if [s] matches the text after the cursor, and return `false`
  /// otherwise.
  ///
  /// You might also be interested in:
  /// - [skipWhitespace], for skipping arbitrary spans of whitespace.
  bool skipString(String s) {
    if (index + s.length < end && buffer.substring(index, index + s.length) == s) {
      history.add(index);
      index += s.length;
      return true;
    }
    return false;
  }

  /// Skip to the next non-whitespace character in [buffer].
  ///
  /// In this case, *whitespace* refers to a non-escaped space character (ASCII 32).
  ///
  /// You might also be interested in:
  /// - [skipString], for skipping a specific string.
  void skipWhitespace() {
    history.add(index);
    while (!eof && isWhitespace) {
      index++;
    }
  }

  /// Return whether the character at [index] is escaped.
  ///
  /// An index is considered *escaped* if it is preceded by a non-escaped backslash character
  /// (`\`, ASCII 92).
  ///
  /// Characters outside of [buffer] are considered non-escaped.
  ///
  /// Escaped
  bool isEscaped(int index) {
    if (index == 0 || index >= end) {
      return false;
    } else {
      return buffer[index - 1] == r'\' && !isEscaped(index - 1);
    }
  }

  /// Consume and return the next word in [buffer], disregarding quotes.
  ///
  /// Developers should use [getQuotedWord] instead unless they specifically want the behaviour
  /// described below, as [getWord] can leave [remaining] with unbalanced quotes.
  ///
  /// A *word* is a sequence of non-whitespace characters, themselves surrounded by whitespace. The
  /// whitespace preceding the word is consumed but not returned, and the whitespace after the word
  /// is left untouched.
  ///
  /// The word is escaped before it is returned.
  ///
  /// You might also be interested in:
  /// - [escape], for escaping arbitrary postions of [buffer];
  /// - [isWhitespace], for checking if the current character is considered whitespace.
  String getWord() {
    skipWhitespace();

    int start = index;

    while (!eof && !isWhitespace) {
      index++;
    }

    return escape(start, index);
  }

  /// Consume and return the next word or quoted portion in [buffer].
  ///
  /// See [getWord] for a description of wwhat is considered a *word*.
  ///
  /// In addition to the behaviour of [getWord], [getQuotedWord] will return the portion of [buffer]
  /// between an opening quote and a corresponding, non-escaped closing quote if the next word
  /// begins with a quote. The quotes are consumed but not returned.
  ///
  /// The word or quoted sequence is escaped before it is returned.
  ///
  /// You might also be interested in:
  /// - [escape], for escaping arbitrary portions of [buffer];
  /// - [isWhitespace], for checking if the current character is considered whitespace.
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

  /// Escape and return a portion of [buffer].
  ///
  /// See [isEscaped] for a description of what is considered an *escaped* character.
  ///
  /// [escape] takes the portion of [buffer] between [start] (inclusive) and [end] (exclusive) and
  /// replaces each pair of escaping character and escaped character with just the escaped
  /// character.
  String escape(int start, int end) {
    String raw = buffer.substring(start, end);

    int currentIndex = start;
    return raw.split('').fold('', (ret, s) {
      currentIndex++;

      if (isEscaped(currentIndex)) {
        return ret;
      }
      return ret + s;
    });
  }

  /// Revert the previous operation if there is one.
  void undo() {
    if (history.isNotEmpty) {
      index = history.removeLast();
    }
  }

  /// Create a copy of this [StringView], with an identical [buffer] and [index].
  StringView copy() {
    StringView res = StringView(buffer)
      ..history = history
      ..index = index;
    return res;
  }

  @override
  String toString() =>
      'StringView[index=$index (current="${eof ? '<eof>' : current}"), end=$end, buffer="$buffer"]';
}
