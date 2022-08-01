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

import '../generator.dart';
import '../type_tree/tree_builder.dart';
import 'compile_time_function_data.dart';

/// Convert [idCreations] into function metadata.
Iterable<CompileTimeFunctionData> getFunctionData(
  Iterable<InvocationExpression> ids,
) {
  List<CompileTimeFunctionData> result = [];

  outerLoop:
  for (final id in ids) {
    if (id.argumentList.arguments.length != 2) {
      logger.shout(
          'Unexpected number of arguments ${id.argumentList.arguments.length} in id invocation');
      continue;
    }

    if (id.argumentList.arguments[1] is! FunctionExpression) {
      throw CommandsError('Functions passed to the `id` function must be function literals');
    }

    FormalParameterList parameterList =
        (id.argumentList.arguments[1] as FunctionExpression).parameters!;

    List<CompileTimeParameterData> parameterData = [
      // The context parameter
      CompileTimeParameterData(
        parameterList.parameterElements.first!.name,
        parameterList.parameterElements.first!.type,
        false,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      )
    ];

    for (final parameter in parameterList.parameters.skip(1)) {
      if (parameter.identifier == null) {
        // Parameters must have a name to be used. Skip this function.
        continue outerLoop;
      }

      /// Extracts all the annotations on a parameter that have a type with the type id [type].
      Iterable<Annotation> annotationsWithType(int type) {
        Iterable<Annotation> constructorAnnotations = parameter.metadata
            .where((node) => node.elementAnnotation?.element is ConstructorElement)
            .where((node) =>
                getId((node.elementAnnotation!.element as ConstructorElement)
                    .enclosingElement
                    .thisType) ==
                type);

        Iterable<Annotation> constVariableAnnotations = parameter.metadata
            .where((node) => (node.elementAnnotation?.element is ConstVariableElement))
            .where((node) =>
                getId((node.elementAnnotation!.element as ConstVariableElement)
                    .evaluationResult!
                    .value!
                    .type) ==
                type);

        return constructorAnnotations.followedBy(constVariableAnnotations);
      }

      Iterable<Annotation> nameAnnotations = annotationsWithType(nameId);

      Iterable<Annotation> descriptionAnnotations = annotationsWithType(descriptionId);

      Iterable<Annotation> choicesAnnotations = annotationsWithType(choicesId);

      Iterable<Annotation> useConverterAnnotations = annotationsWithType(useConverterId);

      Iterable<Annotation> autocompleteAnnotations = annotationsWithType(autocompleteId);

      if ([
        nameAnnotations,
        descriptionAnnotations,
        choicesAnnotations,
        useConverterAnnotations,
        autocompleteAnnotations,
      ].any((annotations) => annotations.length > 1)) {
        throw CommandsError(
          'Cannot have more than 1 of each of @Name, @Description, @Choices,'
          ' @UseConverter or @Autocomplete per parameter',
        );
      }

      String name;
      Expression? localizedNames;
      String? description;
      Expression? localizedDescriptions;
      Expression? choices;
      Expression? defaultValue;
      Annotation? converterOverride;
      Annotation? autocompleteOverride;

      if (nameAnnotations.isNotEmpty) {
        name = getAnnotationData(nameAnnotations.first.elementAnnotation!)
            .getField('name')!
            .toStringValue()!;

        final nameArgs = nameAnnotations.first.arguments?.arguments;
        if (nameArgs?.length == 2) {
          localizedNames = nameArgs?.last;
        }
      } else {
        name = parameter.identifier!.name;
      }

      if (descriptionAnnotations.isNotEmpty) {
        description = getAnnotationData(descriptionAnnotations.first.elementAnnotation!)
            .getField('value')!
            .toStringValue()!;

        final descArgs = descriptionAnnotations.first.arguments?.arguments;
        if (descArgs?.length == 2) {
          localizedDescriptions = descArgs?.last;
        }
      }

      if (choicesAnnotations.isNotEmpty) {
        choices = choicesAnnotations.first.arguments!.arguments.first;
      }

      if (parameter is DefaultFormalParameter) {
        defaultValue = parameter.defaultValue;
      }

      if (useConverterAnnotations.isNotEmpty) {
        converterOverride = useConverterAnnotations.first;
      }

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
        localizedDescriptions,
        localizedNames,
      ));
    }

    result.add(CompileTimeFunctionData(id.argumentList.arguments.first, parameterData));
  }

  return result;
}

/// Extract the object referenced or creatted by an annotation.
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
