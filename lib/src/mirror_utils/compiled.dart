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

bool _isAAssignableToB(int aId, int bId, Map<int, TypeData> typeTree) {
  TypeData a = typeTree[aId]!;
  TypeData b = typeTree[bId]!;

  // Identical
  if (a.id == b.id) {
    // x => x
    return true;
  }

  // Never
  if (b is NeverTypeData || a is NeverTypeData) {
    // * => Never || Never => *
    return false;
  }

  // Dynamic and void
  if (b is VoidTypeData) {
    // * - {Never} => void
    return true;
  }

  if (a is VoidTypeData) {
    // void => * - {void, Never}
    return false;
  }

  if (b is DynamicTypeData) {
    // * - {void, Never} => dynamic
    return true;
  }

  if (a is DynamicTypeData) {
    // dynamic => * - {void, Never, dynamic}
    return false;
  }

  // Object to function
  if (a is! FunctionTypeData && b is FunctionTypeData) {
    // * - {Function} => Function
    return false;
  }

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
    return (b.id == _typeMappings![Object]! || b.id == _typeMappings![Function]!) &&
        (b.isNullable || !a.isNullable);
  } else if (a is InterfaceTypeData && b is FunctionTypeData) {
    // Objects cannot be assigned to functions
    return false;
  } else if (a is FunctionTypeData && b is FunctionTypeData) {
    if (a.positionalParameterTypes.length > b.positionalParameterTypes.length) {
      return false;
    }

    if (b.requiredPositionalParametersCount > a.requiredPositionalParametersCount) {
      return false;
    }

    // Parameter types can be widened but not narrowed
    for (int i = 0; i < a.positionalParameterTypes.length; i++) {
      if (!_isAAssignableToB(
          a.positionalParameterTypes[i], b.positionalParameterTypes[i], typeTree)) {
        return false;
      }
    }

    for (final entry in a.requiredNamedParametersType.entries) {
      String name = entry.key;
      int id = entry.value;

      // Required named parameters in a must be in b, but can be either required or optional
      int? matching = b.requiredNamedParametersType[name] ?? b.optionalNamedParametersType[name];

      if (matching == null) {
        return false;
      }

      if (!_isAAssignableToB(id, matching, typeTree)) {
        return false;
      }
    }

    for (final entry in a.optionalNamedParametersType.entries) {
      String name = entry.key;
      int id = entry.value;

      // Optional named parameters in a must also be optional in b
      int? matching = b.optionalNamedParametersType[name];

      if (matching == null) {
        return false;
      }

      if (!_isAAssignableToB(id, matching, typeTree)) {
        return false;
      }
    }

    // Return type can be narrowed but not widened
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

  dynamic id = idMap[fn];

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
