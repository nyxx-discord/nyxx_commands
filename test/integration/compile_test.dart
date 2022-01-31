import 'dart:io';

import 'package:test/test.dart';

import '../../bin/compile/generator.dart';

void main() {
  test('Compilation script', () async {
    expect(generate('example/example.dart', 'out.g.dart'), completes);

    expect(File('out.g.dart').exists(), completion(equals(true)));

    expect(
      Process.run(
        Platform.executable,
        ['compile', 'exe', 'out.g.dart'],
      ).then((value) => value.exitCode),
      completion(equals(0)), // Expect compilation to succeed
    );

    expect(File('out.g.exe').exists(), completion(equals(true)));
  }, timeout: Timeout(Duration(minutes: 10)));
}
