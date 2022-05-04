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
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../type_tree/tree_builder.dart';
import 'compile_time_function_data.dart';

Iterable<CompileTimeFunctionData> getFunctionData(
    Iterable<InstanceCreationExpression> idCreations) {
  List<CompileTimeFunctionData> result = [];

  outerLoop:
  for (final idCreation in idCreations) {
    FormalParameterList parameterList =
        (idCreation.argumentList.arguments[1] as FunctionExpression).parameters!;

    List<CompileTimeParameterData> parameterData = [
      CompileTimeParameterData(
        parameterList.parameterElements.first!.name,
        parameterList.parameterElements.first!.type,
        false,
        null,
        null,
        null,
        null,
        null,
      )
    ];

    for (final parameter in parameterList.parameters.skip(1)) {
      if (parameter.identifier == null) {
        // Parameters must have a name to be used
        continue outerLoop;
      }

      Iterable<Annotation> annotationsWithType(int type) => parameter.metadata.where((node) =>
          (node.elementAnnotation?.element is ConstructorElement &&
              getId((node.elementAnnotation!.element as ConstructorElement)
                      .enclosingElement
                      .thisType) ==
                  type) ||
          (node.elementAnnotation?.element is ConstVariableElement &&
              getId((node.elementAnnotation!.element as ConstVariableElement)
                      .evaluationResult!
                      .value!
                      .type) ==
                  type));

      Iterable<Annotation> nameAnnotations = annotationsWithType(nameId);

      Iterable<Annotation> descriptionAnnotations = annotationsWithType(descriptionId);

      Iterable<Annotation> choicesAnnotations = annotationsWithType(choicesId);

      Iterable<Annotation> useConverterAnnotations = annotationsWithType(useConverterId);

      Iterable<Annotation> autocompleteAnnotations = annotationsWithType(autocompleteId);

      if ([nameAnnotations, descriptionAnnotations, choicesAnnotations, useConverterAnnotations]
          .any((annotations) => annotations.length > 1)) {
        throw CommandsError(
            'Cannot have more than 1 of each of @Name, @Descriptionn, @Choices or @UseConverter per parameter');
      }

      String name;
      if (nameAnnotations.isNotEmpty) {
        name = getAnnotationData(nameAnnotations.first.elementAnnotation!)
            .getField('name')!
            .toStringValue()!;
      } else {
        name = parameter.identifier!.name;
      }

      String? description;
      if (descriptionAnnotations.isNotEmpty) {
        description = getAnnotationData(descriptionAnnotations.first.elementAnnotation!)
            .getField('value')!
            .toStringValue()!;
      }

      Expression? choices;
      if (choicesAnnotations.isNotEmpty) {
        choices = choicesAnnotations.first.arguments!.arguments.first;
      }

      // Get default value

      Expression? defaultValue;

      if (parameter is DefaultFormalParameter) {
        defaultValue = parameter.defaultValue;
      }

      // Get converter override

      Annotation? converterOverride;

      if (useConverterAnnotations.isNotEmpty) {
        converterOverride = useConverterAnnotations.first;
      }

      Annotation? autocompleteOverride;

      if (autocompleteAnnotations.isNotEmpty) {
        autocompleteOverride = autocompleteAnnotations.first;
      }

      parameterData.add(CompileTimeParameterData(
        name,
        parameter.declaredElement!.type,
        parameter.isOptional,
        description,
        defaultValue,
        choices,
        converterOverride,
        autocompleteOverride,
      ));
    }

    result.add(CompileTimeFunctionData(idCreation.argumentList.arguments.first, parameterData));
  }

  return result;
}

DartObject getAnnotationData(ElementAnnotation annotation) {
  DartObject? result;
  if (annotation.element is ConstructorElement) {
    result = annotation.computeConstantValue();
  } else if (annotation.element is ConstVariableElement) {
    result = (annotation.element as ConstVariableElement).computeConstantValue();
  }

  if (result == null) {
    throw CommandsError('Could not evaluate $annotation');
  }

  return result;
}