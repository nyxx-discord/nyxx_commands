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

import 'dart:async';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:nyxx_commands/src/errors.dart';

import 'generator.dart';

/// An AST visitor that checks every file in the entire program, following imports, exports and part
/// directives. Files that are deemed "interesting" are visited in full by this visitor.
///
/// Files are deemed "interesting" if:
/// - The file is part of `package:nyxx_commands`
/// - The file imports an "interesting" file
class EntireAstVisitor extends RecursiveAstVisitor<void> {
  static final Map<String, SomeResolvedUnitResult> _cache = {};
  final List<String> _interestingSources = [];

  final AnalysisContext context;
  final bool slow;

  EntireAstVisitor(this.context, this.slow);

  /// Makes this visitor check all the imported, exported or "part-ed" files in [element], visiting
  /// ones that are deemed "interesting".
  Future<void> visitLibrary(LibraryElement element) async {
    List<String> visited = [];

    void recursivelyGatherSources(LibraryElement element) {
      String source = element.source.fullName;

      logger.finest('Checking source "$source"');

      if (visited.contains(source)) {
        return;
      }

      visited.add(source);

      if (isLibraryInteresting(element)) {
        _interestingSources.add(source);
      }

      for (final library in [...element.importedLibraries, ...element.exportedLibraries]) {
        recursivelyGatherSources(library);
      }
    }

    recursivelyGatherSources(element);

    while (_interestingSources.isNotEmpty) {
      List<String> interestingSources = _interestingSources.sublist(0);
      _interestingSources.clear();

      logger.fine('Visiting interesting sources $interestingSources');

      await Future.wait(interestingSources.map(visitUnit));
    }
  }

  final List<LibraryElement> _checkingLibraries = [];
  static final Map<LibraryElement, bool> _interestingCache = {};

  /// Returns whether a given library is "interesting"
  bool isLibraryInteresting(LibraryElement element) {
    if (slow) {
      return true;
    }

    if (_interestingCache.containsKey(element)) {
      return _interestingCache[element]!;
    }

    if (_checkingLibraries.contains(element)) {
      return false;
    }

    bool ret;

    _checkingLibraries.add(element);

    if (element.identifier.startsWith('package:nyxx_commands')) {
      ret = true;
    } else {
      ret = element.importedLibraries.any((library) => isLibraryInteresting(library)) ||
          element.exportedLibraries.any((library) => isLibraryInteresting(library));
    }

    _checkingLibraries.removeLast();

    return _interestingCache[element] = ret;
  }

  /// Makes this visitor get the full AST for a given source and visit it.
  Future<void> visitUnit(String source) async {
    logger.finer('Getting AST for source "$source"');

    SomeResolvedUnitResult result =
        _cache[source] ??= await context.currentSession.getResolvedUnit(source);

    if (result is! ResolvedUnitResult) {
      throw CommandsError('Got invalid analysis result for source $source');
    }

    logger.finer('Got AST for source "$source"');

    result.unit.accept(this);
  }

  @override
  void visitPartDirective(PartDirective directive) {
    super.visitPartDirective(directive);

    // Visit "part-ed" files of interesting sources
    _interestingSources.add(directive.uri.stringValue!);
  }
}
