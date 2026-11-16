import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

/// Une demande qui attend le CEO (file unique, RM-25).
class CeoDecision {
  const CeoDecision({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    required this.payload,
    this.requestedBy,
    this.note,
    this.createdAt,
  });

  factory CeoDecision.fromJson(Map<String, Object?> json) => CeoDecision(
    id: (json['id']! as num).toInt(),
    kind: json['kind'] as String? ?? '',
    title: json['title'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    payload: json['payload'] is Map<String, Object?>
        ? json['payload']! as Map<String, Object?>
        : const <String, Object?>{},
    requestedBy: json['requested_by_name'] as String?,
    note: json['decision_note'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')
        ?.toLocal(),
  );

  final int id;

  /// `rule_change`, `cost_limit`, `tool_approval`, `office_plan`…
  final String kind;
  final String title;

  /// `pending`, `needs_info`, `approved`, `rejected`.
  final String status;
  final Map<String, Object?> payload;
  final String? requestedBy;
  final String? note;
  final DateTime? createdAt;

  bool get isOpen => status == 'pending' || status == 'needs_info';

  /// Nature en clair.
  String get kindLabel => switch (kind) {
    'tool_approval' => 'Action d\'agent',
    'cost_limit' => 'Limite de coût',
    'rule_change' => 'Changement de règle',
    'office_plan' => 'Aménagement du bureau',
    _ => 'Demande',
  };

  /// Titre lisible : une action d'agent est nommée en clair.
  String get displayTitle => kind != 'tool_approval'
      ? title
      : switch (payload['tool']) {
          'write_file' => 'Écrire un fichier',
          'read_file' => 'Lire un fichier',
          final String tool => 'Utiliser l\'outil « $tool »',
          _ => title,
        };

  /// Limite actuelle et dépense, pour une limite de coût atteinte.
  int? get limitMicros => (payload['limit_micros'] as num?)?.toInt();
  int? get spentMicros => (payload['spent_micros'] as num?)?.toInt();

  /// Ce que l'agent veut faire, pour une action soumise au CEO.
  String? get summary => payload['summary'] as String?;
}

/// File des décisions du CEO dans l'application (D-024).
class DecisionsController extends ChangeNotifier {
  DecisionsController(
    this.api, {
    this.refreshEvery = const Duration(seconds: 5),
  });

  final ApiClient api;

  /// Relecture régulière tant que la file est ouverte : un agent attend
  /// peut-être une réponse.
  final Duration refreshEvery;

  List<CeoDecision> _open = const <CeoDecision>[];
  bool _loading = false;
  String? _error;
  final Set<int> _busy = <int>{};
  Timer? _timer;
  bool _disposed = false;

  List<CeoDecision> get open => _open;
  int get count => _open.length;
  bool get loading => _loading;
  String? get error => _error;
  bool isBusy(int id) => _busy.contains(id);

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Relit les demandes ouvertes (en attente ou en précisions).
  Future<void> load() async {
    _loading = true;
    _notify();
    try {
      final pending = await api.getList('decisions?status=pending');
      final info = await api.getList('decisions?status=needs_info');
      _open = <CeoDecision>[
        for (final raw in <Map<String, Object?>>[...pending, ...info])
          CeoDecision.fromJson(raw),
      ]..sort((a, b) => b.id.compareTo(a.id));
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    } on Object {
      _error = 'Décisions illisibles : vérifiez la connexion au serveur.';
    }
    _loading = false;
    _notify();
  }

  /// Relecture régulière tant que [watching] est vrai.
  void watch({required bool watching}) {
    _timer?.cancel();
    _timer = null;
    if (watching) {
      unawaited(load());
      _timer = Timer.periodic(refreshEvery, (_) => load());
    }
  }

  Future<void> approve(
    CeoDecision decision, {
    String? note,
    int? newLimitMicros,
  }) => _act(decision, 'approve', <String, Object?>{
    if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    'new_limit_micros': ?newLimitMicros,
  });

  Future<void> reject(CeoDecision decision, {String? note}) =>
      _act(decision, 'reject', <String, Object?>{
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  /// Demande des précisions ; la note est obligatoire.
  Future<void> requestInfo(CeoDecision decision, String note) =>
      _act(decision, 'request-info', <String, Object?>{'note': note.trim()});

  Future<void> _act(
    CeoDecision decision,
    String action,
    Map<String, Object?> body,
  ) async {
    if (_busy.contains(decision.id)) {
      return;
    }
    _busy.add(decision.id);
    _error = null;
    _notify();
    try {
      await api.post('decisions/${decision.id}/$action', body);
      if (action != 'request-info') {
        _open = _open.where((d) => d.id != decision.id).toList();
      }
    } on ApiException catch (error) {
      _error = error.message;
    } on Object {
      _error = 'La décision n\'a pas pu être envoyée.';
    } finally {
      _busy.remove(decision.id);
      _notify();
    }
    if (action == 'request-info' || _error != null) {
      await load();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
