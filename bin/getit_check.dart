// Analyzer for cyclic dependencies introduced through getIt.
//
// Run from your project root:
//   dart run application_base:getit_check
//   dart run application_base:getit_check --verbose   # dump every registered
//                                                     # class and its edges
//
// Scans lib/, finds classes registered in DI through injectable annotations
// (@lazySingleton / @singleton / @injectable and the constructor forms
// @LazySingleton(as: X) / @Singleton(as: X) / @Injectable(as: X)), collects
// every getIt<T>() call inside them, builds a directed graph, then looks for
// cycles via Tarjan's SCC + DFS, and prints them with severity.
//
// EAGER edge — getIt<X>() in a field initializer or in the body / initializers
//               of a constructor. A cycle with at least one eager edge =
//               instant stack overflow when the first participant is created.
// LAZY  edge — getIt<X>() in the body of a method/getter/setter (also in
//               static field initializers, since they run on first access).
//               A cycle made only of lazy edges may still bite, but only if
//               the calls overlap in time.
//
// Current limitations:
// - getIt calls inside mixins are not attributed to the classes that include
//   them via `with` (can be added later).
// - The analysis is purely static and does not account for control flow
//   (if/?:): every reached getIt<T>() call is counted as a potential
//   dependency.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

// MARK: Const

const _libDir = 'lib';

const _shorthandAnnotations = {'lazySingleton', 'singleton', 'injectable'};
const _classAnnotations = {'LazySingleton', 'Singleton', 'Injectable'};

const _generatedSuffixes = [
  '.g.dart',
  '.gr.dart',
  '.gen.dart',
  '.config.dart',
  '.freezed.dart',
];

// Hard cap on simple cycles enumerated inside a single SCC. Dense SCCs in
// large graphs can have exponentially many cycles; after this many we stop
// and append a warning.
const _maxCyclesPerScc = 1000;

// MARK: Data

enum _EdgeKind { eager, lazy }

enum _Severity { high, low }

final class _Ref {
  _Ref({required this.target, required this.kind, required this.line});

  final String target;
  final _EdgeKind kind;
  final int line;
}

final class _ClassInfo {
  _ClassInfo({
    required this.className,
    required this.registeredAs,
    required this.filePath,
    required this.line,
  });

  final String className;
  final String registeredAs;
  final String filePath;
  final int line;
  final List<_Ref> refs = [];
}

// MARK: Base functions

Future<void> main(List<String> args) async {
  final verbose = args.contains('--verbose') || args.contains('-v');

  final libDir = Directory(_libDir);
  if (!libDir.existsSync()) {
    stderr.writeln(
      'Error: directory "$_libDir" not found. '
      'Run from the project root.',
    );
    exit(2);
  }

  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where(_isAnalyzable)
      .toList();

  stdout.writeln('Scanning ${files.length} .dart files in $_libDir/ ...');

  final classes = <_ClassInfo>[];
  var parseErrors = 0;
  for (final file in files) {
    try {
      classes.addAll(_analyzeFile(file));
    } catch (e) {
      parseErrors++;
      stderr.writeln('Skipped ${file.path}: $e');
    }
  }
  if (parseErrors > 0) {
    stdout.writeln('Files skipped due to parse errors: $parseErrors');
  }

  final registry = <String, _ClassInfo>{};
  final duplicates = <String, List<_ClassInfo>>{};
  for (final cls in classes) {
    final prev = registry[cls.registeredAs];
    if (prev == null) {
      registry[cls.registeredAs] = cls;
    } else {
      duplicates.putIfAbsent(cls.registeredAs, () => [prev]).add(cls);
    }
  }

  // Graph: registeredAs -> { target: edgeKind }.
  // If both eager and lazy edges exist between the same pair, eager wins
  // (it represents the worst case for cycle severity).
  final graph = <String, Map<String, _EdgeKind>>{};
  for (final cls in classes) {
    final adj = graph.putIfAbsent(cls.registeredAs, () => {});
    for (final ref in cls.refs) {
      if (!registry.containsKey(ref.target)) continue;
      final prev = adj[ref.target];
      if (prev == null ||
          (prev == _EdgeKind.lazy && ref.kind == _EdgeKind.eager)) {
        adj[ref.target] = ref.kind;
      }
    }
  }

  final sccs = _tarjanScc(graph);
  final cycles = <List<String>>[];
  var truncatedSccs = 0;
  for (final scc in sccs) {
    if (scc.length == 1) {
      if ((graph[scc.first] ?? const {}).containsKey(scc.first)) {
        cycles.add([scc.first, scc.first]);
      }
      continue;
    }
    final found = _findAllSimpleCyclesInScc(scc, graph);
    cycles.addAll(found.cycles);
    if (found.truncated) truncatedSccs++;
  }

  final totalRefs = classes.fold<int>(0, (a, c) => a + c.refs.length);
  stdout
    ..writeln('Registered classes: ${registry.length}')
    ..writeln('Counted getIt<T>() references inside them: $totalRefs');

  if (verbose) _dumpGraph(registry, graph);

  if (duplicates.isNotEmpty) {
    stdout.writeln(
      '\n[!] Multiple classes claim the same getIt name:',
    );
    duplicates.forEach((name, list) {
      stdout.writeln('  $name:');
      for (final c in list) {
        stdout.writeln('    - ${c.className}  (${c.filePath}:${c.line})');
      }
    });
  }

  if (cycles.isEmpty) {
    stdout.writeln('\nOK — no cyclic dependencies detected.');
    exit(0);
  }

  cycles.sort((a, b) {
    final sa = _severity(a, graph);
    final sb = _severity(b, graph);
    if (sa != sb) return sa == _Severity.high ? -1 : 1;
    return a.length.compareTo(b.length);
  });

  stdout.writeln('\nCycles found: ${cycles.length}');
  if (truncatedSccs > 0) {
    stdout.writeln(
      '[!] $truncatedSccs SCC(s) reached the $_maxCyclesPerScc cycles cap '
      '— output is truncated, fix the ones above first and re-run.',
    );
  }
  for (var i = 0; i < cycles.length; i++) {
    _printCycle(i + 1, cycles[i], graph, registry);
  }
  exit(1);
}

// MARK: Functions

bool _isAnalyzable(File f) {
  final path = f.path;
  if (!path.endsWith('.dart')) return false;
  for (final suffix in _generatedSuffixes) {
    if (path.endsWith(suffix)) return false;
  }
  return true;
}

Iterable<_ClassInfo> _analyzeFile(File file) {
  final content = file.readAsStringSync();
  final result = parseString(
    content: content,
    path: file.path,
    throwIfDiagnostics: false,
  );
  final visitor = _Collector(file.path, result.lineInfo);
  result.unit.accept(visitor);
  return visitor.classes;
}

String? _detectRegistration(ClassDeclaration node) {
  final className = node.name.lexeme;
  for (final annotation in node.metadata) {
    final fullName = annotation.name.name;
    final aName = fullName.contains('.') ? fullName.split('.').last : fullName;

    // @lazySingleton, @singleton, @injectable — no parentheses.
    if (_shorthandAnnotations.contains(aName) && annotation.arguments == null) {
      return className;
    }

    // @LazySingleton(...), @Singleton(...), @Injectable(...).
    if (_classAnnotations.contains(aName)) {
      final args = annotation.arguments;
      if (args != null) {
        for (final arg in args.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'as') {
            return _baseTypeName(arg.expression.toSource());
          }
        }
      }
      return className;
    }
  }
  return null;
}

String _baseTypeName(String source) {
  var s = source.split('<').first.trim();
  if (s.contains('.')) s = s.split('.').last;
  return s;
}

// Tarjan's strongly connected components.
List<List<String>> _tarjanScc(Map<String, Map<String, _EdgeKind>> graph) {
  final indices = <String, int>{};
  final lowlinks = <String, int>{};
  final onStack = <String>{};
  final stack = <String>[];
  final out = <List<String>>[];
  var index = 0;

  void strongConnect(String v) {
    indices[v] = index;
    lowlinks[v] = index;
    index++;
    stack.add(v);
    onStack.add(v);

    final adj = graph[v];
    if (adj != null) {
      for (final w in adj.keys) {
        if (!indices.containsKey(w)) {
          strongConnect(w);
          if (lowlinks[w]! < lowlinks[v]!) lowlinks[v] = lowlinks[w]!;
        } else if (onStack.contains(w)) {
          if (indices[w]! < lowlinks[v]!) lowlinks[v] = indices[w]!;
        }
      }
    }

    if (lowlinks[v] == indices[v]) {
      final scc = <String>[];
      String w;
      do {
        w = stack.removeLast();
        onStack.remove(w);
        scc.add(w);
      } while (w != v);
      out.add(scc);
    }
  }

  for (final v in graph.keys) {
    if (!indices.containsKey(v)) strongConnect(v);
  }
  return out;
}

final class _SccCyclesResult {
  _SccCyclesResult({required this.cycles, required this.truncated});

  final List<List<String>> cycles;
  final bool truncated;
}

// Enumerates all elementary (simple) cycles inside one strongly connected
// component. For each chosen `start`, DFS only descends through nodes whose
// name is lexicographically >= start; this guarantees every cycle is reported
// exactly once (with its lex-smallest node as the entry point) — the same
// uniqueness trick Johnson's algorithm uses.
//
// To stay safe on dense SCCs, the search aborts at [_maxCyclesPerScc] cycles.
_SccCyclesResult _findAllSimpleCyclesInScc(
  List<String> scc,
  Map<String, Map<String, _EdgeKind>> graph,
) {
  final cycles = <List<String>>[];
  final set = scc.toSet();
  final sorted = [...scc]..sort();
  var truncated = false;

  for (final start in sorted) {
    if (truncated) break;
    final path = <String>[start];
    final inPath = <String>{start};

    bool dfs(String node) {
      final adj = graph[node];
      if (adj == null) return false;
      for (final next in adj.keys) {
        if (!set.contains(next)) continue;
        if (next == start) {
          cycles.add([...path, start]);
          if (cycles.length >= _maxCyclesPerScc) {
            truncated = true;
            return true;
          }
          continue;
        }
        if (next.compareTo(start) < 0) continue;
        if (inPath.contains(next)) continue;
        path.add(next);
        inPath.add(next);
        if (dfs(next)) return true;
        path.removeLast();
        inPath.remove(next);
      }
      return false;
    }

    dfs(start);
  }

  return _SccCyclesResult(cycles: cycles, truncated: truncated);
}

_Severity _severity(
  List<String> cycle,
  Map<String, Map<String, _EdgeKind>> graph,
) {
  for (var i = 0; i < cycle.length - 1; i++) {
    if (graph[cycle[i]]?[cycle[i + 1]] == _EdgeKind.eager) {
      return _Severity.high;
    }
  }
  return _Severity.low;
}

void _printCycle(
  int idx,
  List<String> cycle,
  Map<String, Map<String, _EdgeKind>> graph,
  Map<String, _ClassInfo> registry,
) {
  final sev = _severity(cycle, graph);
  final tag = sev == _Severity.high ? '[!] HIGH' : '[ ] LOW ';
  stdout.writeln('\n$tag  Cycle #$idx (length ${cycle.length - 1}):');
  for (var i = 0; i < cycle.length - 1; i++) {
    final from = cycle[i];
    final to = cycle[i + 1];
    final kind = graph[from]?[to];
    final arrow = kind == _EdgeKind.eager ? '=eager=>' : '-lazy->';
    final cls = registry[from];
    final loc = cls != null ? '  (${cls.filePath}:${cls.line})' : '';
    stdout
      ..writeln('    $from$loc')
      ..writeln('      $arrow $to');
  }
}

void _dumpGraph(
  Map<String, _ClassInfo> registry,
  Map<String, Map<String, _EdgeKind>> graph,
) {
  final names = registry.keys.toList()..sort();
  stdout.writeln('\n--- Registered classes (verbose) ---');
  for (final name in names) {
    final cls = registry[name]!;
    final adj = graph[name] ?? const <String, _EdgeKind>{};
    final tag = cls.className == name ? '' : '  [as $name]';
    stdout.writeln('${cls.className}$tag  (${cls.filePath}:${cls.line})');
    if (adj.isEmpty) {
      stdout.writeln('    (no registered dependencies)');
      continue;
    }
    final targets = adj.keys.toList()..sort();
    for (final t in targets) {
      final kind = adj[t] == _EdgeKind.eager ? 'eager' : 'lazy ';
      stdout.writeln('    $kind -> $t');
    }
  }
  stdout.writeln('--- end verbose ---');
}

// MARK: Visitor

class _Collector extends RecursiveAstVisitor<void> {
  _Collector(this.filePath, this.lineInfo);

  final String filePath;
  final LineInfo lineInfo;
  final classes = <_ClassInfo>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final registered = _detectRegistration(node);
    if (registered == null) return;

    final info = _ClassInfo(
      className: node.name.lexeme,
      registeredAs: registered,
      filePath: filePath,
      // Use the name token offset so the reported line points at the class
      // identifier itself, not at the start of the leading doc comment.
      line: lineInfo.getLocation(node.name.offset).lineNumber,
    );

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        // Static fields are lazy: their initializers run on first access,
        // not during construction of a class instance.
        final kind = member.isStatic ? _EdgeKind.lazy : _EdgeKind.eager;
        final v = _GetItVisitor(kind, lineInfo);
        member.fields.accept(v);
        info.refs.addAll(v.refs);
      } else if (member is ConstructorDeclaration) {
        final v = _GetItVisitor(_EdgeKind.eager, lineInfo);
        member.body.accept(v);
        for (final init in member.initializers) {
          init.accept(v);
        }
        info.refs.addAll(v.refs);
      } else if (member is MethodDeclaration) {
        final v = _GetItVisitor(_EdgeKind.lazy, lineInfo);
        member.body.accept(v);
        info.refs.addAll(v.refs);
      }
    }

    classes.add(info);
  }
}

class _GetItVisitor extends RecursiveAstVisitor<void> {
  _GetItVisitor(this.kind, this.lineInfo);

  final _EdgeKind kind;
  final LineInfo lineInfo;
  final refs = <_Ref>[];

  void _capture(TypeArgumentList? typeArgs, int offset) {
    if (typeArgs == null || typeArgs.arguments.isEmpty) return;
    final first = typeArgs.arguments.first;
    String name;
    if (first is NamedType) {
      name = first.name.lexeme;
    } else {
      name = _baseTypeName(first.toSource());
    }
    if (name.isEmpty) return;
    refs.add(
      _Ref(
        target: name,
        kind: kind,
        line: lineInfo.getLocation(offset).lineNumber,
      ),
    );
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'getIt' && node.target == null) {
      _capture(node.typeArguments, node.offset);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final func = node.function;
    if (func is SimpleIdentifier && func.name == 'getIt') {
      _capture(node.typeArguments, node.offset);
    }
    super.visitFunctionExpressionInvocation(node);
  }
}
