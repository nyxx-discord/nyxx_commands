import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

import 'function_metadata/compile_time_function_data.dart';
import 'function_metadata/metadata_builder_visitor.dart';
import 'function_metadata/metadata_builder.dart';
import 'type_tree/type_builder_visitor.dart';
import 'type_tree/tree_builder.dart';
import 'type_tree/type_data.dart';

final Logger logger = Logger('Commands Compiler');

Future<void> generate(String path, String outPath) async {
  path = normalize(absolute(path));

  logger.info('Analyzing file "$path"');

  final ContextLocator locator = ContextLocator();
  final ContextBuilder builder = ContextBuilder();

  final AnalysisContext context =
      builder.createContext(contextRoot: locator.locateRoots(includedPaths: [path]).first);

  final SomeResolvedUnitResult result = await context.currentSession.getResolvedUnit(path);

  logger.info('Finished analyzing file "$path"');

  if (result is! ResolvedUnitResult || !result.exists) {
    logger.shout('Did not get a valid analysis result for "$path"');
    exit(1);
  }

  Map<int, TypeData> typeTree = await processTypes(result, context);

  Iterable<CompileTimeFunctionData> functions = await processFunctions(result, context, typeTree);

  String output =
      generateOutput({...typeTree.values}, functions, result.libraryElement.source.uri.toString());

  logger.info('Writing output to file "$outPath"');

  await File(outPath).writeAsString(output);

  logger.finest('Done');
}

Future<Map<int, TypeData>> processTypes(ResolvedUnitResult result, AnalysisContext context) async {
  logger.info('Building type tree from AST');

  final TypeBuilderVisitor typeBuilder = TypeBuilderVisitor(context);

  result.unit.accept(typeBuilder);

  await typeBuilder.completed;

  logger.fine('Found ${typeBuilder.types.length} type instances');

  final Map<int, TypeData> typeTree = buildTree(typeBuilder.types);

  logger.info('Finished building type tree with ${typeTree.length} entries');

  return typeTree;
}

Future<Iterable<CompileTimeFunctionData>> processFunctions(
    ResolvedUnitResult result, AnalysisContext context, Map<int, TypeData> typeTree) async {
  logger.info('Loading function metadata');

  final FunctionBuilderVisitor functionBuilder = FunctionBuilderVisitor(context);

  result.unit.accept(functionBuilder);

  await functionBuilder.completed;

  logger.fine('Found ${functionBuilder.parameterLists.length} function instances');

  final Iterable<CompileTimeFunctionData> data =
      getFunctionData(functionBuilder.parameterLists, typeTree);

  logger.info('Got data for ${data.length} functions');

  return data;
}

String generateOutput(Iterable<TypeData> typeTree, Iterable<CompileTimeFunctionData> functionData,
    String pathToMainFile) {
  logger.info('Generating output');

  StringBuffer result = StringBuffer('''
  import 'package:nyxx_commands/src/mirror_utils/mirror_utils.dart';
  import '$pathToMainFile' as _main show main;
  
  // Auto-generated file
  // DO NOT EDIT

  // Type data

  ''');

  typeTree = typeTree.toSet();

  result.write('const Map<int, TypeData> typeTree = {');

  // Special types
  result.write('0: DynamicTypeData(),');
  result.write('1: VoidTypeData(),');
  result.write('2: NeverTypeData(),');

  // Other types
  for (final type in typeTree.whereType<InterfaceTypeData>()) {
    result.write(
        '${type.id}: InterfaceTypeData(r"${type.name}", ${type.id}, ${type.strippedId}, [${type.superClasses.join(',')}], [${type.typeArguments.join(',')}], ${type.isNullable}),');
  }

  for (final type in typeTree.whereType<FunctionTypeData>()) {
    result.write(
        '${type.id}: FunctionTypeData(r"${type.name}", ${type.id}, ${type.returnType}, [${type.parameterTypes.join(',')}], ${type.isNullable}),');
  }

  result.write('};');

  result.write('''
  
  // Nullable typedefs
  
  ''');

  Set<String> imports = {'import "dart:core";'}; // Keep core library globally loaded

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

    List<String>? typeSourceRepresentation = toSource(type.source);

    if (typeSourceRepresentation == null) {
      continue;
    }

    successfulIds.add(type.id);

    imports.addAll(typeSourceRepresentation.skip(2));

    result.write(
        'typedef t_${type.id}${typeSourceRepresentation[0]} = ${typeSourceRepresentation[1]};\n');
  }

  result.write('''

  // Type mappings

  ''');

  result.write('const Map<Type, int> typeMappings = {');

  for (final id in successfulIds) {
    result.write('t_$id: $id,');
  }

  result.write('};');

  // result.write('''

  // // Function data

  // ''');

  // result.write('const Map<dynamic, FunctionData> functionData = {');

  // for (final function in functionData) {
  //   result.write('null: FunctionData([');

  //   for (final parameter in function.parametersData) {
  //     result.write('''
  //       ParameterData(
  //         "${parameter.name}",
  //         t_${getId(parameter.type)},
  //         ${parameter.isOptional},
  //         ${parameter.description == null ? 'null' : '"${parameter.description}"'},
  //         "${parameter.defaultValue}",
  //         ${parameter.choices == null ? 'null' : '{${parameter.choices!.entries.map((e) => '${e.key}:${e.value}')}}'},
  //         "${parameter.converterOverride}",
  //       ),
  //     ''');
  //   }

  //   result.write(']),');
  // }

  // result.write('};');

  // TODO: check if main function actually exists in target file
  // TODO: check if main function has an arguments parameter

  result.write('''
  
  // Main function wrapper
  void main() {
    loadData(typeTree, typeMappings);

    _main.main();
  }
  ''');

  logger.fine('Formatting output');

  result = StringBuffer(imports.join('\n'))..write(result.toString());

  return DartFormatter(lineEnding: '\n').format(result.toString());
}

/// Returns a list - the first element is a type argument list, the second element is the type
/// source representation and the others are needed import statements.
List<String>? toSource(DartType type, [bool handleTypeParameters = true]) {
  String typeArguments = '';

  Iterable<TypeParameterType> recursivelyGatherTypeParameters(DartType type,
      [Iterable<TypeParameterType> noHandle = const []]) sync* {
    if (type is TypeParameterType) {
      yield type;
      if (!noHandle.contains(type)) {
        yield* recursivelyGatherTypeParameters(type.bound, [type, ...noHandle]);
      }
    } else if (type is ParameterizedType) {
      for (final typeArgument in type.typeArguments) {
        yield* recursivelyGatherTypeParameters(typeArgument, noHandle);
      }
    } else if (type is FunctionType) {
      yield* recursivelyGatherTypeParameters(type.returnType, noHandle);

      for (final parameterType in type.parameters.map((e) => e.type)) {
        yield* recursivelyGatherTypeParameters(parameterType, noHandle);
      }
    }
  }

  if (handleTypeParameters) {
    List<TypeParameterType> typeParameters =
        recursivelyGatherTypeParameters(type).fold([], (previousValue, element) {
      if (!previousValue.any((t) => t.element == element.element)) {
        previousValue.add(element);
      }
      return previousValue;
    });

    if (typeParameters.isNotEmpty) {
      typeArguments += '<';

      for (final typeParameter in typeParameters) {
        typeArguments += typeParameter.element.name;

        if (typeParameter.bound is! DynamicType) {
          typeArguments += ' extends ';

          List<String>? data = toSource(typeParameter.bound, false);

          if (data == null) {
            return null;
          }

          typeArguments += data[1];
        }

        if (typeParameter != typeParameters.last) {
          typeArguments += ',';
        }
      }

      typeArguments += '>';
    }
  }

  /// First element is the name for the type
  /// Other elements are needed import statements
  List<String>? getNameFor(DartType type) {
    if (type is DynamicType) {
      return ['dynamic'];
    } else if (type is VoidType) {
      return ['void'];
    } else if (type is NeverType) {
      return ['Never'];
    }

    if (type.element?.library?.source.uri.toString().contains(':_') ?? false) {
      return null; // Private library; cannot handle
    } else if (type.getDisplayString(withNullability: true).startsWith('_')) {
      return null; // Private type; cannot handle
    }

    String? importPrefix;
    if (type.element is ClassElement) {
      importPrefix = type.element!.library!.source.uri
          .toString()
          .replaceAll(':', '_')
          .replaceAll('/', '__')
          .replaceAll(r'\', '__')
          .replaceAll('.', '___');
    }

    List<String> imports = [];
    if (importPrefix != null) {
      imports.add('import "${type.element!.library!.source.uri.toString()}" as $importPrefix;');
    }

    String prefix = importPrefix != null ? '$importPrefix.' : '';

    String typeString;
    if (type is ParameterizedType) {
      typeString = prefix;
      typeString += type.element!.name!;

      if (type.typeArguments.isNotEmpty) {
        typeString += '<';

        for (final typeArgument in type.typeArguments) {
          List<String>? data = getNameFor(typeArgument);

          if (data == null) {
            return null;
          }

          typeString += data[0];

          imports.addAll(data.skip(1));

          typeString += ',';
        }

        typeString = typeString.substring(0, typeString.length - 1); // Remove last comma

        typeString += '>';
      }
    } else if (type is FunctionType) {
      List<String>? returnTypeData = getNameFor(type.returnType);

      if (returnTypeData == null) {
        return null;
      }

      imports.addAll(returnTypeData.skip(1));

      typeString = returnTypeData[0];

      typeString += ' Function(';

      for (final parameterType in type.normalParameterTypes) {
        List<String>? parameterData = getNameFor(parameterType);

        if (parameterData == null) {
          return null;
        }

        imports.addAll(parameterData.skip(1));

        typeString += parameterData[0];

        typeString += ',';
      }

      if (type.optionalParameterTypes.isNotEmpty) {
        typeString += '[';

        for (final optionalParameterType in type.optionalParameterTypes) {
          List<String>? parameterData = getNameFor(optionalParameterType);

          if (parameterData == null) {
            return null;
          }

          imports.addAll(parameterData.skip(1));

          typeString += parameterData[0];

          typeString += ',';
        }

        if (typeString.endsWith(',')) {
          typeString = typeString.substring(0, typeString.length - 1); // Remove last comma
        }

        typeString += ']';
      }

      if (type.namedParameterTypes.isNotEmpty) {
        typeString += '{';

        for (final entry in type.namedParameterTypes.entries) {
          List<String>? parameterData = getNameFor(entry.value);

          if (parameterData == null) {
            return null;
          }

          imports.addAll(parameterData.skip(1));

          typeString += '${parameterData[0]} ${entry.key}';

          typeString += ',';
        }

        if (typeString.endsWith(',')) {
          typeString = typeString.substring(0, typeString.length - 1); // Remove last comma
        }

        typeString += '}';
      }

      if (typeString.endsWith(',')) {
        typeString = typeString.substring(0, typeString.length - 1); // Remove last comma
      }

      typeString += ')';
    } else if (type is TypeParameterType) {
      typeString = type.element.name;
    } else {
      typeString = '$prefix${type.toString()}';
    }

    if (type.nullabilitySuffix == NullabilitySuffix.question && !typeString.endsWith('?')) {
      typeString += '?';
    }

    return [typeString, ...imports];
  }

  List<String>? data = getNameFor(type);

  if (data == null) {
    return null;
  }

  return [typeArguments, ...data];
}
