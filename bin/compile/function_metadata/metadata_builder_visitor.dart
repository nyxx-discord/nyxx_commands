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

import '../element_tree_visitor.dart';

/// An AST visitor that collects all instances of [id] invocations.
class FunctionBuilderVisitor extends EntireAstVisitor {
  final List<InvocationExpression> ids = [];

  FunctionBuilderVisitor(super.context, super.slow);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    Expression function = node.function;

    if (function is Identifier &&
        function.staticElement?.location?.encoding == 'package:nyxx_commands/src/util/util.dart;package:nyxx_commands/src/util/util.dart;id') {
      ids.add(node);
    }
  }
}
