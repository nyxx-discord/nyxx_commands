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

import '../element_tree_visitor.dart';
import '../generator.dart';
import '../type_tree/tree_builder.dart';

class FunctionBuilderVisitor extends EntireAstVisitor {
  final List<InstanceCreationExpression> idCreations = [];

  FunctionBuilderVisitor(AnalysisContext context) : super(context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression expression) {
    if (getId(expression.constructorName.type.type!) == idId) {
      idCreations.add(expression);
    }

    logger.finest('Found ID creation $expression');

    super.visitInstanceCreationExpression(expression);
  }
}
