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

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:nyxx_commands/src/errors.dart';
import 'package:path/path.dart';

import 'function_metadata/compile_time_function_data.dart';
import 'function_metadata/metadata_builder_visitor.dart';
import 'function_metadata/metadata_builder.dart';
import 'to_source.dart';

final Logger logger = Logger('Commands Compiler');

/// Generates the metadata for the program located at [path], writing the output to the file at
/// [outPath].
///
/// If [formatOutput] is `true`, the resulting file will be formatted with `dart format`.
Future<void> generate(String path, String outPath, bool formatOutput, bool slow) async {
  path = normalize(absolute(path));

  logger.info('Analyzing file "$path"');

  final ContextLocator locator = ContextLocator();
  final ContextBuilder builder = ContextBuilder();

  final AnalysisContext context =
      builder.createContext(contextRoot: locator.locateRoots(includedPaths: [path]).first);

  final SomeResolvedLibraryResult result = await context.currentSession.getResolvedLibrary(path);

  logger.info('Finished analyzing file "$path"');

  if (result is! ResolvedLibraryResult) {
    logger.shout('Did not get a valid analysis result for "$path"');
    throw CommandsException('Did not get a valid analysis result for "$path"');
  }

  // Require our program to have a `main()` function so we can call it
  if (result.element.entryPoint == null) {
    logger.shout('No entry point was found for file "$path"');
    throw CommandsException('No entry point was found for file "$path"');
  }

  Iterable<CompileTimeFunctionData> functions =
      await processFunctions(result.element, context, slow);

  String output = generateOutput(
    functions,
    result.element.source.uri.toString(),
    result.element.entryPoint!.parameters.isNotEmpty,
    formatOutput,
  );

  logger.info('Writing output to file "$outPath"');

  await File(outPath).writeAsString(output);

  logger.finest('Done');
}

/// Generates function metadata for all creations of [id] invocations in [result] and child units.
Future<Iterable<CompileTimeFunctionData>> processFunctions(
  LibraryElement result,
  AnalysisContext context,
  bool slow,
) async {
  logger.info('Loading function metadata');

  final FunctionBuilderVisitor functionBuilder = FunctionBuilderVisitor(context, slow);

  await functionBuilder.visitLibrary(result);

  logger.fine('Found ${functionBuilder.ids.length} function instances');

  final Iterable<CompileTimeFunctionData> data = getFunctionData(functionBuilder.ids);

  logger.info('Got data for ${data.length} functions');

  return data;
}

/// Generates the content that should be written to the output file from type and function metadata.
///
/// The resulting file will have an entrypoint that loads the program metadata, and then calls the
/// entrypoint in the file [pathToMainFile].
///
/// If [hasArgsArgument] is set, the entrypoint will be called with the command-line arguments.
///
/// If [formatOutput] is set, the generated content will be passed through `dart format` before
/// being returned.
String generateOutput(
  Iterable<CompileTimeFunctionData> functionData,
  String pathToMainFile,
  bool hasArgsArgument,
  bool formatOutput,
) {
  logger.info('Generating output');

  // Import directives that will be placed at the start of the file
  // Other steps in the generation process can add items to this set in order to import types from
  // other files
  Set<String> imports = {};

  // The base stub:
  // - Imports the nyxx_commands runtime type data classes so we can instantiate them
  // - Imports the specified program entrypoint so we can call it later
  // - Imports `dart:core` so we don't remove it from the global scope by importing it with an alias
  // - Adds a warning comment to the top of the file
  StringBuffer result = StringBuffer('''
  import 'package:nyxx_commands/src/mirror_utils/mirror_utils.dart';
  import '$pathToMainFile' as _main show main;
  import "dart:core";
  
  // Auto-generated file
  // DO NOT EDIT

  // Function data

  ''');

  writeFunctionData(functionData, result, imports);

  result.write('''

// Main function wrapper
void main(List<String> args) {
  loadData(functionData);

  _main.main(${hasArgsArgument ? 'args' : ''});
}
''');

  result = StringBuffer(imports.join('\n'))..write(result.toString());

  if (!formatOutput) {
    return result.toString();
  }

  logger.fine('Formatting output');

  return DartFormatter(lineEnding: '\n').format(result.toString());
}

/// Generates a map literal that maps [id] ids to function metadata that can be used to look up
/// function metadata at runtime, and writes the result to [result].
///
/// Imports needed to write the metadata will be added to [imports].
///
/// [loadedTypeIds] must be a set of type metadata IDs that are available to use.
void writeFunctionData(
  Iterable<CompileTimeFunctionData> functionData,
  StringBuffer result,
  Set<String> imports,
) {
  Set<String> loadedIds = {};

  result.write('const Map<dynamic, FunctionData> functionData = {');

  outerLoop:
  for (final function in functionData) {
    String parameterDataSource = '';

    for (final parameter in function.parametersData) {
      String? converterSource;

      if (parameter.converterOverride != null) {
        List<String>? converterOverrideData = toConverterSource(parameter.converterOverride!);

        if (converterOverrideData == null) {
          logger.shout(
            'Unable to resolve converter override for parameter ${parameter.name}, skipping function',
          );
          continue outerLoop;
        }

        imports.addAll(converterOverrideData.skip(1));

        converterSource = converterOverrideData.first;
      }

      String? defaultValueSource;

      if (parameter.defaultValue != null) {
        List<String>? defaultValueData = toExpressionSource(parameter.defaultValue!);

        if (defaultValueData == null) {
          logger.warning(
            'Unable to resolve default value for parameter ${parameter.name}, skipping function',
          );
          continue outerLoop;
        }

        imports.addAll(defaultValueData.skip(1));

        defaultValueSource = defaultValueData.first;
      }

      String? choicesSource;

      if (parameter.choices != null) {
        List<String>? choicesData = toExpressionSource(parameter.choices!);

        if (choicesData == null) {
          logger.warning(
            'Unable to resolve choices for parameter ${parameter.name}, skipping function',
          );
          continue outerLoop;
        }

        imports.addAll(choicesData.skip(1));

        choicesSource = choicesData.first;
      }

      String? autocompleteSource;

      if (parameter.autocompleteOverride != null) {
        List<String>? autocompleteOverrideData = toConverterSource(parameter.autocompleteOverride!);

        if (autocompleteOverrideData == null) {
          // Unresolved autocomplete functions are more severe than unresolved types as the only
          // case where an autocomplete override is specified is when the @Autocomplete annotation
          // is explicitly used
          logger.shout(
            'Unable to resolve autocomplete override for parameter ${parameter.name}, skipping function',
          );
          continue outerLoop;
        }

        imports.addAll(autocompleteOverrideData.skip(1));

        autocompleteSource = autocompleteOverrideData.first;
      }

      String? localizedNamesSource;

      if (parameter.localizedNames != null) {
        List<String>? localizedNamesData = toExpressionSource(parameter.localizedNames!);

        if (localizedNamesData == null) {
          logger.warning(
            'Unable to resolve localized names for parameter ${parameter.name}, skipping function',
          );
          continue outerLoop;
        }

        imports.addAll(localizedNamesData.skip(1));

        localizedNamesSource = localizedNamesData.first;
      }

      String? localizedDescriptionsSource;

      if (parameter.localizedDescriptions != null) {
        List<String>? localizedDescriptionsData =
            toExpressionSource(parameter.localizedDescriptions!);

        if (localizedDescriptionsData == null) {
          logger.warning(
            'Unable to resolve localized descriptions for parameter ${parameter.name}, skipping function',
          );
          continue outerLoop;
        }

        imports.addAll(localizedDescriptionsData.skip(1));

        localizedDescriptionsSource = localizedDescriptionsData.first;
      }

      List<String>? type = toTypeSource(parameter.type);
      if (type == null) {
        logger.shout('Parameter ${parameter.name} has an unresolved type, skipping function');
        continue outerLoop;
      }

      if (type.first.isNotEmpty) {
        logger.shout('Parameter ${parameter.name} uses a type argument which is disallowed.');
        continue outerLoop;
      }

      imports.addAll(type.skip(2));

      parameterDataSource += '''
        ParameterData(
          name: "${parameter.name}",
          type: const RuntimeType<${type[1]}>.allowingDynamic(),
          isOptional: ${parameter.isOptional},
          description: ${parameter.description == null ? 'null' : '"${parameter.description}"'},
          defaultValue: $defaultValueSource,
          choices: $choicesSource,
          converterOverride: $converterSource,
          autocompleteOverride: $autocompleteSource,
          localizedDescriptions: $localizedDescriptionsSource,
          localizedNames: $localizedNamesSource,
        ),
      ''';
    }

    List<String>? idData = toExpressionSource(function.id);

    if (idData == null) {
      logger.shout("Couldn't resolve id ${function.id}");
      continue;
    }

    if (loadedIds.contains(idData.first)) {
      throw CommandsException('Duplicate identifier for id: ${function.id}');
    }

    loadedIds.add(idData.first);

    imports.addAll(idData.skip(1));

    result.write('${idData.first}: FunctionData([');

    result.write(parameterDataSource);

    result.write(']),');
  }

  result.write('};');
}
