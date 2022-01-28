import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../element_tree_visitor.dart';
import '../generator.dart';

class FunctionBuilderVisitor extends EntireAstVisitor {
  final List<FormalParameterList> parameterLists = [];

  FunctionBuilderVisitor(AnalysisContext context) : super(context);

  @override
  void visitFormalParameterList(FormalParameterList node) {
    parameterLists.add(node);

    logger.finest('Found parameter list $node');

    super.visitFormalParameterList(node);
  }
}
