import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:runtime_type/runtime_type.dart';

import '../context/autocomplete_context.dart';
import '../converters/converter.dart';

class FunctionData {
  final List<ParameterData<dynamic>> parametersData;

  int get requiredParameters => parametersData.takeWhile((value) => !value.isOptional).length;

  const FunctionData(this.parametersData);
}

class ParameterData<T> {
  final String name;

  final Map<Locale, String>? localizedNames;

  final RuntimeType<T> type;

  final bool isOptional;

  final String? description;

  final Map<Locale, String>? localizedDescriptions;

  final dynamic defaultValue;

  final Map<String, dynamic>? choices;

  final Converter<dynamic>? converterOverride;

  final FutureOr<Iterable<CommandOptionChoiceBuilder<dynamic>>?> Function(AutocompleteContext)?
      autocompleteOverride;

  const ParameterData({
    required this.name,
    required this.localizedNames,
    required this.type,
    required this.isOptional,
    required this.description,
    required this.localizedDescriptions,
    required this.defaultValue,
    required this.choices,
    required this.converterOverride,
    required this.autocompleteOverride,
  });
}
