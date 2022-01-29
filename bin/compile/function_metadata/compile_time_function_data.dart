import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

class CompileTimeFunctionData {
  final List<CompileTimeParameterData> parametersData;

  const CompileTimeFunctionData(this.parametersData);
}

class CompileTimeParameterData {
  final String name;

  final DartType type;

  final bool isOptional;

  final String? description;

  final dynamic defaultValue;

  final Map<String, dynamic>? choices;

  final Annotation? converterOverride;

  const CompileTimeParameterData(
    this.name,
    this.type,
    this.isOptional,
    this.description,
    this.defaultValue,
    this.choices,
    this.converterOverride,
  );
}
