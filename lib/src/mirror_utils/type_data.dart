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

abstract class TypeData {
  int get id;

  String get name;
}

abstract class NullableTypeData {
  bool get isNullable;
}

class InterfaceTypeData implements TypeData, NullableTypeData {
  @override
  final int id;

  @override
  final String name;

  final int strippedId;

  final List<int> superClasses;

  final List<int> typeArguments;

  @override
  final bool isNullable;

  const InterfaceTypeData(
      this.name, this.id, this.strippedId, this.superClasses, this.typeArguments, this.isNullable);
}

class FunctionTypeData implements TypeData, NullableTypeData {
  @override
  final int id;

  @override
  final String name;

  final int returnType;

  final List<int> parameterTypes;

  @override
  final bool isNullable;

  const FunctionTypeData(this.name, this.id, this.returnType, this.parameterTypes, this.isNullable);
}

class DynamicTypeData implements TypeData {
  @override
  final int id = 0;

  @override
  final String name = 'dynamic';

  const DynamicTypeData();
}

class VoidTypeData implements TypeData {
  @override
  final int id = 1;

  @override
  final String name = 'void';

  const VoidTypeData();
}

class NeverTypeData implements TypeData {
  @override
  final int id = 2;

  @override
  final String name = 'Never';

  const NeverTypeData();
}
