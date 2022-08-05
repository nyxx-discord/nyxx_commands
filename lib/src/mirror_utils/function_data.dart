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

import 'dart:async';

import 'package:nyxx_commands/src/context/autocomplete_context.dart';
import 'package:nyxx_commands/src/converters/converter.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

class FunctionData {
  final List<ParameterData> parametersData;

  int get requiredParameters => parametersData.takeWhile((value) => !value.isOptional).length;

  const FunctionData(this.parametersData);
}

class ParameterData {
  final String name;

  final Map<Locale, String>? localizedNames;

  final Type type;

  final bool isOptional;

  final String? description;

  final Map<Locale, String>? localizedDescriptions;

  final dynamic defaultValue;

  final Map<String, dynamic>? choices;

  final Converter<dynamic>? converterOverride;

  final FutureOr<Iterable<ArgChoiceBuilder>?> Function(AutocompleteContext)? autocompleteOverride;

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
