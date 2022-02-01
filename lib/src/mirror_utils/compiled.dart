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

import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_commands/src/mirror_utils/mirror_utils.dart';
import 'package:nyxx_commands/src/util/util.dart';

Map<int, TypeData>? _typeTree;
Map<Type, int>? _typeMappings;
Map<dynamic, FunctionData>? _functionData;

bool isAssignableTo(Type instance, Type target) {
  if (_typeTree == null || _typeMappings == null) {
    throw CommandsError('Type data was not correctly loaded. Did you compile the wrong file?');
  }

  int? instanceId = _typeMappings?[instance];
  int? targetId = _typeMappings?[target];

  if (instanceId == null) {
    throw CommandsException('Couldnt find type data for type $instance');
  } else if (targetId == null) {
    throw CommandsException('Couldnt find type data for type $target');
  }

  return _isAAssignableToB(instanceId, targetId, _typeTree!);
}

// Essentially copied from bin/compile/type_tree/util.dart
bool _isAAssignableToB(int aId, int bId, Map<int, TypeData> typeTree) {
  TypeData a = typeTree[aId]!;
  TypeData b = typeTree[bId]!;

  // Identical
  if (a.id == b.id) return true; // x => x

  // Never
  if (b is NeverTypeData || a is NeverTypeData) return false; // * => Never || Never => *

  // Dynamic and void
  if (b is VoidTypeData) return true; // * - {Never} => void
  if (a is VoidTypeData) return false; // void => * - {void, Never}
  if (b is DynamicTypeData) return true; // * - {void, Never} => dynamic
  if (a is DynamicTypeData) return false; // dynamic => * - {void, Never, dynamic}

  // Object to function
  if (a is! FunctionTypeData && b is FunctionTypeData) return false; // * - {Function} => Function

  // Object to object
  if (a is InterfaceTypeData && b is InterfaceTypeData) {
    if (a.strippedId == b.strippedId) {
      // A and B are the same class with different type arguments. Check if the type arguments
      // are subtypes.
      for (int i = 0; i < a.typeArguments.length; i++) {
        if (!_isAAssignableToB(a.typeArguments[i], b.typeArguments[i], typeTree)) {
          return false;
        }
      }

      return b.isNullable || !a.isNullable;
    } else {
      // A and B are different classes. Check if one of A's supertypes is assignable to B
      for (final superId in a.superClasses) {
        if (_isAAssignableToB(superId, bId, typeTree)) {
          return true;
        }
      }

      return false;
    }
  } else if (a is FunctionTypeData && b is InterfaceTypeData) {
    // Functions can only be assigned to [Object] and [Function] interface types
    return (b.id == _typeMappings![Object] || b.id == _typeMappings![Function]) &&
        (b.isNullable || !a.isNullable);
  } else if (a is InterfaceTypeData && b is FunctionTypeData) {
    // Objects cannot be assigned to functions
    return false;
  } else if (a is FunctionTypeData && b is FunctionTypeData) {
    if (a.parameterTypes.length != b.parameterTypes.length) {
      return false; // TODO: optional & named parameters
    }

    // Parameter types can be widened but not narrowed
    for (int i = 0; i < a.parameterTypes.length; i++) {
      if (!_isAAssignableToB(b.parameterTypes[i], a.parameterTypes[i], typeTree)) {
        return false;
      }
    }

    // Return type can be widened but not narrowed
    if (!_isAAssignableToB(b.returnType, a.returnType, typeTree)) {
      return false;
    }

    return b.isNullable || !a.isNullable;
  }

  throw CommandsException(
    'Unhandled assignability check between types '
    '"${a.runtimeType}" and "${b.runtimeType}"',
  );
}

FunctionData loadFunctionData(Function fn) {
  if (_functionData == null) {
    throw CommandsError('Function data was not correctly loaded. Did you compile the wrong file?');
  }

  dynamic id = idMap[fn.hashCode];

  FunctionData? result = _functionData![id];

  if (result == null) {
    throw CommandsException("Couldn't load function data for function $fn");
  }

  return result;
}

void loadData(
  Map<int, TypeData> typeTree,
  Map<Type, int> typeMappings,
  Map<dynamic, FunctionData> functionData,
) {
  _typeTree = typeTree;
  _typeMappings = typeMappings;
  _functionData = functionData;
}
