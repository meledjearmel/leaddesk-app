import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Où en est une exécution, pour la reprendre (D-025) : conversation avec
/// le modèle, coût cumulé, livrables écrits.
class RunState {
  const RunState({
    required this.messages,
    this.costMicros = 0,
    this.deliverables = const <String>[],
  });

  factory RunState.fromJson(Map<String, Object?> json) => RunState(
    messages: <Map<String, Object?>>[
      for (final m in json['messages'] as List<Object?>? ?? const <Object?>[])
        if (m is Map<String, Object?>) m,
    ],
    costMicros: (json['cost_micros'] as num?)?.toInt() ?? 0,
    deliverables: <String>[
      for (final d
          in json['deliverables'] as List<Object?>? ?? const <Object?>[])
        if (d is String) d,
    ],
  );

  final List<Map<String, Object?>> messages;
  final int costMicros;
  final List<String> deliverables;

  Map<String, Object?> toJson() => <String, Object?>{
    'messages': messages,
    'cost_micros': costMicros,
    'deliverables': deliverables,
  };
}

/// Journal local des exécutions en cours. Il contient le contenu lu par
/// l'agent : il reste sur cet ordinateur, jamais envoyé au serveur.
abstract interface class RunJournal {
  Future<RunState?> read(int runId);
  Future<void> write(int runId, RunState state);
  Future<void> delete(int runId);
}

/// Un fichier JSON par exécution, dans le dossier de l'application.
class FileRunJournal implements RunJournal {
  FileRunJournal([String? directory])
    : directory = directory ?? _defaultDirectory();

  final String directory;

  static String _defaultDirectory() {
    final base =
        Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    return p.join(base, 'LeadDesk', 'runs');
  }

  File _file(int runId) => File(p.join(directory, 'run-$runId.json'));

  @override
  Future<RunState?> read(int runId) async {
    final file = _file(runId);
    try {
      if (!file.existsSync()) {
        return null;
      }
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, Object?> ? RunState.fromJson(json) : null;
    } on Object {
      // Journal abîmé : l'exécution repartira de zéro.
      return null;
    }
  }

  @override
  Future<void> write(int runId, RunState state) async {
    final file = _file(runId);
    await file.parent.create(recursive: true);
    // Écriture atomique : un arrêt brutal ne laisse pas un fichier tronqué.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> delete(int runId) async {
    final file = _file(runId);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}

/// Journal en mémoire, pour les tests.
class MemoryRunJournal implements RunJournal {
  final Map<int, RunState> states = <int, RunState>{};

  @override
  Future<RunState?> read(int runId) async => states[runId];

  @override
  Future<void> write(int runId, RunState state) async => states[runId] = state;

  @override
  Future<void> delete(int runId) async => states.remove(runId);
}
