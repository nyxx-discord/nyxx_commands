import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:nyxx_commands/src/errors.dart';
import 'package:analyzer/src/dart/element/element.dart';

/// Converts an import path to a valid Dart import prefix that uniquely represents the path.
String toImportPrefix(String importPath) => importPath
    .replaceAll(':', '_')
    .replaceAll('/', '__')
    .replaceAll(r'\', '__')
    .replaceAll('.', '___');

/// Converts a [DartType] to a representation of that same type in source code.
///
/// The return type is a list containing the following:
/// - The first element is a type argument list that should be appended to the name of the typedef;
/// - The second element is the representation of [type], relying on the type arguments from the
///   first element;
/// - The remaining elements are import statements used in the type representations.
///
/// Returns `null` on failure.
List<String>? toTypeSource(DartType type, [bool handleTypeParameters = true]) {
  String typeArguments = '';

  /// Gathers all the type parameters used in [type].
  ///
  /// Elements in [noHandle] will not be processed.
  Iterable<TypeParameterType> recursivelyGatherTypeParameters(
    DartType type, [
    Iterable<TypeParameterType> noHandle = const [],
  ]) sync* {
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
    // Get all the type parameters in [type].
    List<TypeParameterType> typeParameters = recursivelyGatherTypeParameters(type).fold(
      [],
      (previousValue, element) {
        // Only include each type parameter once
        if (!previousValue.any((t) => t.element == element.element)) {
          previousValue.add(element);
        }

        return previousValue;
      },
    );

    if (typeParameters.isNotEmpty) {
      // Create the type argument list if needed
      typeArguments += '<';

      for (final typeParameter in typeParameters) {
        typeArguments += typeParameter.element.name;

        if (typeParameter.bound is! DynamicType) {
          typeArguments += ' extends ';

          // We've already handled gathering *all* the type parameters in [type], so no need to
          // handle them when converting the bounds to their own source representations,
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

  /// Get the actual name and imports from [type].
  List<String>? getNameFor(DartType type) {
    if (type is DynamicType) {
      return ['dynamic'];
    } else if (type is VoidType) {
      return ['void'];
    } else if (type is NeverType) {
      return ['Never'];
    }

    if (type.element?.library?.source.uri.toString().contains(':_') ?? false) {
      return null; // Private or unresolved library; cannot handle
    } else if (type.getDisplayString(withNullability: true).startsWith('_')) {
      return null; // Private type; cannot handle
    }

    String? importPrefix;
    if (type.element is InterfaceElement) {
      importPrefix = toImportPrefix(type.element!.library!.source.uri.toString());
    }

    List<String> imports = [];
    if (importPrefix != null) {
      imports.add('import "${type.element!.library!.source.uri.toString()}" as $importPrefix;');
    }

    String prefix = importPrefix != null ? '$importPrefix.' : '';

    String typeString;

    if (type is ParameterizedType) {
      // Either a type parameter or a class
      typeString = '$prefix${type.element!.name!}';

      // Add type arguments as needed
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
      // Function types are just composed of other types, so we handle this recursively
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
      // Copy the name of the type parameter. It should have been introduced when we processed type
      // arguments earlier, so we don't need to do anything more
      typeString = type.element.name;
    } else if (type is InterfaceType) {
      // Just a simple class (or enum/mixin)
      typeString = '$prefix${type.toString()}';
    } else {
      throw CommandsError('Unknown type $type');
    }

    // Make it nullable if needed
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

/// Converts an `@UseConverter` [Annotation] to a source code representation of the converter
/// specified.
List<String>? toConverterSource(Annotation useConverterAnnotation) {
  Expression argument = useConverterAnnotation.arguments!.arguments.first;

  return toExpressionSource(argument);
}

/// Converts an [Expression] to a representation of that same expression in source code.
/// [expression] must be a valid constant or this method may fail.
///
/// The return type is a list containing the following:
/// - The first element is the representation of [expression];
/// - The remaining elements are import statements used in the expression.
///
/// Returns `null` on failure.
List<String>? toExpressionSource(Expression expression) {
  // Simple types: Strings, integers, doubles, booleans, lists, maps
  if (expression is StringLiteral) {
    if (expression is SimpleStringLiteral) {
      return [expression.literal.lexeme];
    } else if (expression is AdjacentStrings) {
      return [expression.strings.map(toExpressionSource).join('')];
    } else {
      throw CommandsError('Unsupported string literal type $expression');
    }
  } else if (expression is IntegerLiteral) {
    return [expression.literal.lexeme];
  } else if (expression is DoubleLiteral) {
    return [expression.literal.lexeme];
  } else if (expression is BooleanLiteral) {
    return [expression.literal.lexeme];
  } else if (expression is ListLiteral || expression is SetOrMapLiteral) {
    // Lists and maps are very similar, so we reuse the same conversion for both
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
      // Unreachable
      assert(false);
      return null;
    }

    String ret = 'const $openingBrace';

    for (final item in elements) {
      // Convert each element to its source representation, then join them back together.
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
            toTypeSource((referenced.variable.enclosingElement as InterfaceElement).thisType);

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
      List<String>? typeData =
          toTypeSource((referenced.enclosingElement as InterfaceElement).thisType);

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

/// Converts a [CollectionElement] to a representation of that same element in source code.
///
/// The return type is a list containing the following:
/// - The first element is the representation of [item];
/// - The remaining elements are import statements used in the expression.
///
/// Returns `null` on failure.
List<String>? toCollectionElementSource(CollectionElement item) {
  if (item is Expression) {
    // In most cases, [item] will just be another expression
    return toExpressionSource(item);
  } else if (item is IfElement) {
    // Collection if statement
    String ret = 'if(';

    List<String> imports = [];

    List<String>? conditionSource = toExpressionSource(item.expression);

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
    // Collection for statement: disallowed because it is not const
    throw CommandsException('Cannot reproduce for loops');
  } else if (item is MapLiteralEntry) {
    // In the case we have a map, we need to convert both the key and the value
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
