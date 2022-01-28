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
