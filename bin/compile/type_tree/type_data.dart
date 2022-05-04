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

import 'package:analyzer/dart/element/type.dart';

/// A representation of a type.
abstract class TypeData {
  /// The ID of this type.
  int get id;

  /// The [DartType] from which this type data was generated.
  DartType get source;

  /// The name of this type.
  String get name;
}

/// A nullable type.
abstract class NullableTypeData {
  /// Whether this type is nullable.
  bool get isNullable;
}

/// Type data for a class, enum or mixin ("interfaces").
class InterfaceTypeData implements TypeData, NullableTypeData {
  @override
  int id;

  @override
  final InterfaceType source;

  @override
  String name;

  /// The "stripped id" of this type.
  ///
  /// This is the ID of this same type, but without any specific type arguments.
  int strippedId;

  /// The super classes of this type.
  List<int> superClasses;

  /// The type arguments of this type.
  List<int> typeArguments;

  @override
  bool isNullable;

  InterfaceTypeData({
    required this.name,
    required this.source,
    required this.id,
    required this.strippedId,
    required this.superClasses,
    required this.typeArguments,
    required this.isNullable,
  });

  @override
  int get hashCode => id;

  @override
  operator ==(Object other) => identical(this, other) || (other is TypeData && other.id == id);

  @override
  String toString() => 'InterfaceTypeData[id=$id, '
      'source=$source, '
      'name=$name, '
      'strippedId=$strippedId, '
      'superClasses=$superClasses, '
      'typeArguments=$typeArguments, '
      'isNullable=$isNullable]';
}

/// Type data for a function type.
class FunctionTypeData implements TypeData, NullableTypeData {
  @override
  int id;

  @override
  final FunctionType source;

  @override
  String name;

  /// The ID of the return type of this function.
  int returnType;

  /// The types of the positional parameters of this function.
  List<int> positionalParameterTypes;

  /// The number of required parameters of this function.
  int requiredPositionalParametersCount;

  /// The types of the optional named parameters of this function.
  Map<String, int> optionalNamedParametersType;

  /// The types of the required named parameters of this function.
  Map<String, int> requiredNamedParametersType;

  @override
  bool isNullable;

  FunctionTypeData({
    required this.name,
    required this.source,
    required this.id,
    required this.returnType,
    required this.positionalParameterTypes,
    required this.isNullable,
    required this.requiredPositionalParametersCount,
    required this.optionalNamedParametersType,
    required this.requiredNamedParametersType,
  });

  @override
  int get hashCode => id;

  @override
  operator ==(Object other) => identical(this, other) || (other is TypeData && other.id == id);

  @override
  String toString() => 'FunctionTypeData[id=$id, '
      'source=$source, '
      'name=$name, '
      'returnType=$returnType, '
      'parameterTypes=$positionalParameterTypes, '
      'isNullable=$isNullable]';
}

/// Type data for the `dynamic` type.
class DynamicTypeData implements TypeData {
  @override
  int id = 0;

  @override
  DynamicType get source => throw UnsupportedError('Cannot get source for dynamic');

  @override
  String name = 'dynamic';

  @override
  int get hashCode => id;

  @override
  operator ==(Object other) => identical(this, other) || (other is TypeData && other.id == id);

  @override
  String toString() => 'DynamicTypeData';
}

/// Type data for the `void` type.
class VoidTypeData implements TypeData {
  @override
  int id = 1;

  @override
  VoidType get source => throw UnsupportedError('Cannot get source for void');

  @override
  String name = 'void';

  @override
  int get hashCode => id;

  @override
  operator ==(Object other) => identical(this, other) || (other is TypeData && other.id == id);

  @override
  String toString() => 'VoidTypeData';
}

/// Type data for the "Never" type.
class NeverTypeData implements TypeData {
  @override
  int id = 2;

  @override
  NeverType get source => throw UnsupportedError('Cannot get source for Never');

  @override
  String name = 'Never';

  @override
  int get hashCode => id;

  @override
  operator ==(Object other) => identical(this, other) || (other is TypeData && other.id == id);

  @override
  String toString() => 'NeverTypeData';
}
