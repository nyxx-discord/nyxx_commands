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

abstract class TypeData {
  int get id;

  DartType get source;

  String get name;
}

abstract class NullableTypeData {
  bool get isNullable;
}

class InterfaceTypeData implements TypeData, NullableTypeData {
  @override
  int id;

  @override
  final InterfaceType source;

  @override
  String name;

  int strippedId;

  List<int> superClasses;

  List<int> typeArguments;

  @override
  bool isNullable;

  InterfaceTypeData(
    this.name,
    this.source,
    this.id,
    this.strippedId,
    this.superClasses,
    this.typeArguments,
    this.isNullable,
  );

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

class FunctionTypeData implements TypeData, NullableTypeData {
  @override
  int id;

  @override
  final FunctionType source;

  @override
  String name;

  int returnType;

  List<int> parameterTypes;

  @override
  bool isNullable;

  FunctionTypeData(
      this.name, this.source, this.id, this.returnType, this.parameterTypes, this.isNullable);

  @override
  int get hashCode => id;

  @override
  operator ==(Object other) => identical(this, other) || (other is TypeData && other.id == id);

  @override
  String toString() => 'FunctionTypeData[id=$id, '
      'source=$source, '
      'name=$name, '
      'returnType=$returnType, '
      'parameterTypes=$parameterTypes, '
      'isNullable=$isNullable]';
}

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
