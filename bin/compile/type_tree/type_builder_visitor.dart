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

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../element_tree_visitor.dart';
import '../generator.dart';

/// An AST visitor that collects all the types referenced in an entire program.
class TypeBuilderVisitor extends EntireAstVisitor {
  final List<DartType> types = [];

  TypeBuilderVisitor(AnalysisContext context, bool slow) : super(context, slow);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    types.add(node.declaredElement!.thisType);

    logger.finest('Found class declaration ${node.name}');

    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    types.add(node.declaredElement!.thisType);

    logger.finest('Found mixin declaration ${node.name}');

    super.visitMixinDeclaration(node);
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    for (final parameter in node.parameterElements) {
      types.add(parameter!.type);

      logger.finest('Found parameter type ${parameter.type}');
    }

    super.visitFormalParameterList(node);
  }

  @override
  void visitTypeLiteral(TypeLiteral node) {
    types.add(node.type.type!);

    logger.finest('Found type literal $node');

    super.visitTypeLiteral(node);
  }

  @override
  void visitTypeArgumentList(TypeArgumentList node) {
    for (final argument in node.arguments) {
      types.add(argument.type!);

      logger.finest('Found type argument ${argument.type}');
    }

    super.visitTypeArgumentList(node);
  }
}
