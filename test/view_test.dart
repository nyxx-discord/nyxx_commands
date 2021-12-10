import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

void main() {
  group('StringView', () {
    group('StringView()', () {
      test('buffer', () {
        expect(StringView('foo').buffer, equals('foo'));
      });

      test('current', () {
        expect(StringView('foo').current, equals('f'));
      });

      test('index', () {
        StringView view = StringView('bar');
        view.index++;

        expect(view.current, equals('a'));

        view.index++;

        expect(view.current, equals('r'));
      });

      test('remaining', () {
        StringView view = StringView('foo bar baz')..index = 4;

        expect(view.remaining, equals('bar baz'));
      });

      test('eof', () {
        StringView view = StringView('foo');

        expect(view.eof, equals(false));

        view.index = 3;

        expect(view.eof, equals(true));
      });
    });

    group('StringView.skipString()', () {
      test('Skips string when match', () {
        StringView view = StringView('foo bar baz');

        expect(view.skipString('foo '), equals(true));
        expect(view.remaining, equals('bar baz'));
      });

      test("Doesn't skip string when unmatched", () {
        StringView view = StringView('foo bar baz');

        expect(view.skipString('bar '), equals(false));
        expect(view.remaining, equals('foo bar baz'));
      });

      test('Handles EOF', () {
        StringView view = StringView('foo bar');

        expect(view.skipString('foo bar baz'), equals(false));
        expect(view.remaining, equals('foo bar'));
      });
    });

    group('StringView.skipWhitespace()', () {
      test('Skips whitespace', () {
        StringView view = StringView('   foo')..skipWhitespace();

        expect(view.remaining, equals('foo'));
      });

      test("Doesn't skip non-whitespace", () {
        StringView view = StringView('foo   ')..skipWhitespace();

        expect(view.remaining, equals('foo   '));
      });

      test('Handles EOF', () {
        StringView view = StringView('     ')..skipWhitespace();

        expect(view.eof, equals(true));
      });
    });

    group('StringView.isEscaped()', () {
      test('Detects escaped characters', () {
        StringView view = StringView(r'f\oo');

        expect(view.isEscaped(2), equals(true));
      });

      test('Complex escape sequences', () {
        StringView view = StringView(r'foo\\ bar\\\ baz');

        expect(view.isEscaped(4), equals(true));
        expect(view.isEscaped(5), equals(false));
        expect(view.isEscaped(11), equals(false));
        expect(view.isEscaped(12), equals(true));
      });
    });

    group('StringView.getWord()', () {
      StringView view = StringView(r'foo bar\ baz qux\\ quux');

      test('Simple word', () {
        expect(view.getWord(), equals('foo'));
      });

      test('Escaped space', () {
        expect(view.getWord(), equals('bar baz'));
      });

      test('Escaped escape sequence', () {
        expect(view.getWord(), equals(r'qux\'));
        expect(view.getWord(), equals('quux'));
      });
    });

    group('StringView.getQuotedWord()', () {
      StringView view = StringView(r'foo "bar baz" \"qux" qu"ux "foobar');

      test('No quotes', () {
        expect(view.getQuotedWord(), equals('foo'));
      });

      test('Quotes', () {
        expect(view.getQuotedWord(), equals('bar baz'));
      });

      test('Escaped quotes', () {
        expect(view.getQuotedWord(), equals('"qux"'));
      });

      test('Non-opening quotes', () {
        expect(view.getQuotedWord(), equals('qu"ux'));
      });

      test('Parsing error', () {
        expect(view.getQuotedWord, throwsA(isA<ParsingException>()));
      });
    });

    test('StringView.escape()', () {
      StringView view = StringView(r'\ \\ \\\ \\\\ \\\\\');

      expect(view.escape(0, view.end), equals(r' \ \ \\ \\\'));
    });
  });
}
