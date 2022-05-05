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
import 'type_tree/type_builder_visitor.dart';
import 'type_tree/tree_builder.dart';
import 'type_tree/type_data.dart';

final Logger logger = Logger('Commands Compiler');

/// Generates the metadata for the program located at [path], writing the output to the file at
/// [outPath].
///
/// If [formatOutput] is `true`, the resulting file will be formatted with `dart format`.
Future<void> generate(String path, String outPath, bool formatOutput) async {
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

  Map<int, TypeData> typeTree = await processTypes(result.element, context);

  Iterable<CompileTimeFunctionData> functions = await processFunctions(result.element, context);

  String output = generateOutput(
    {...typeTree.values},
    functions,
    result.element.source.uri.toString(),
    result.element.entryPoint!.parameters.isNotEmpty,
    formatOutput,
  );

  logger.info('Writing output to file "$outPath"');

  await File(outPath).writeAsString(output);

  logger.finest('Done');
}

/// Generates type metadata for [result] and all child units (includes imports, exports and parts).
Future<Map<int, TypeData>> processTypes(LibraryElement result, AnalysisContext context) async {
  logger.info('Building type tree from AST');

  final TypeBuilderVisitor typeBuilder = TypeBuilderVisitor(context);

  await typeBuilder.visitLibrary(result);

  logger.fine('Found ${typeBuilder.types.length} type instances');

  final Map<int, TypeData> typeTree = buildTree(typeBuilder.types);

  logger.info('Finished building type tree with ${typeTree.length} entries');

  return typeTree;
}

/// Generates function metadata for all creations of [Id] instances in [result] and child units.
Future<Iterable<CompileTimeFunctionData>> processFunctions(
    LibraryElement result, AnalysisContext context) async {
  logger.info('Loading function metadata');

  final FunctionBuilderVisitor functionBuilder = FunctionBuilderVisitor(context);

  await functionBuilder.visitLibrary(result);

  logger.fine('Found ${functionBuilder.idCreations.length} function instances');

  final Iterable<CompileTimeFunctionData> data = getFunctionData(functionBuilder.idCreations);

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
  Iterable<TypeData> typeTree,
  Iterable<CompileTimeFunctionData> functionData,
  String pathToMainFile,
  bool hasArgsArgument,
  bool formatOutput,
) {
  logger.info('Generating output');

  // The base stub:
  // - Imports the nyxx_commands runtime type data classes so we can instanciate them
  // - Imports the specified program entrypoint so we can call it later
  // - Imports `dart:core` so we don't remove it from the global scope by importing it with an alias
  // - Adds a warning comment to the top of the file
  StringBuffer result = StringBuffer('''
  import 'package:nyxx_commands/src/mirror_utils/mirror_utils.dart';
  import '$pathToMainFile' as _main show main;
  import "dart:core";
  
  // Auto-generated file
  // DO NOT EDIT

  // Type data

  ''');

  // Import directives that will be placed at the start of the file
  // Other steps in the generation process can add items to this set in order to import types from
  // other files
  Set<String> imports = {};

  typeTree = typeTree.toSet();

  writeTypeMetadata(typeTree, result);

  result.write('''
  
  // Nullable typedefs
  
  ''');

  Set<int> successfulIds = writeTypeDefs(typeTree, result, imports);

  result.write('''

  // Type mappings

  ''');

  writeTypeMappings(successfulIds, result);

  result.write('''

  // Function data

  ''');

  writeFunctionData(functionData, result, imports, successfulIds);

  result.write('''
  
  // Main function wrapper
  void main(List<String> args) {
    loadData(typeTree, typeMappings, functionData);

    _main.main(${hasArgsArgument ? 'args' : ''});
  }
  ''');

  logger.fine('Formatting output');

  result = StringBuffer(imports.join('\n'))..write(result.toString());

  if (!formatOutput) {
    return result.toString();
  }

  return DartFormatter(lineEnding: '\n').format(result.toString());
}

/// Generates the content that represents the type metadata of a program from [typeTree] and writes
/// it to [result].
void writeTypeMetadata(Iterable<TypeData> typeTree, StringBuffer result) {
  result.write('const Map<int, TypeData> typeTree = {');

  // Special types
  result.write('0: DynamicTypeData(),');
  result.write('1: VoidTypeData(),');
  result.write('2: NeverTypeData(),');

  // Other types
  for (final type in typeTree.whereType<InterfaceTypeData>()) {
    result.write('''
      ${type.id}: InterfaceTypeData(
        name: r"${type.name}",
        id: ${type.id},
        strippedId: ${type.strippedId},
        superClasses: [${type.superClasses.join(',')}],
        typeArguments: [${type.typeArguments.join(',')}],
        isNullable: ${type.isNullable},
      ),
    ''');
  }

  for (final type in typeTree.whereType<FunctionTypeData>()) {
    result.write('''
      ${type.id}: FunctionTypeData(
        name: r"${type.name}",
        id: ${type.id},
        returnType: ${type.returnType},
        positionalParameterTypes: [${type.positionalParameterTypes.join(',')}],
        requiredPositionalParametersCount: ${type.requiredPositionalParametersCount},
        requiredNamedParametersType: {${type.requiredNamedParametersType.entries.map((entry) => 'r"${entry.key}": ${entry.value}').join(',')}},
        optionalNamedParametersType: {${type.optionalNamedParametersType.entries.map((entry) => 'r"${entry.key}": ${entry.value}').join(',')}},
        isNullable: ${type.isNullable},
      ),
    ''');
  }

  result.write('};');
}

/// Generates a set of `typedef` statements that can be used as keys in maps to represent types, and
/// writes them to [result].
///
/// Imports needed to create the typedefs are added to [imports].
///
/// This method is needed as nullable type literals are interpreted as ternary statements in some
/// cases, and can lead to errors. Creating a typedef that reflects the same type and using that
/// instead of a type literal avoids this issue.
Set<int> writeTypeDefs(Iterable<TypeData> typeTree, StringBuffer result, Set<String> imports) {
  Set<int> successfulIds = {};

  for (final type in typeTree) {
    if (type is DynamicTypeData || type is VoidTypeData || type is NeverTypeData) {
      result.write('typedef t_${type.id} = ');

      if (type is DynamicTypeData) {
        result.write('dynamic');
      } else if (type is VoidTypeData) {
        result.write('void');
      } else {
        result.write('Never');
      }

      result.write(';');

      successfulIds.add(type.id);
      continue;
    }

    List<String>? typeSourceRepresentation = toTypeSource(type.source);

    if (typeSourceRepresentation == null) {
      logger.fine('Excluding type $type as data for type was not resolved');
      continue;
    }

    successfulIds.add(type.id);

    imports.addAll(typeSourceRepresentation.skip(2));

    result.write(
        'typedef t_${type.id}${typeSourceRepresentation.first} = ${typeSourceRepresentation[1]};\n');
  }

  return successfulIds;
}

/// Generates a map literal that maps runtime [Type] instances to an ID that can be used to look up
/// their metadata, and writes the result to [result].
void writeTypeMappings(Iterable<int> ids, StringBuffer result) {
  result.write('const Map<Type, int> typeMappings = {');

  for (final id in ids) {
    result.write('t_$id: $id,');
  }

  result.write('};');
}

/// Generates a map literal that maps [Id] ids to function metadata that can be used to look up
/// function metadata at runtime, and writes the result to [result].
///
/// Imports needed to write the metadata will be added to [imports].
///
/// [loadedTypeIds] must be a set of type metadata IDs that are available to use.
void writeFunctionData(
  Iterable<CompileTimeFunctionData> functionData,
  StringBuffer result,
  Set<String> imports,
  Set<int> loadedTypeIds,
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

      if (!loadedTypeIds.contains(getId(parameter.type))) {
        logger.shout('Parameter ${parameter.name} has an unresolved type, skipping function');
        continue outerLoop;
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
            'Unable to resolve converter override for parameter ${parameter.name}, skipping function',
          );
          continue outerLoop;
        }

        imports.addAll(autocompleteOverrideData.skip(1));

        autocompleteSource = autocompleteOverrideData.first;
      }

      parameterDataSource += '''
        ParameterData(
          name: "${parameter.name}",
          type: t_${getId(parameter.type)},
          isOptional: ${parameter.isOptional},
          description: ${parameter.description == null ? 'null' : '"${parameter.description}"'},
          defaultValue: $defaultValueSource,
          choices: $choicesSource,
          converterOverride: $converterSource,
          autocompleteOverride: $autocompleteSource,
        ),
      ''';
    }

    List<String>? idData = toExpressionSource(function.id);

    if (idData == null) {
      logger.shout("Couldn't resolve id ${function.id}");
      continue;
    }

    if (loadedIds.contains(idData.first)) {
      throw CommandsException('Duplicate identifier for Id: ${function.id}');
    }

    loadedIds.add(idData.first);

    imports.addAll(idData.skip(1));

    result.write('${idData.first}: FunctionData([');

    result.write(parameterDataSource);

    result.write(']),');
  }

  result.write('};');
}
