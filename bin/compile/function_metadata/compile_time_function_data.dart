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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

/// Metadata about a function.
class CompileTimeFunctionData {
  /// The id that was associated with this function in the [id] invocation.
  final Expression id;

  /// The parameter data for this function.
  final List<CompileTimeParameterData> parametersData;

  const CompileTimeFunctionData(this.id, this.parametersData);

  @override
  String toString() => 'CompileTimeFunctionData[id=$id, parameters=$parametersData]';
}

/// Metadata about a function parameter.
class CompileTimeParameterData {
  /// The name of this parameter.
  final String name;

  /// The type of this parameter.
  final DartType type;

  /// Whether this parameter is optional.
  final bool isOptional;

  // We don't care about named parameters because they aren't allowed in command callbacks.

  /// The description of this parameter.
  final String? description;

  /// The localized descriptions of this parameter.
  final Expression? localizedDescriptions;

  /// The default value of this parameter.
  final Expression? defaultValue;

  /// The choices for this parameter.
  final Expression? choices;

  /// The converter override for this parameter.
  final Annotation? converterOverride;

  /// The autocompletion handler override for this parameter.
  final Annotation? autocompleteOverride;

  const CompileTimeParameterData(
    this.name,
    this.type,
    this.isOptional,
    this.description,
    this.defaultValue,
    this.choices,
    this.converterOverride,
    this.autocompleteOverride,
    this.localizedDescriptions,
  );

  @override
  String toString() => 'CompileTimeParameterData[name=$name, '
      'type=${type.getDisplayString(withNullability: true)}, '
      'isOptional=$isOptional, '
      'description=$description, '
      'defaultValue=$defaultValue, '
      'choices=$choices, '
      'converterOverride=$converterOverride, '
      'autocompleteOverride=$autocompleteOverride, '
      'localizedDescriptions=$localizedDescriptions]';
}
