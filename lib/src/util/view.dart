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

class StringView {
  final String buffer;

  int index = 0;

  List<int> history = [];

  StringView(this.buffer);

  int get end => buffer.length;

  bool get eof => index >= end;

  String get current => buffer[index];

  bool get isWhitespace => current == ' ' && !isEscaped(index);

  String get remaining => buffer.substring(index);

  bool skipString(String s) {
    if (index + s.length < end && buffer.substring(index, index + s.length) == s) {
      history.add(index);
      index += s.length;
      return true;
    }
    return false;
  }

  void skipWhitespace() {
    history.add(index);
    while (!eof && isWhitespace) {
      index++;
    }
  }

  bool isEscaped(int index) {
    if (index == 0 || index >= end) {
      return false;
    } else {
      return buffer[index - 1] == r'\' && !isEscaped(index - 1);
    }
  }

  String getWord() {
    skipWhitespace();

    int start = index;

    while (!eof && !isWhitespace) {
      index++;
    }

    return escape(start, index);
  }

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

  void undo() {
    if (history.isNotEmpty) {
      index = history.removeLast();
    }
  }

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
