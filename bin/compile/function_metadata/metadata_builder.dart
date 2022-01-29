import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../type_tree/tree_builder.dart';
import '../type_tree/type_data.dart';
import '../type_tree/util.dart';
import 'compile_time_function_data.dart';

Iterable<CompileTimeFunctionData> getFunctionData(
    Iterable<FormalParameterList> functions, Map<int, TypeData> typeTree) {
  List<CompileTimeFunctionData> result = [];

  Iterable<FormalParameterList> contextFunctions = functions.where(
    (parameters) =>
        parameters.parameterElements.isNotEmpty &&
        (isAAssignableToB(
                iChatContextId, getId(parameters.parameterElements.first!.type), typeTree) ||
            isAAssignableToB(
                getId(parameters.parameterElements.first!.type), iChatContextId, typeTree)),
  );

  outerLoop:
  for (final parameterList in contextFunctions) {
    List<CompileTimeParameterData> parameterData = [
      CompileTimeParameterData(parameterList.parameterElements.first!.name,
          parameterList.parameterElements.first!.type, false, null, null, null, null)
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

      Map<String, dynamic>? choices;
      if (choicesAnnotations.isNotEmpty) {
        Map<String, DartObject> unresolvedChoices =
            getAnnotationData(choicesAnnotations.first.elementAnnotation!)
                .getField('choices')!
                .toMapValue()!
                .map((key, value) => MapEntry(key!.toStringValue()!, value!));

        choices = {};

        for (final key in unresolvedChoices.keys) {
          DartObject value = unresolvedChoices[key]!;

          dynamic resolved = value.toStringValue() ?? value.toIntValue();

          if (resolved == null) {
            throw CommandsError('Only `int` and `String` can be used as a value for choices.');
          }

          choices[key] = resolved;
        }
      }

      // Get default value

      dynamic defaultValue;

      if (parameter is DefaultFormalParameter) {
        if (parameter.defaultValue == null) {
          defaultValue = null;
        } else if (parameter.defaultValue is StringLiteral) {
          defaultValue = (parameter.defaultValue as StringLiteral).stringValue;
        } else if (parameter.defaultValue is IntegerLiteral) {
          defaultValue = (parameter.defaultValue as IntegerLiteral).value;
        } else if (parameter.defaultValue is BooleanLiteral) {
          defaultValue = (parameter.defaultValue as BooleanLiteral).value;
        } else if (parameter.defaultValue is SimpleIdentifier) {
          Element staticElement = (parameter.defaultValue as SimpleIdentifier).staticElement!;

          if (staticElement is PropertyAccessorElement) {
            defaultValue = (staticElement.variable as ConstVariableElement).evaluationResult!.value;
          } else {
            throw CommandsError('Unhandled default expression type ${staticElement.runtimeType}');
          }
        } else {
          throw CommandsError('Unhandled default type ${parameter.defaultValue.runtimeType}');
        }
      }

      // Get converter override

      Annotation? converterOverride;

      if (useConverterAnnotations.isNotEmpty) {
        converterOverride = useConverterAnnotations.first;
      }

      parameterData.add(CompileTimeParameterData(
        name,
        parameter.declaredElement!.type,
        parameter.isOptional,
        description,
        defaultValue,
        choices,
        converterOverride,
      ));
    }

    result.add(CompileTimeFunctionData(parameterData));
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
