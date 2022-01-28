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
}
