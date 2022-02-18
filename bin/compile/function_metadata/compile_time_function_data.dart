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

class CompileTimeFunctionData {
  final Expression id;

  final List<CompileTimeParameterData> parametersData;

  const CompileTimeFunctionData(this.id, this.parametersData);

  @override
  String toString() => 'CompileTimeFunctionData[id=$id, parameters=$parametersData]';
}

class CompileTimeParameterData {
  final String name;

  final DartType type;

  final bool isOptional;

  final String? description;

  final Expression? defaultValue;

  final Expression? choices;

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

  @override
  String toString() => 'CompileTimeParameterData[name=$name, '
      'type=${type.getDisplayString(withNullability: true)}, '
      'isOptional=$isOptional, '
      'description=$description, '
      'defaultValue=$defaultValue, '
      'choices=$choices, '
      'converterOverride=$converterOverride]';
}
