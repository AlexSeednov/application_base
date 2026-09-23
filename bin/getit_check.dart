// Finds cyclic dependencies introduced through getIt.
//
// Run from the project root:
//   dart run application_base:getit_check
//   dart run application_base:getit_check --verbose   # every registered
//                                                     # class and its edges
//   dart run application_base:getit_check --no-color  # no ANSI colors
//   dart run application_base:getit_check --ascii     # ASCII-only glyphs
//
// Scans lib/ for classes registered through injectable annotations
// (@lazySingleton / @singleton / @injectable and the constructor forms
// @LazySingleton(as: X) / @Singleton(as: X) / @Injectable(as: X)), turns
// every getIt<T>() call inside them into an edge of a directed graph, finds
// the cycles (Tarjan's SCC, then a DFS inside each component) and prints
// them by severity.
//
// EAGER edge — getIt<X>() in a field initializer or in the body /
//               initializers of a constructor. A cycle with at least one
//               eager edge overflows the stack as soon as its first
//               participant is created.
// LAZY  edge — getIt<X>() in the body of a method/getter/setter, or in a
//               static field initializer (it runs on first access). A cycle
//               of lazy edges only bites when the calls overlap in time.
//
// Limitations:
// - getIt calls inside mixins are not attributed to the classes that apply
//   them with `with`.
// - Only the call form getIt<T>() is seen: getIt.get<T>(), GetIt.I<T>() and
//   the like are not.
// - The analysis is static and ignores control flow (if / ?:): every
//   getIt<T>() call reached counts as a dependency.

import 'dart:io';
import 'dart:math' as math;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

// MARK: Const

/// Resolved against the working directory: the tool runs from the project
/// root.
const _libDir = 'lib';

/// The forms without arguments.
const _shorthandAnnotations = {'lazySingleton', 'singleton', 'injectable'};
/// The constructor forms, which may register the class under another type
/// with `as:`.
const _classAnnotations = {'LazySingleton', 'Singleton', 'Injectable'};

/// Skipped: generated code holds no annotated classes of its own.
const _generatedSuffixes = [
  '.g.dart',
  '.gr.dart',
  '.gen.dart',
  '.config.dart',
  '.freezed.dart',
];

/// Cap on the cycles listed per SCC: a dense one can hold exponentially many,
/// so the search stops here and the report says it is truncated.
const _maxCyclesPerScc = 1000;

/// A thin divider goes after every this many cycles of one severity, so a
/// long list stays easy to scan.
const _cycleGroupChunk = 5;

/// Visible width of the section headers and of the summary box.
const _bannerWidth = 64;

// MARK: Output styling

///
var _useColor = true;
/// Off with `--ascii`, for terminals without UTF-8.
var _useUnicode = true;

/// [code] is an SGR parameter list, such as `1;31` for bold red.
String _ansi(String text, String code) =>
    _useColor ? '\x1B[${code}m$text\x1B[0m' : text;

///
String _bold(String s) => _ansi(s, '1');
///
String _dim(String s) => _ansi(s, '2');
///
String _red(String s) => _ansi(s, '31');
///
String _yellow(String s) => _ansi(s, '33');
///
String _cyan(String s) => _ansi(s, '36');
///
String _boldRed(String s) => _ansi(s, '1;31');
///
String _boldYellow(String s) => _ansi(s, '1;33');
///
String _boldGreen(String s) => _ansi(s, '1;32');
///
String _boldCyan(String s) => _ansi(s, '1;36');

/// Each glyph has an ASCII fallback for `--ascii`.
String get _gArrowDown => _useUnicode ? '▼' : 'v';
///
String get _gBar => _useUnicode ? '│' : '|';
///
String get _gArrow => _useUnicode ? '→' : '->';
///
String get _gHintMark => _useUnicode ? '▸' : '>';
///
String get _gHLine => _useUnicode ? '─' : '-';
///
String get _gBoxTL => _useUnicode ? '┌' : '+';
///
String get _gBoxBL => _useUnicode ? '└' : '+';
///
String get _gHeavy => _useUnicode ? '═' : '=';
///
String get _gCheck => _useUnicode ? '✓' : 'OK';
///
String get _gLoop => _useUnicode ? '↺' : '<-';
///
String get _gWarn => _useUnicode ? '⚠' : '[!]';

// MARK: Data

/// When a getIt call runs; see the file header.
enum _EdgeKind { eager, lazy }

/// HIGH: the cycle has an eager edge. LOW: lazy edges only.
enum _Severity { high, low }

/// One `getIt<T>()` call inside a registered class.
final class _Ref {
  ///
  _Ref({required this.target, required this.kind, required this.line});

  /// The type argument of the call, the name it asks getIt for.
  final String target;
  ///
  final _EdgeKind kind;
  ///
  final int line;
}

/// A class registered in DI, with the getIt calls inside it.
final class _ClassInfo {
  ///
  _ClassInfo({
    required this.className,
    required this.registeredAs,
    required this.filePath,
    required this.line,
  });

  ///
  final String className;
  /// The `as:` type of the annotation, else the class itself: the name
  /// getIt knows it by and the node it becomes in the graph.
  final String registeredAs;
  ///
  final String filePath;
  ///
  final int line;
  ///
  final List<_Ref> refs = [];
}

// MARK: Base functions

/// Exits with 0 on a clean graph, 1 on any cycle and 2 without `lib/`, so a
/// CI step can gate on it.
void main(List<String> args) {
  final verbose = args.contains('--verbose') || args.contains('-v');
  _useColor =
      stdout.supportsAnsiEscapes &&
      !Platform.environment.containsKey('NO_COLOR') &&
      !args.contains('--no-color');
  _useUnicode = !args.contains('--ascii');

  final libDir = Directory(_libDir);
  if (!libDir.existsSync()) {
    stderr.writeln(
      _boldRed(
        'Error: directory "$_libDir" not found. Run from the project root.',
      ),
    );
    exit(2);
  }

  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where(_isAnalyzable)
      .toList();

  stdout.writeln(
    'Scanning ${_bold('${files.length}')} .dart files in '
    '${_cyan('$_libDir/')} ...',
  );

  final classes = <_ClassInfo>[];
  var parseErrors = 0;
  for (final file in files) {
    // One unreadable file must not hide the cycles in the rest: it is
    // counted and skipped.
    try {
      classes.addAll(_analyzeFile(file));
    } catch (e) {
      parseErrors++;
      stderr.writeln(_yellow('Skipped ${file.path}: $e'));
    }
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

  // registeredAs -> {target: edge kind}. Of an eager and a lazy edge between
  // the same pair, eager wins: severity goes by the worst case.
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
    // A single node is a cycle only through an edge to itself.
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

  // HIGH before LOW; within each, shorter cycles first.
  cycles.sort((a, b) {
    final sa = _severity(a, graph);
    final sb = _severity(b, graph);
    if (sa != sb) return sa == _Severity.high ? -1 : 1;
    return a.length.compareTo(b.length);
  });

  // How many cycles each class is in. toSet(): a cycle repeats its first
  // node at the end.
  final hotMap = <String, int>{};
  for (final cycle in cycles) {
    for (final node in cycle.toSet()) {
      hotMap[node] = (hotMap[node] ?? 0) + 1;
    }
  }

  final totalRefs = classes.fold<int>(0, (a, c) => a + c.refs.length);
  final highCycles = cycles
      .where((c) => _severity(c, graph) == _Severity.high)
      .toList();
  final lowCycles = cycles
      .where((c) => _severity(c, graph) == _Severity.low)
      .toList();

  if (verbose) _dumpGraph(registry, graph, hotMap);

  if (duplicates.isNotEmpty) _printDuplicates(duplicates);

  if (cycles.isNotEmpty) {
    if (truncatedSccs > 0) {
      stdout.writeln(
        '\n${_yellow(_gWarn)} ${_yellow('$truncatedSccs SCC(s) '
        'reached the $_maxCyclesPerScc cycles cap '
        '— output is truncated, fix the ones above first and re-run.')}',
      );
    }

    if (highCycles.isNotEmpty) {
      _printCycleGroup(highCycles, 1, _Severity.high, graph, registry, hotMap);
    }
    if (lowCycles.isNotEmpty) {
      _printCycleGroup(
        lowCycles,
        highCycles.length + 1,
        _Severity.low,
        graph,
        registry,
        hotMap,
      );
    }
  }

  _printSummary(
    filesScanned: files.length,
    parseErrors: parseErrors,
    registered: registry.length,
    references: totalRefs,
    duplicates: duplicates.length,
    highCount: highCycles.length,
    lowCount: lowCycles.length,
  );

  exit(cycles.isEmpty ? 0 : 1);
}

// MARK: Output helpers

///
void _printSectionHeader(String label, int count, _Severity sev) {
  final color = sev == _Severity.high ? _boldRed : _boldYellow;
  final word = count == 1 ? 'cycle' : 'cycles';
  final title = '$label severity — $count $word';
  // Measured before coloring: ANSI codes take no columns.
  final visibleTitleLen = title.length;
  const leftLen = 3;
  final rightLen = math.max(3, _bannerWidth - visibleTitleLen - 2 - leftLen);
  final left = _gHeavy * leftLen;
  final right = _gHeavy * rightLen;
  stdout
    ..writeln()
    ..writeln('${color(left)} ${color(title)} ${color(right)}')
    ..writeln();
}

/// [startIdx] carries the numbering on from the HIGH group to the LOW one.
void _printCycleGroup(
  List<List<String>> cycles,
  int startIdx,
  _Severity sev,
  Map<String, Map<String, _EdgeKind>> graph,
  Map<String, _ClassInfo> registry,
  Map<String, int> hotMap,
) {
  _printSectionHeader(
    sev == _Severity.high ? 'HIGH' : 'LOW',
    cycles.length,
    sev,
  );
  for (var i = 0; i < cycles.length; i++) {
    if (i > 0 && i % _cycleGroupChunk == 0) {
      stdout
        ..writeln('  ${_dim(_gHLine * (_bannerWidth - 4))}')
        ..writeln();
    }
    _printCycle(startIdx + i, cycles[i], graph, registry, hotMap, sev);
    stdout.writeln();
  }
}

///
void _printCycle(
  int idx,
  List<String> cycle,
  Map<String, Map<String, _EdgeKind>> graph,
  Map<String, _ClassInfo> registry,
  Map<String, int> hotMap,
  _Severity sev,
) {
  final length = cycle.length - 1;

  // The widest name with its hot tag, so the file locations line up.
  var maxNameLen = 0;
  for (var i = 0; i < length; i++) {
    final n = cycle[i];
    final hot = hotMap[n] ?? 0;
    final visible = hot >= 2 ? '$n [hot: $hot cycles]' : n;
    if (visible.length > maxNameLen) maxNameLen = visible.length;
  }

  stdout
    ..writeln('  ${_bold('Cycle #$idx')}  ${_dim('(length $length)')}')
    ..writeln();

  final seenInCycle = <String>{};
  for (var i = 0; i < length; i++) {
    final from = cycle[i];
    final to = cycle[i + 1];
    final kind = graph[from]?[to];
    final cls = registry[from];
    final loc = cls != null ? '${cls.filePath}:${cls.line}' : '';

    final hot = hotMap[from] ?? 0;
    final showHot = hot >= 2 && !seenInCycle.contains(from);
    seenInCycle.add(from);

    final visibleName = showHot ? '$from [hot: $hot cycles]' : from;
    final label = showHot
        ? '${_bold(from)} ${_dim('[hot: $hot cycles]')}'
        : _bold(from);
    final padding = ' ' * (maxNameLen - visibleName.length + 2);

    stdout.writeln('    $label$padding${_dim(loc)}');

    final isEager = kind == _EdgeKind.eager;
    final kindLabel = isEager ? _boldRed('eager') : _yellow('lazy');
    final coloredArrow = isEager ? _red(_gArrowDown) : _yellow(_gArrowDown);

    stdout
      ..writeln('      ${_dim(_gBar)} $kindLabel')
      ..writeln('      $coloredArrow');
  }

  // The closing node repeats cycle[0]: a marker instead of its location.
  final back = cycle.last;
  stdout
    ..writeln('    ${_bold(back)}  ${_dim('$_gLoop loops back')}')
    ..writeln();

  if (sev == _Severity.high) {
    stdout
      ..writeln(
        '    ${_cyan(_gHintMark)} ${_dim('Hint: '
        'break an eager edge — move the getIt<X>() call out of')}',
      )
      ..writeln(
        '      ${_dim('a field initializer / constructor '
        'body into a method body.')}',
      );
  } else {
    stdout
      ..writeln(
        '    ${_cyan(_gHintMark)} ${_dim('Hint: only lazy edges — '
        'safe at registration time, but verify')}',
      )
      ..writeln(
        '      ${_dim('these methods can\'t call each other '
        'on overlapping paths.')}',
      );
  }
}

/// The graph is keyed by the registered name, so only the first class of
/// each duplicated name takes part in the analysis.
void _printDuplicates(Map<String, List<_ClassInfo>> duplicates) {
  stdout
    ..writeln()
    ..writeln('${_yellow(_gWarn)} ${_boldYellow('Duplicate registrations:')}')
    ..writeln();
  duplicates.forEach((name, list) {
    stdout.writeln('  ${_bold(name)}');
    var maxLen = 0;
    for (final c in list) {
      if (c.className.length > maxLen) maxLen = c.className.length;
    }
    for (final c in list) {
      final padding = ' ' * (maxLen - c.className.length + 2);
      stdout.writeln(
        '    ${_bold(c.className)}$padding${_dim('${c.filePath}:${c.line}')}',
      );
    }
  });
}

///
void _printSummary({
  required int filesScanned,
  required int parseErrors,
  required int registered,
  required int references,
  required int duplicates,
  required int highCount,
  required int lowCount,
}) {
  final cyclesTotal = highCount + lowCount;
  final cyclesNote = cyclesTotal == 0
      ? '${_boldGreen(_gCheck)} ${_boldGreen('clean')}'
      : '${_dim('(')}${_boldRed('$highCount HIGH')}${_dim(', ')}'
            '${_boldYellow('$lowCount LOW')}${_dim(')')}';

  final entries = <List<String>>[
    ['Files scanned', '$filesScanned'],
    if (parseErrors > 0) ['Parse errors', _yellow('$parseErrors')],
    ['Registered classes', '$registered'],
    ['getIt<T> references', '$references'],
    ['Cycles', '$cyclesTotal   $cyclesNote'],
    if (duplicates == 0)
      ['Duplicates', '0']
    else
      ['Duplicates', _yellow('$duplicates')],
  ];

  // Fits the longest label, `getIt<T> references`, with room to spare.
  const labelWidth = 22;
  const titleText = ' Summary ';
  const innerWidth = _bannerWidth - 2;
  final topRight = _gHLine * (innerWidth - titleText.length - 2);
  final top = _boldCyan('$_gBoxTL${_gHLine * 2}$titleText$topRight');
  final bot = _boldCyan('$_gBoxBL${_gHLine * innerWidth}');

  stdout
    ..writeln()
    ..writeln(top);
  for (final entry in entries) {
    final label = entry[0].padRight(labelWidth);
    stdout.writeln('${_boldCyan(_gBar)}  $label ${_bold(entry[1])}');
  }
  stdout.writeln(bot);

  if (cyclesTotal == 0) {
    stdout
      ..writeln()
      ..writeln(_boldGreen('$_gCheck OK — no cyclic dependencies detected.'));
  }
}

// MARK: Functions

///
bool _isAnalyzable(File f) {
  final path = f.path;
  if (!path.endsWith('.dart')) return false;
  for (final suffix in _generatedSuffixes) {
    if (path.endsWith(suffix)) return false;
  }
  return true;
}

/// Parses without resolving: fast, needs no package config and survives
/// syntax errors — but every type is known by its name only.
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

/// The name [node] is registered under, or null without a registration
/// annotation. Annotations match by name, an import prefix dropped.
String? _detectRegistration(ClassDeclaration node) {
  final className = node.namePart.typeName.lexeme;
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
          if (arg is NamedArgument && arg.name.lexeme == 'as') {
            return _baseTypeName(arg.argumentExpression.toSource());
          }
        }
      }
      return className;
    }
  }
  return null;
}

/// Strips type arguments and an import prefix: `p.Foo<Bar>` becomes `Foo`.
String _baseTypeName(String source) {
  var s = source.split('<').first.trim();
  if (s.contains('.')) s = s.split('.').last;
  return s;
}

/// Tarjan's strongly connected components of [graph].
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

///
final class _SccCyclesResult {
  ///
  _SccCyclesResult({required this.cycles, required this.truncated});

  ///
  final List<List<String>> cycles;
  /// Whether the search stopped at [_maxCyclesPerScc].
  final bool truncated;
}

/// Every elementary cycle inside one strongly connected component, each with
/// its first node repeated at the end.
///
/// From each `start` the DFS descends only through names that sort at or
/// after it, so every cycle is found exactly once, entered at its smallest
/// node — the uniqueness trick of Johnson's algorithm. The search stops at
/// [_maxCyclesPerScc] cycles to stay safe on dense components.
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

///
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

/// The `--verbose` listing: every registered class with its edges.
void _dumpGraph(
  Map<String, _ClassInfo> registry,
  Map<String, Map<String, _EdgeKind>> graph,
  Map<String, int> hotMap,
) {
  final names = registry.keys.toList()..sort();

  // The widest class label, so the file locations line up.
  var maxClassLen = 0;
  for (final name in names) {
    final cls = registry[name]!;
    final asTag = cls.className == name ? '' : ' [as $name]';
    final hot = hotMap[name] ?? 0;
    final hotTag = hot >= 2 ? ' [hot: $hot cycles]' : '';
    final visible = '${cls.className}$asTag$hotTag';
    if (visible.length > maxClassLen) maxClassLen = visible.length;
  }

  // The 33 below is the width of the left rule and the title together.
  stdout
    ..writeln()
    ..writeln(
      _boldCyan(
        '${_gHLine * 3} Registered classes (verbose) '
        '${_gHLine * math.max(3, _bannerWidth - 33)}',
      ),
    )
    ..writeln();

  for (final name in names) {
    final cls = registry[name]!;
    final adj = graph[name] ?? const <String, _EdgeKind>{};
    final asTag = cls.className == name ? '' : ' [as $name]';
    final hot = hotMap[name] ?? 0;
    final hotTag = hot >= 2 ? ' [hot: $hot cycles]' : '';
    final visible = '${cls.className}$asTag$hotTag';
    final padding = ' ' * (maxClassLen - visible.length + 2);

    final renderedClass =
        _bold(cls.className) +
        (asTag.isEmpty ? '' : _dim(asTag)) +
        (hotTag.isEmpty ? '' : ' ${_dim('[hot: $hot cycles]')}');

    stdout.writeln(
      '  $renderedClass$padding${_dim('${cls.filePath}:${cls.line}')}',
    );

    if (adj.isEmpty) {
      stdout.writeln('    ${_dim('(no registered dependencies)')}');
      continue;
    }

    final targets = adj.keys.toList()..sort();
    for (final t in targets) {
      final isEager = adj[t] == _EdgeKind.eager;
      // 'lazy ' is padded to the width of 'eager'.
      final kindStr = isEager ? _boldRed('eager') : _yellow('lazy ');
      stdout.writeln('    $kindStr ${_dim(_gArrow)} ${_bold(t)}');
    }
  }
}

// MARK: Visitor

/// Collects the registered classes of one file.
class _Collector extends RecursiveAstVisitor<void> {
  ///
  _Collector(this.filePath, this.lineInfo);

  ///
  final String filePath;
  ///
  final LineInfo lineInfo;
  ///
  final classes = <_ClassInfo>[];

  /// The kind of each member decides the kind of the edges found in it.
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final registered = _detectRegistration(node);
    if (registered == null) return;

    final info = _ClassInfo(
      className: node.namePart.typeName.lexeme,
      registeredAs: registered,
      filePath: filePath,
      // The name token, not the node: the node starts at the doc comment.
      line: lineInfo.getLocation(node.namePart.typeName.offset).lineNumber,
    );

    for (final member in node.body.members) {
      if (member is FieldDeclaration) {
        // A static field initializer runs on first access, not when an
        // instance is built.
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

/// Records every `getIt<T>()` call in the subtree it visits, all of [kind].
class _GetItVisitor extends RecursiveAstVisitor<void> {
  ///
  _GetItVisitor(this.kind, this.lineInfo);

  ///
  final _EdgeKind kind;
  ///
  final LineInfo lineInfo;
  ///
  final refs = <_Ref>[];

  /// A call without a type argument names no dependency and is skipped.
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

  /// Only a bare `getIt<T>()`: a call with a target is some other method.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'getIt' && node.target == null) {
      _capture(node.typeArguments, node.offset);
    }
    super.visitMethodInvocation(node);
  }

  /// The same call when it parses as a function-expression invocation.
  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final func = node.function;
    if (func is SimpleIdentifier && func.name == 'getIt') {
      _capture(node.typeArguments, node.offset);
    }
    super.visitFunctionExpressionInvocation(node);
  }
}
