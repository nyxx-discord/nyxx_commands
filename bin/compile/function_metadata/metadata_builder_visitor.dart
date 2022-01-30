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
    if (getId(expression.constructorName.type2.type!) == idId) {
      idCreations.add(expression);
    }

    logger.finest('Found ID creation $expression');

    super.visitInstanceCreationExpression(expression);
  }
}
