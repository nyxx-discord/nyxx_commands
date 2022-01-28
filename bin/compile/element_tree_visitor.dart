import 'dart:async';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'generator.dart';

class EntireAstVisitor extends RecursiveAstVisitor<void> {
  static final Map<String, SomeResolvedUnitResult> _cache = {};

  final AnalysisContext context;

  final List<String> visited = [];

  EntireAstVisitor(this.context) {
    // [_processing] can sometimes reach 0 in between processing cached units, so we instead only
    // check periodically whether we are done.
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_processing == 0) {
        logger.finer('#processing hit 0, completing visitor');
        _completer.complete();
        timer.cancel();
      }
    });
  }

  final Completer<void> _completer = Completer();
  late final Future<void> completed = _completer.future;

  int _processing = 0;

  void visitUriBasedDirective(UriBasedDirective directive) async {
    String source = directive.uriSource!.fullName;

    if (visited.contains(source)) {
      logger.finest('Not visiting source $source as it has already been visited');
      return;
    }

    _processing++;

    visited.add(source);

    logger.finer('Getting AST for source $source');

    SomeResolvedUnitResult result =
        (_cache[source] ??= await context.currentSession.getResolvedUnit(source));

    if (result is! ResolvedUnitResult) {
      logger.warning('Got invalid analysis result for source $source');
      _processing--;
      return;
    }

    result.unit.accept(this);

    logger.finest('Finished visiting source $source');

    _processing--;
  }

  @override
  void visitImportDirective(ImportDirective directive) {
    super.visitImportDirective(directive);

    logger.finer('Found import directive $directive in ${directive.element?.source.uri}');

    visitUriBasedDirective(directive);
  }

  @override
  void visitExportDirective(ExportDirective directive) {
    super.visitExportDirective(directive);

    logger.finer('Found export directive $directive in ${directive.element?.source.uri}');

    visitUriBasedDirective(directive);
  }

  @override
  void visitPartDirective(PartDirective directive) {
    super.visitPartDirective(directive);

    logger.finer('Found part directive $directive in ${directive.element?.source?.uri}');

    visitUriBasedDirective(directive);
  }
}
