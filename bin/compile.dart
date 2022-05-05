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

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';

import 'compile/generator.dart';

void main(List<String> args) async {
  late ArgParser parser;
  parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this help and exit',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: 'out.g.dart',
      help: 'The file where generated output should be written to',
    )
    ..addOption(
      'verbosity',
      abbr: 'v',
      defaultsTo: 'info',
      allowed: Level.LEVELS.map((e) => e.name.toLowerCase()),
      help: 'Change the verbosity level of the command-line output',
    )
    ..addFlag(
      'compile',
      abbr: 'c',
      defaultsTo: true,
      help: 'Compile the generated file with `dart compile exe`',
    )
    ..addFlag(
      'format',
      abbr: 'f',
      defaultsTo: true,
      help: 'Format the generated output before compiling',
    )
    ..addFlag(
      'slow',
      defaultsTo: false,
      help: 'Use a slower, more thourough version of the compiler. This can help in cases where'
          ' the default compiler is unable to generate all the metadata needed for your program.',
    );

  if (args.isEmpty) {
    printHelp(parser);
    return;
  }

  ArgResults result = parser.parse(args);

  // Help

  if (result['help'] as bool) {
    printHelp(parser);
    return;
  }

  // Logging

  Logger.root.level = Level.LEVELS.firstWhere(
    (element) => element.name.toLowerCase() == result['verbosity'],
  );
  Logger.root.onRecord.listen((LogRecord rec) {
    print("[${rec.time}] [${rec.level.name}] ${rec.message}");
  });

  // Generation

  await generate(
    result.rest.first,
    result['output'] as String,
    result['format'] as bool,
    result['slow'] as bool,
  );

  // Compilation

  if (result['compile'] as bool) {
    logger.info('Compiling file to executable');

    Process compiler = await Process.start('dart', ['compile', 'exe', result['output'] as String]);

    compiler.stdout.transform(utf8.decoder).listen(stdout.write);
    compiler.stderr.transform(utf8.decoder).listen(stderr.write);
  }
}

void printHelp(ArgParser p) {
  print(
    '''
Generate code from a Dart program that contains metadata about types and function metadata, and can
be compiled to run a program written with nyxx_commands.

Usage: nyxx-compile [options] <file>

Options:
''',
  );
  print(p.usage);
}
