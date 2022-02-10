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
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:nyxx_commands/src/errors.dart';
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
    throw CommandsException('Did not get a valid analysis result for "$path"');
  }

  if (result.libraryElement.entryPoint == null) {
    logger.shout('No entry point was found for file "$path"');
    throw CommandsException('No entry point was found for file "$path"');
  }

  if (result.errors.where((element) => element.severity == Severity.error).isNotEmpty) {
    logger.shout('File "$path" contains analysis errors');
    throw CommandsException('File "$path" contains analysis errors');
  }

  Map<int, TypeData> typeTree = await processTypes(result, context);

  Iterable<CompileTimeFunctionData> functions = await processFunctions(result, context, typeTree);

  String output = generateOutput(
    {...typeTree.values},
    functions,
    result.libraryElement.source.uri.toString(),
    result.libraryElement.entryPoint!.parameters.isNotEmpty,
  );

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

  logger.fine('Found ${functionBuilder.idCreations.length} function instances');

  final Iterable<CompileTimeFunctionData> data = getFunctionData(functionBuilder.idCreations);

  logger.info('Got data for ${data.length} functions');

  return data;
}

String generateOutput(
  Iterable<TypeData> typeTree,
  Iterable<CompileTimeFunctionData> functionData,
  String pathToMainFile,
  bool hasArgsArgument,
) {
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

  result.write('''

  // Type mappings

  ''');

  result.write('const Map<Type, int> typeMappings = {');

  for (final id in successfulIds) {
    result.write('t_$id: $id,');
  }

  result.write('};');

  result.write('''

  // Function data

  ''');

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
          // Unresolved converters are more severe than unresolved types as the only case where a
          // converter override is specified is when the @UseConverter annotation is explicitly used
          logger.shout(
            'Unable to resolve converter override for parameter ${parameter.name}, skipping function',
          );
          continue outerLoop;
        }

        imports.addAll(converterOverrideData.skip(1));

        converterSource = converterOverrideData.first;
      }

      if (!successfulIds.contains(getId(parameter.type))) {
        logger.fine('Parameter ${parameter.name} has an unresolved type, skipping function');
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

      parameterDataSource += '''
        ParameterData(
          "${parameter.name}",
          t_${getId(parameter.type)},
          ${parameter.isOptional},
          ${parameter.description == null ? 'null' : '"${parameter.description}"'},
          $defaultValueSource,
          $choicesSource,
          $converterSource,
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

  result.write('''
  
  // Main function wrapper
  void main(List<String> args) {
    loadData(typeTree, typeMappings, functionData);

    _main.main(${hasArgsArgument ? 'args' : ''});
  }
  ''');

  logger.fine('Formatting output');

  result = StringBuffer(imports.join('\n'))..write(result.toString());

  return DartFormatter(lineEnding: '\n').format(result.toString());
}

String toImportPrefix(String importPath) => importPath
    .replaceAll(':', '_')
    .replaceAll('/', '__')
    .replaceAll(r'\', '__')
    .replaceAll('.', '___');

/// Returns a list - the first element is a type argument list, the second element is the type
/// source representation and the others are needed import statements.
List<String>? toTypeSource(DartType type, [bool handleTypeParameters = true]) {
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

          List<String>? data = toTypeSource(typeParameter.bound, false);

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
      importPrefix = toImportPrefix(type.element!.library!.source.uri.toString());
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

          typeString += data.first;

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

      typeString = returnTypeData.first;

      typeString += ' Function(';

      for (final parameterType in type.normalParameterTypes) {
        List<String>? parameterData = getNameFor(parameterType);

        if (parameterData == null) {
          return null;
        }

        imports.addAll(parameterData.skip(1));

        typeString += parameterData.first;

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

          typeString += parameterData.first;

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

          typeString += '${parameterData.first} ${entry.key}';

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

List<String>? toConverterSource(Annotation useConverterAnnotation) {
  Expression argument = useConverterAnnotation.arguments!.arguments.first;

  return toExpressionSource(argument);
}

List<String>? toExpressionSource(Expression expression) {
  if (expression is StringLiteral) {
    return ['"${expression.stringValue!.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"'];
  } else if (expression is IntegerLiteral) {
    return [expression.value!.toString()];
  } else if (expression is BooleanLiteral) {
    return [expression.value.toString()];
  } else if (expression is ListLiteral || expression is SetOrMapLiteral) {
    List<String> imports = [];

    String openingBrace, closingBrace;
    NodeList<CollectionElement> elements;

    if (expression is ListLiteral) {
      openingBrace = '[';
      closingBrace = ']';

      elements = expression.elements;
    } else if (expression is SetOrMapLiteral) {
      openingBrace = '{';
      closingBrace = '}';

      elements = expression.elements;
    } else {
      assert(false);
      return null;
    }

    String ret = 'const $openingBrace';

    for (final item in elements) {
      List<String>? elementData = toCollectionElementSource(item);

      if (elementData == null) {
        return null;
      }

      imports.addAll(elementData.skip(1));

      ret += elementData.first;

      ret += ',';
    }

    ret += closingBrace;

    return [
      ret,
      ...imports,
    ];
  } else if (expression is Identifier) {
    Element referenced = expression.staticElement!;

    if (referenced is PropertyAccessorElement) {
      if (referenced.variable is TopLevelVariableElement) {
        TopLevelVariableElement variable = referenced.variable as TopLevelVariableElement;

        if (variable.library.source.uri.toString().contains(':_')) {
          return null; // Private library; cannot handle
        } else if (!variable.isPublic) {
          return null; // Private variable; cannot handle
        }

        String importPrefix = toImportPrefix(variable.library.source.uri.toString());

        return [
          '$importPrefix.${variable.name}',
          'import "${variable.library.source.uri.toString()}" as $importPrefix;',
        ];
      } else if (referenced.variable is FieldElement) {
        List<String>? typeData =
            toTypeSource((referenced.variable.enclosingElement as ClassElement).thisType);

        if (typeData == null || !referenced.variable.isPublic || !referenced.variable.isStatic) {
          return null;
        }

        if (typeData.first.isNotEmpty) {
          // Can't handle type parameters
          throw CommandsException('Cannot handle type parameters in expression toSource()');
        }

        return [
          '${typeData[1]}.${referenced.variable.name}',
          ...typeData.skip(2),
        ];
      } else {
        throw CommandsError('Unhandled property accessor type ${referenced.variable.runtimeType}');
      }
    } else if (referenced is FunctionElement) {
      if (referenced.isPublic) {
        String importPrefix = toImportPrefix(referenced.library.source.uri.toString());

        if (referenced.library.source.uri.toString().contains(':_')) {
          return null; // Private library; cannot handle
        }

        return [
          '$importPrefix.${referenced.name}',
          'import "${referenced.library.source.uri.toString()}" as $importPrefix;',
        ];
      } else {
        return null; // Cannot handle private functions
      }
    } else if (referenced is MethodElement) {
      List<String>? typeData = toTypeSource((referenced.enclosingElement as ClassElement).thisType);

      if (typeData == null || !referenced.isPublic || !referenced.isStatic) {
        return null;
      }

      if (typeData.first.isNotEmpty) {
        // Can't handle type parameters
        throw CommandsException('Cannot handle type parameters in expression toSource()');
      }

      return [
        '${typeData[1]}.${referenced.name}',
        ...typeData.skip(2),
      ];
    } else if (referenced is ConstVariableElement) {
      return toExpressionSource(referenced.constantInitializer!);
    }
  } else if (expression is InstanceCreationExpression) {
    List<String>? typeData = toTypeSource(expression.staticType!);

    if (typeData == null) {
      return null;
    }

    List<String> imports = typeData.skip(2).toList();

    if (typeData.first.isNotEmpty) {
      // Can't handle type parameters
      throw CommandsException('Cannot handle type parameters in toExpressionSource()');
    }

    String namedConstructor = '';
    if (expression.constructorName.name != null) {
      namedConstructor = '.${expression.constructorName.name!.name}';
    }

    String result = '${typeData[1]}$namedConstructor(';

    for (final argument in expression.argumentList.arguments) {
      List<String>? argumentData = toExpressionSource(argument);

      if (argumentData == null) {
        return null;
      }

      imports.addAll(argumentData.skip(1));

      result += '${argumentData.first},';
    }

    result += ')';

    return [
      result,
      ...imports,
    ];
  } else if (expression is NamedExpression) {
    List<String>? wrappedExpressionData = toExpressionSource(expression.expression);

    if (wrappedExpressionData == null) {
      return null;
    }

    return [
      '${expression.name.label.name}: ${wrappedExpressionData.first}',
      ...wrappedExpressionData.skip(1),
    ];
  } else if (expression is PrefixExpression) {
    List<String>? expressionData = toExpressionSource(expression.operand);

    if (expressionData == null) {
      return null;
    }

    return [
      '${expression.operator.lexeme}${expressionData.first}',
      ...expressionData.skip(1),
    ];
  } else if (expression is BinaryExpression) {
    List<String>? leftData = toExpressionSource(expression.leftOperand);
    List<String>? rightData = toExpressionSource(expression.rightOperand);

    if (leftData == null || rightData == null) {
      return null;
    }

    return [
      '${leftData.first}${expression.operator.lexeme}${rightData.first}',
      ...leftData.skip(1),
      ...rightData.skip(1),
    ];
  }

  throw CommandsError('Unhandled constant expression $expression');
}

List<String>? toCollectionElementSource(CollectionElement item) {
  if (item is Expression) {
    return toExpressionSource(item);
  } else if (item is IfElement) {
    String ret = 'if(';

    List<String> imports = [];

    List<String>? conditionSource = toExpressionSource(item.condition);

    if (conditionSource == null) {
      return null;
    }

    imports.addAll(conditionSource.skip(1));

    ret += conditionSource.first;

    ret += ') ';

    List<String>? thenSource = toCollectionElementSource(item.thenElement);

    if (thenSource == null) {
      return null;
    }

    imports.addAll(thenSource.skip(1));

    ret += thenSource.first;

    if (item.elseElement != null) {
      ret += ' else ';

      List<String>? elseSource = toCollectionElementSource(item.elseElement!);

      if (elseSource == null) {
        return null;
      }

      imports.addAll(elseSource.skip(1));

      ret += elseSource.first;
    }

    return [
      ret,
      ...imports,
    ];
  } else if (item is ForElement) {
    throw CommandsException('Cannot reproduce for loops');
  } else if (item is MapLiteralEntry) {
    List<String>? keyData = toExpressionSource(item.key);
    List<String>? valueData = toExpressionSource(item.value);

    if (keyData == null || valueData == null) {
      return null;
    }

    return [
      '${keyData.first}: ${valueData.first}',
      ...keyData.skip(1),
      ...valueData.skip(1),
    ];
  } else if (item is SpreadElement) {
    List<String>? expressionData = toExpressionSource(item.expression);

    if (expressionData == null) {
      return null;
    }

    return [
      '...${item.isNullAware ? '?' : ''}${expressionData.first}',
      ...expressionData.skip(1),
    ];
  } else {
    throw CommandsError('Unhandled type in collection literal: ${item.runtimeType}');
  }
}
