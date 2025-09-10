import 'dart:async';
import 'dart:mirrors';

import 'package:nyxx/nyxx.dart';
import 'package:runtime_type/mirrors.dart';

import '../commands.dart';
import '../context/autocomplete_context.dart';
import '../converters/converter.dart';
import '../errors.dart';
import '../util/util.dart';
import 'mirror_utils.dart';

final Map<Function, FunctionData> _cache = {};

FunctionData loadFunctionData(Function fn) {
  if (_cache.containsKey(fn)) {
    return _cache[fn]!;
  }

  List<ParameterData<dynamic>> parametersData = [];

  MethodMirror fnMirror = (reflect(fn) as ClosureMirror).function;

  for (final parameterMirror in fnMirror.parameters) {
    if (parameterMirror.isNamed) {
      throw CommandRegistrationError(
        'Cannot load function data for functions with named parameters',
      );
    }

    // Get parameter name
    String name = MirrorSystem.getName(parameterMirror.simpleName);

    Iterable<T> getAnnotations<T>() => parameterMirror.metadata.map((e) => e.reflectee).whereType<T>();

    // If present, get name annotation and localized names
    Iterable<Name> nameAnnotations = getAnnotations<Name>();
    Map<Locale, String>? nameLocales;

    if (nameAnnotations.length > 1) {
      throw CommandRegistrationError('parameters may have at most one Name annotation');
    }

    if (nameAnnotations.isNotEmpty) {
      // Override name
      name = nameAnnotations.first.name;
      nameLocales = nameAnnotations.first.localizedNames;
    }

    // Get parameter type
    Type rawType = parameterMirror.type.hasReflectedType ? parameterMirror.type.reflectedType : dynamic;
    RuntimeType<dynamic> type = rawType.toRuntimeType();

    // Get parameter description (if any)

    Iterable<Description> descriptionAnnotations = getAnnotations<Description>();
    if (descriptionAnnotations.length > 1) {
      throw CommandRegistrationError('parameters may have at most one Description annotation');
    }

    String? description;
    Map<Locale, String>? descriptionLocales;
    if (descriptionAnnotations.isNotEmpty) {
      description = descriptionAnnotations.first.value;
      descriptionLocales = descriptionAnnotations.first.localizedDescriptions;
    }

    // Get parameter choices

    Iterable<Choices> choicesAnnotations = getAnnotations<Choices>();
    if (choicesAnnotations.length > 1) {
      throw CommandRegistrationError('parameters may have at most one Choices decorator');
    }

    Map<String, dynamic>? choices;
    if (choicesAnnotations.isNotEmpty) {
      choices = choicesAnnotations.first.choices;
    }

    // Get parameter converter override

    Iterable<UseConverter> useConverterAnnotations = getAnnotations<UseConverter>();
    if (useConverterAnnotations.length > 1) {
      throw CommandRegistrationError('parameters may have at most one UseConverter decorator');
    }

    Converter<dynamic>? converterOverride;
    if (useConverterAnnotations.isNotEmpty) {
      converterOverride = useConverterAnnotations.first.converter;
    }

    // Get parameter autocomplete override

    Iterable<Autocomplete> autocompleteAnnotations = getAnnotations<Autocomplete>();
    if (autocompleteAnnotations.length > 1) {
      throw CommandRegistrationError('parameters may have at most one Autocomplete decorator');
    }

    FutureOr<Iterable<CommandOptionChoiceBuilder<dynamic>>?> Function(AutocompleteContext)? autocompleteOverride;
    if (autocompleteAnnotations.isNotEmpty) {
      autocompleteOverride = autocompleteAnnotations.first.callback;
    }

    parametersData.add(ParameterData(
      name: name,
      localizedNames: nameLocales,
      type: type,
      isOptional: parameterMirror.isOptional,
      description: description,
      localizedDescriptions: descriptionLocales,
      defaultValue: parameterMirror.defaultValue?.reflectee,
      choices: choices,
      converterOverride: converterOverride,
      autocompleteOverride: autocompleteOverride,
    ));
  }

  return _cache[fn] = FunctionData(parametersData);
}

void loadData(Map<dynamic, FunctionData> functionData) {
  if (const bool.fromEnvironment('dart.library.mirrors')) {
    logger.info('Loading compiled function data when `dart:mirrors` is available is unneeded');
  }
}
