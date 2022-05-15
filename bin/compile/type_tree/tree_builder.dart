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

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:nyxx_commands/src/errors.dart';

import '../generator.dart';
import 'type_data.dart';

final List<DartType> processing = [];

/// Returns an ID that uniquely represents [type].
int getId(DartType type) {
  if (processing.contains(type)) {
    // Probably a type parameter with a bound that references itself
    while (type is TypeParameterType) {
      // Since we only care about the bound itself and not the name of the type parameter, we get
      // rid of it here
      type = type.bound;
    }

    logger.finest('Recursive type found; returning hashCode of element ${type.element}');

    return type.element.hashCode;
  }

  processing.add(type);

  int ret;

  if (type is InterfaceType) {
    if (type.isDartAsyncFutureOr &&
        [
          DynamicTypeData().id,
          VoidTypeData().id,
          NeverTypeData().id,
        ].contains(getId(type.typeArguments.first))) {
      ret = getId(type.typeArguments.first);
    } else {
      ret = Object.hashAll([type.hashCode, ...type.typeArguments.map(getId)]);
    }
  } else if (type is FunctionType) {
    ret = Object.hashAll([getId(type.returnType), ...type.parameters.map((e) => getId(e.type))]);
  } else if (type is DynamicType) {
    ret = DynamicTypeData().id;
  } else if (type is VoidType) {
    ret = VoidTypeData().id;
  } else if (type is NeverType) {
    ret = NeverTypeData().id;
  } else if (type is TypeParameterType) {
    ret = getId(type.bound);
  } else {
    throw CommandsError('Unhandled type $type');
  }

  processing.removeLast();

  if (type.nullabilitySuffix == NullabilitySuffix.question) {
    // null can be assigned to dynamic, void or Never by default
    if (![DynamicTypeData().id, VoidTypeData().id, NeverTypeData().id].contains(ret)) {
      ret++;
    }
  }

  logger.finest('ID for type $type: $ret');

  return ret;
}

// We keep track of the IDs of special types

/// The ID of the [Name] class type.
int get nameId => getId(nameClassElement!.thisType);
ClassElement? nameClassElement;

/// The ID of the [Description] class type.
int get descriptionId => getId(descriptionClassElement!.thisType);
ClassElement? descriptionClassElement;

/// The ID of the [Choices] class type.
int get choicesId => getId(choicesClassElement!.thisType);
ClassElement? choicesClassElement;

/// The ID of the [UseConverter] class type.
int get useConverterId => getId(useConverterClassElement!.thisType);
ClassElement? useConverterClassElement;

/// The ID of the [Autocomplete] class type.
int get autocompleteId => getId(autocompleteClassElement!.thisType);
ClassElement? autocompleteClassElement;

/// The ID of the [Object] class type.
int get objectId => getId(objectClassElement!.thisType);
ClassElement? objectClassElement;

/// The ID of the [Function] class type,
int get functionId => getId(functionClassElement!.thisType);
ClassElement? functionClassElement;

Map<List<String>, void Function(ClassElement)> _specialInterfaceTypeSetters = {
  ['package:nyxx_commands/src/util/util.dart', 'Description']: (element) =>
      descriptionClassElement = element,
  ['package:nyxx_commands/src/util/util.dart', 'Name']: (element) => nameClassElement = element,
  ['package:nyxx_commands/src/util/util.dart', 'Choices']: (element) =>
      choicesClassElement = element,
  ['package:nyxx_commands/src/util/util.dart', 'UseConverter']: (element) =>
      useConverterClassElement = element,
  ['package:nyxx_commands/src/util/util.dart', 'Autocomplete']: (element) =>
      autocompleteClassElement = element,
  ['dart:core/object.dart', 'Object']: (element) => objectClassElement = element,
  ['dart:core/function.dart', 'Function']: (element) => functionClassElement = element,
};

/// Update the special types if needed.
void checkSpecialType(DartType type) {
  if (type is InterfaceType) {
    for (final key in _specialInterfaceTypeSetters.keys) {
      if ((type.element.location?.components.contains(key[0]) ?? false) &&
          type.getDisplayString(withNullability: true) == key[1]) {
        logger.finer('Found special type $key: ${type.element}');

        _specialInterfaceTypeSetters[key]!(type.element);
      }
    }
  }
}

/// Takes a list of [types] and generates type data from them.
///
/// The return value is a mapping of type IDs to their type data.
Map<int, TypeData> buildTree(List<DartType> types) {
  final Map<int, TypeData> result = {};

  List<int> processing = [];

  // Type parameters can have a different ID to their actual reflected type, so we merge them at
  // the end.
  Map<int, int> toMerge = {};

  void handle(DartType type) {
    int id = getId(type);

    logger.finer('Handling type $type (ID $id)');

    if (type is TypeParameterType) {
      handle(type.bound);

      if (result.containsKey(id) || processing.contains(id)) {
        return;
      }

      int boundId = getId(type.bound);

      if (processing.contains(boundId)) {
        toMerge[boundId] = id;
      } else {
        result[id] = result[boundId]!;
      }

      return;
    }

    if (result.containsKey(id) || processing.contains(id)) {
      return;
    }

    checkSpecialType(type);

    processing.add(id);

    if (type is InterfaceType) {
      handle(type.element.thisType);

      for (final superType in type.allSupertypes) {
        handle(superType);
      }

      for (final typeArgument in type.typeArguments) {
        handle(typeArgument);
      }

      result[id] = InterfaceTypeData(
        name: type.getDisplayString(withNullability: true),
        source: type,
        id: id,
        strippedId: getId(type.element.thisType),
        superClasses: type.allSupertypes.map(getId).toList(),
        typeArguments: type.typeArguments.map(getId).toList(),
        isNullable: type.nullabilitySuffix == NullabilitySuffix.question,
      );
    } else if (type is FunctionType) {
      handle(type.returnType);

      int requiredParameterCount = 0;
      List<int> positionalParameterTypes = [];
      Map<String, int> requiredNamedParameters = {};
      Map<String, int> optionalNamedParameters = {};

      for (final parameter in type.parameters) {
        handle(parameter.type);

        if (parameter.isPositional) {
          if (parameter.isRequiredPositional) {
            requiredParameterCount++;
          }

          positionalParameterTypes.add(getId(parameter.type));
        } else if (parameter.isRequiredNamed) {
          requiredNamedParameters[parameter.name] = getId(parameter.type);
        } else if (parameter.isOptionalNamed) {
          optionalNamedParameters[parameter.name] = getId(parameter.type);
        } else {
          throw CommandsError('Unknown parameter type $parameter');
        }
      }

      result[id] = FunctionTypeData(
        name: type.getDisplayString(withNullability: true),
        source: type,
        id: id,
        returnType: getId(type.returnType),
        positionalParameterTypes: positionalParameterTypes,
        requiredPositionalParametersCount: requiredParameterCount,
        requiredNamedParametersType: requiredNamedParameters,
        optionalNamedParametersType: optionalNamedParameters,
        isNullable: type.nullabilitySuffix == NullabilitySuffix.question,
      );
    } else if (type is DynamicType) {
      result[id] = DynamicTypeData();
    } else if (type is VoidType) {
      result[id] = VoidTypeData();
    } else if (type is NeverType) {
      result[id] = NeverTypeData();
    } else {
      throw CommandsError('Couldn\'t generate type data for type "${type.runtimeType}"');
    }

    processing.removeLast();

    for (final key in toMerge.keys.toList()) {
      if (!processing.contains(key)) {
        result[toMerge.remove(key)!] = result[key]!;
      }
    }
  }

  for (final type in types) {
    handle(type);
  }

  return result;
}
