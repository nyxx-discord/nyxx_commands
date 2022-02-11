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

import 'dart:mirrors';

import 'package:nyxx_commands/src/commands.dart';
import 'package:nyxx_commands/src/mirror_utils/mirror_utils.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_commands/src/util/util.dart';

bool isAssignableTo(Type instance, Type target) =>
    instance == target || reflectType(instance).isSubtypeOf(reflectType(target));

FunctionData loadFunctionData(Function fn) {
  if (wrappedMap.containsKey(fn.hashCode)) {
    fn = wrappedMap[fn.hashCode]!;
  }

  List<ParameterData> parametersData = [];

  MethodMirror fnMirror = (reflect(fn) as ClosureMirror).function;

  for (final parameterMirror in fnMirror.parameters) {
    if (parameterMirror.isNamed) {
      throw CommandRegistrationError(
        'Cannot load function data for functions with named parameters',
      );
    }

    // Get parameter name
    String name = MirrorSystem.getName(parameterMirror.simpleName);

    // Get parameter type
    Type type =
        parameterMirror.type.hasReflectedType ? parameterMirror.type.reflectedType : dynamic;

    Iterable<T> getAnnotations<T>() =>
        parameterMirror.metadata.map((e) => e.reflectee).whereType<T>();

    // Get parameter description (if any)

    Iterable<Description> descriptionAnnotations = getAnnotations<Description>();
    if (descriptionAnnotations.length > 1) {
      throw CommandRegistrationError('parameters may have at most one Description annotation');
    }

    String? description;
    if (descriptionAnnotations.isNotEmpty) {
      description = descriptionAnnotations.first.value;
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

    parametersData.add(ParameterData(
      name,
      type,
      parameterMirror.isOptional,
      description,
      parameterMirror.defaultValue?.reflectee,
      choices,
      converterOverride,
    ));
  }

  return FunctionData(parametersData);
}

void loadData(
  Map<int, TypeData> typeTree,
  Map<Type, int> typeMappings,
  Map<dynamic, FunctionData> functionData,
) {
  if (const bool.fromEnvironment('dart.library.mirrors')) {
    logger.info('Loading compiled function data when `dart:mirrors` is availible is unneeded');
  }
}
