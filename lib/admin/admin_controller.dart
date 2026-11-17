import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'admin_models.dart';

/// Rubriques du back-office.
enum AdminSection {
  company('Entreprise'),
  units('Organisation'),
  positions('Postes'),
  agents('Agents'),
  providers('Modèles IA');

  const AdminSection(this.label);

  final String label;

  /// Chemin de l'API ; l'entreprise et les fournisseurs n'ont pas de
  /// corbeille.
  String? get path => switch (this) {
    AdminSection.units => 'units',
    AdminSection.positions => 'positions',
    AdminSection.agents => 'agents',
    AdminSection.providers => 'ai-providers',
    AdminSection.company => null,
  };

  bool get hasTrash =>
      this == AdminSection.units ||
      this == AdminSection.positions ||
      this == AdminSection.agents;
}

/// Back-office de l'application (D-026) : configuration de l'entreprise,
/// de son organisation, de ses postes, de ses agents et de ses modèles IA.
/// Rien n'est codé en dur (RM-03) : tout vient du serveur.
class AdminController extends ChangeNotifier {
  AdminController(this.api);

  final ApiClient api;

  AdminSection section = AdminSection.units;

  /// Corbeille affichée à la place de la liste.
  bool showTrash = false;

  /// Enregistrement ouvert dans l'éditeur ; `null` avec [creating] pour
  /// un nouvel enregistrement.
  int? selectedId;
  bool creating = false;

  bool loading = false;
  bool busy = false;
  String? error;

  /// Message de réussite bref (« Enregistré »).
  String? notice;

  String companyName = '';
  List<OrgUnit> units = <OrgUnit>[];
  List<OrgPosition> positions = <OrgPosition>[];
  List<OrgAgent> agents = <OrgAgent>[];
  List<AiProviderEntry> providers = <AiProviderEntry>[];
  List<OrgUnit> trashedUnits = <OrgUnit>[];
  List<OrgPosition> trashedPositions = <OrgPosition>[];
  List<OrgAgent> trashedAgents = <OrgAgent>[];

  /// Types de fournisseurs connus : (driver, libellé).
  List<(String, String)> drivers = <(String, String)>[];
  List<String> activityTags = <String>[];

  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        api.get('company'),
        api.getList('units'),
        api.getList('positions'),
        api.getList('agents'),
        api.getList('ai-providers'),
        api.getList('units?trashed=1'),
        api.getList('positions?trashed=1'),
        api.getList('agents?trashed=1'),
        api.getList('ai-providers/catalog'),
        api.get('office/activity-tags'),
      ]);
      final company = results[0];
      companyName = company is Map<String, Object?>
          ? company['name'] as String? ?? ''
          : '';
      List<Map<String, Object?>> at(int i) =>
          results[i]! as List<Map<String, Object?>>;
      units = at(1).map(OrgUnit.fromJson).toList();
      positions = at(2).map(OrgPosition.fromJson).toList();
      agents = at(3).map(OrgAgent.fromJson).toList();
      providers = at(4).map(AiProviderEntry.fromJson).toList();
      trashedUnits = at(5).map(OrgUnit.fromJson).toList();
      trashedPositions = at(6).map(OrgPosition.fromJson).toList();
      trashedAgents = at(7).map(OrgAgent.fromJson).toList();
      drivers = <(String, String)>[
        for (final d in at(8))
          (d['driver'] as String? ?? '', d['label'] as String? ?? ''),
      ];
      activityTags = <String>[
        if (results[9] case final List<Object?> tags)
          for (final t in tags)
            if (t is String) t,
      ];
    } on ApiException catch (e) {
      error = e.message;
    } on Object {
      error = 'Serveur injoignable. Vérifiez la connexion.';
    }
    loading = false;
    _notify();
  }

  // Navigation.

  void open(AdminSection value) {
    section = value;
    showTrash = false;
    selectedId = null;
    creating = false;
    error = null;
    notice = null;
    _notify();
  }

  void toggleTrash() {
    showTrash = !showTrash;
    selectedId = null;
    creating = false;
    _notify();
  }

  void select(int id) {
    selectedId = id;
    creating = false;
    error = null;
    notice = null;
    _notify();
  }

  void startCreating() {
    selectedId = null;
    creating = true;
    showTrash = false;
    error = null;
    notice = null;
    _notify();
  }

  void closeEditor() {
    selectedId = null;
    creating = false;
    error = null;
    _notify();
  }

  // Recherches.

  OrgUnit? unit(int? id) => _find(units, id, (u) => u.id);
  OrgPosition? position(int? id) => _find(positions, id, (p) => p.id);
  OrgAgent? agent(int? id) => _find(agents, id, (a) => a.id);
  AiProviderEntry? provider(int? id) => _find(providers, id, (p) => p.id);

  static T? _find<T>(List<T> list, int? id, int Function(T) idOf) {
    if (id == null) {
      return null;
    }
    for (final item in list) {
      if (idOf(item) == id) {
        return item;
      }
    }
    return null;
  }

  /// Tous les modèles, avec leur fournisseur.
  List<(AiProviderEntry, AiModelEntry)> get allModels =>
      <(AiProviderEntry, AiModelEntry)>[
        for (final p in providers)
          for (final m in p.models) (p, m),
      ];

  /// Chemin d'une unité, du premier niveau à elle (« Technique › Développement »).
  String unitPath(int? id) {
    final names = <String>[];
    var current = unit(id);
    var guard = 0;
    while (current != null && guard++ < 20) {
      names.insert(0, current.name);
      current = unit(current.parentId);
    }
    return names.join(' › ');
  }

  /// Unités dans l'ordre de l'arbre, avec leur profondeur.
  List<(OrgUnit, int)> get unitTree {
    final result = <(OrgUnit, int)>[];
    final ids = units.map((u) => u.id).toSet();
    void walk(int? parent, int depth) {
      for (final u in units) {
        final p = u.parentId != null && ids.contains(u.parentId)
            ? u.parentId
            : null;
        if (p == parent && depth < 20) {
          result.add((u, depth));
          walk(u.id, depth + 1);
        }
      }
    }

    walk(null, 0);
    return result;
  }

  /// Vrai si [candidate] est [unitId] ou l'une de ses sous-unités.
  bool isSelfOrDescendant(int candidate, int unitId) {
    var current = unit(candidate);
    var guard = 0;
    while (current != null && guard++ < 20) {
      if (current.id == unitId) {
        return true;
      }
      current = unit(current.parentId);
    }
    return false;
  }

  /// Vrai si [candidate] est [positionId] ou rend compte, même de loin, à lui.
  bool reportsToSelf(int candidate, int positionId) {
    var current = position(candidate);
    var guard = 0;
    while (current != null && guard++ < 50) {
      if (current.id == positionId) {
        return true;
      }
      current = position(current.reportsToId);
    }
    return false;
  }

  // Écritures. Chacune rend vrai si elle a réussi.

  Future<bool> saveCompany(String name) => _run(() async {
    await api.patch('company', <String, Object?>{'name': name.trim()});
    companyName = name.trim();
  }, notice: 'Entreprise enregistrée.');

  Future<bool> saveUnit({
    int? id,
    required String name,
    int? parentId,
    String? kind,
    String? color,
    required List<String> activityTags,
  }) => _run(() async {
    final body = <String, Object?>{
      'name': name.trim(),
      'parent_id': ?parentId,
      'kind': _blank(kind),
      'color': _blank(color),
      'activity_tags': activityTags,
    };
    final data = id == null
        ? await api.post('units', body)
        : await api.patch('units/$id', body);
    _afterSave(OrgUnit.fromJson(data! as Map<String, Object?>).id);
  }, notice: id == null ? 'Unité créée.' : 'Unité enregistrée.');

  Future<bool> savePosition({
    int? id,
    required String title,
    required int unitId,
    int? reportsToId,
    String? mission,
    required List<String> responsibilities,
    required bool isHead,
    required String status,
  }) => _run(() async {
    final body = <String, Object?>{
      'title': title.trim(),
      'unit_id': unitId,
      'reports_to_id': reportsToId,
      'mission': _blank(mission),
      'responsibilities': responsibilities,
      'is_head': isHead,
      'status': status,
    };
    final data = id == null
        ? await api.post('positions', body)
        : await api.patch('positions/$id', body);
    _afterSave(OrgPosition.fromJson(data! as Map<String, Object?>).id);
  }, notice: id == null ? 'Poste créé.' : 'Poste enregistré.');

  /// Enregistre un agent : identité, poste, modèles, mise en service.
  /// Chaque partie n'est envoyée que si elle a changé.
  Future<bool> saveAgent({
    int? id,
    required String name,
    String? bio,
    int? positionId,
    required List<AgentModelLink> models,
    required bool active,
  }) => _run(() async {
    final before = agent(id);
    var agentId = id;
    if (agentId == null) {
      final data = await api.post('agents', <String, Object?>{
        'name': name.trim(),
        'bio': _blank(bio),
        'position_id': ?positionId,
      });
      agentId = OrgAgent.fromJson(data! as Map<String, Object?>).id;
    } else {
      await api.patch('agents/$agentId', <String, Object?>{
        'name': name.trim(),
        'bio': _blank(bio),
      });
      if (before?.positionId != positionId) {
        await api.post('agents/$agentId/position', <String, Object?>{
          'position_id': positionId,
        });
      }
    }
    final wasActive = before?.active ?? false;
    // Un agent en service doit garder un modèle : on le repasse en
    // brouillon avant de changer ses modèles, et on le remet ensuite.
    if (wasActive && !active) {
      await api.post('agents/$agentId/deactivate');
    }
    if (!_sameModels(before?.models ?? const <AgentModelLink>[], models)) {
      await api.put('agents/$agentId/ai-models', <String, Object?>{
        'models': <Map<String, Object?>>[for (final m in models) m.toJson()],
      });
    }
    if (active && !wasActive) {
      await api.post('agents/$agentId/activate');
    }
    _afterSave(agentId);
  }, notice: id == null ? 'Agent créé.' : 'Agent enregistré.');

  Future<bool> saveProvider({
    int? id,
    required String name,
    required String driver,
    String? baseUrl,
  }) => _run(() async {
    final body = <String, Object?>{
      'name': name.trim(),
      'driver': driver.trim(),
      'base_url': _blank(baseUrl),
    };
    final data = id == null
        ? await api.post('ai-providers', body)
        : await api.patch('ai-providers/$id', body);
    _afterSave(AiProviderEntry.fromJson(data! as Map<String, Object?>).id);
  }, notice: id == null ? 'Fournisseur ajouté.' : 'Fournisseur enregistré.');

  Future<bool> addModel(int providerId, String identifier, String? label) =>
      _run(() async {
        await api.post('ai-providers/$providerId/models', <String, Object?>{
          'identifier': identifier.trim(),
          'label': _blank(label),
        });
      }, notice: 'Modèle ajouté.');

  Future<bool> renameModel(int modelId, String? label) => _run(() async {
    await api.patch('ai-models/$modelId', <String, Object?>{
      'label': _blank(label),
    });
  }, notice: 'Modèle renommé.');

  Future<bool> removeModel(int modelId) => _run(() async {
    await api.delete('ai-models/$modelId');
  }, notice: 'Modèle retiré.');

  /// Met l'enregistrement ouvert à la corbeille (ou retire le fournisseur).
  Future<bool> trash(int id) {
    final path = section.path;
    if (path == null) {
      return Future<bool>.value(false);
    }
    return _run(
      () async {
        await api.delete('$path/$id');
        selectedId = null;
      },
      notice: section.hasTrash
          ? 'Mis à la corbeille. Vous pouvez le restaurer.'
          : 'Fournisseur retiré.',
    );
  }

  Future<bool> restore(int id) {
    final path = section.path;
    if (path == null || !section.hasTrash) {
      return Future<bool>.value(false);
    }
    return _run(() async {
      await api.post('$path/$id/restore');
    }, notice: 'Restauré.');
  }

  // Outils.

  void _afterSave(int id) {
    selectedId = id;
    creating = false;
  }

  Future<bool> _run(Future<void> Function() action, {String? notice}) async {
    if (busy) {
      return false;
    }
    busy = true;
    error = null;
    this.notice = null;
    _notify();
    var ok = false;
    try {
      await action();
      await _reload();
      this.notice = notice;
      ok = true;
    } on ApiException catch (e) {
      // Le premier message de validation est plus précis que le message
      // général.
      error = e.errors.values.expand((m) => m).firstOrNull ?? e.message;
      await _reload();
    } on Object {
      error = 'Serveur injoignable. Vérifiez la connexion.';
    }
    busy = false;
    _notify();
    return ok;
  }

  /// Recharge sans montrer l'indicateur de chargement ni effacer l'erreur.
  Future<void> _reload() async {
    final keepError = error;
    final keepSelection = (selectedId, creating);
    await load();
    error ??= keepError;
    selectedId = keepSelection.$1;
    creating = keepSelection.$2;
  }

  static String? _blank(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  static bool _sameModels(List<AgentModelLink> a, List<AgentModelLink> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i].aiModelId != b[i].aiModelId ||
          a[i].isDefault != b[i].isDefault ||
          (a[i].purpose ?? '') != (b[i].purpose ?? '')) {
        return false;
      }
    }
    return true;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
