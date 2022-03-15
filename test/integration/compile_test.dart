import 'dart:io';

import 'package:test/test.dart';

import '../../bin/compile/generator.dart';

void main() {
  test('Compilation script', () async {
    Future<void> generationFuture = generate('example/example.dart', 'out.g.dart', true);

    expect(generationFuture, completes);

    await generationFuture;

    expect(File('out.g.dart').exists(), completion(equals(true)));

    Future<ProcessResult> compilationFuture = Process.run(
      Platform.executable,
      ['compile', 'exe', 'out.g.dart'],
    );

    expect(
      compilationFuture.then((value) => value.exitCode),
      completion(equals(0)), // Expect compilation to succeed
    );

    await compilationFuture;

    expect(File('out.g.exe').exists(), completion(equals(true)));
  }, timeout: Timeout(Duration(minutes: 10)));
}
