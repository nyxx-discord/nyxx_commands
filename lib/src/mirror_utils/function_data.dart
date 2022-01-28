import 'package:nyxx_commands/src/converters/converter.dart';

class FunctionData {
  final List<ParameterData> parametersData;

  int get requiredParameters => parametersData.takeWhile((value) => !value.isOptional).length;

  const FunctionData(this.parametersData);
}

class ParameterData {
  final String name;

  final Type type;

  final bool isOptional;

  final String? description;

  final dynamic defaultValue;

  final Map<String, dynamic>? choices;

  final Converter<dynamic>? converterOverride;

  const ParameterData(
    this.name,
    this.type,
    this.isOptional,
    this.description,
    this.defaultValue,
    this.choices,
    this.converterOverride,
  );
}
