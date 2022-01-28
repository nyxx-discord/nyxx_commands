import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

import '../element_tree_visitor.dart';
import '../generator.dart';

class TypeBuilderVisitor extends EntireAstVisitor {
  final List<DartType> types = [];

  TypeBuilderVisitor(AnalysisContext context) : super(context);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    types.add(node.declaredElement!.thisType);

    logger.finest('Found class delcaration ${node.name}');

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
}
