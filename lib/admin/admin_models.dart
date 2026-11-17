/// Enregistrements du back-office, tels que l'API les renvoie.
library;

int _id(Object? v) => (v! as num).toInt();
int? _optId(Object? v) => (v as num?)?.toInt();
List<String> _strings(Object? v) => <String>[
  if (v is List<Object?>)
    for (final s in v)
      if (s is String) s,
];

/// Unité de l'organisation (département, pôle…), imbriquable (RM-03).
class OrgUnit {
  const OrgUnit({
    required this.id,
    required this.name,
    this.parentId,
    this.kind,
    this.systemRole,
    this.color,
    this.activityTags = const <String>[],
    this.sortOrder = 0,
  });

  factory OrgUnit.fromJson(Map<String, Object?> j) => OrgUnit(
    id: _id(j['id']),
    name: j['name'] as String? ?? '',
    parentId: _optId(j['parent_id']),
    kind: j['kind'] as String?,
    systemRole: j['system_role'] as String?,
    color: j['color'] as String?,
    activityTags: _strings(j['activity_tags']),
    sortOrder: _optId(j['sort_order']) ?? 0,
  );

  final int id;
  final String name;
  final int? parentId;
  final String? kind;

  /// `hr`, `facilities` : unité présente dans toute entreprise.
  final String? systemRole;
  final String? color;
  final List<String> activityTags;
  final int sortOrder;
}

/// Poste : fonction, mission et place hiérarchique.
class OrgPosition {
  const OrgPosition({
    required this.id,
    required this.title,
    required this.unitId,
    this.reportsToId,
    this.mission,
    this.responsibilities = const <String>[],
    this.isHead = false,
    this.status = 'draft',
  });

  factory OrgPosition.fromJson(Map<String, Object?> j) => OrgPosition(
    id: _id(j['id']),
    title: j['title'] as String? ?? '',
    unitId: _id(j['unit_id']),
    reportsToId: _optId(j['reports_to_id']),
    mission: j['mission'] as String?,
    responsibilities: _strings(j['responsibilities']),
    isHead: j['is_head'] == true,
    status: j['status'] as String? ?? 'draft',
  );

  final int id;
  final String title;
  final int unitId;
  final int? reportsToId;
  final String? mission;
  final List<String> responsibilities;
  final bool isHead;
  final String status;
}

/// Modèle IA affecté à un agent.
class AgentModelLink {
  const AgentModelLink({
    required this.aiModelId,
    this.purpose,
    this.isDefault = false,
  });

  factory AgentModelLink.fromJson(Map<String, Object?> j) => AgentModelLink(
    aiModelId: _id(j['ai_model_id']),
    purpose: j['purpose'] as String?,
    isDefault: j['is_default'] == true,
  );

  final int aiModelId;
  final String? purpose;
  final bool isDefault;

  Map<String, Object?> toJson() => <String, Object?>{
    'ai_model_id': aiModelId,
    'purpose': purpose,
    'is_default': isDefault,
  };
}

/// Agent : personne IA affectée à un poste.
class OrgAgent {
  const OrgAgent({
    required this.id,
    required this.name,
    this.bio,
    this.positionId,
    this.status = 'draft',
    this.models = const <AgentModelLink>[],
  });

  factory OrgAgent.fromJson(Map<String, Object?> j) => OrgAgent(
    id: _id(j['id']),
    name: j['name'] as String? ?? '',
    bio: j['bio'] as String?,
    positionId: _optId(j['position_id']),
    status: j['status'] as String? ?? 'draft',
    models: <AgentModelLink>[
      if (j['ai_models'] case final List<Object?> list)
        for (final m in list)
          if (m is Map<String, Object?>) AgentModelLink.fromJson(m),
    ],
  );

  final int id;
  final String name;
  final String? bio;
  final int? positionId;
  final String status;
  final List<AgentModelLink> models;

  bool get active => status == 'active';
}

/// Modèle proposé par un fournisseur.
class AiModelEntry {
  const AiModelEntry({
    required this.id,
    required this.providerId,
    required this.identifier,
    this.label,
  });

  factory AiModelEntry.fromJson(Map<String, Object?> j) => AiModelEntry(
    id: _id(j['id']),
    providerId: _id(j['ai_provider_id']),
    identifier: j['identifier'] as String? ?? '',
    label: j['label'] as String?,
  );

  final int id;
  final int providerId;
  final String identifier;
  final String? label;

  String get displayName =>
      (label == null || label!.isEmpty) ? identifier : label!;
}

/// Fournisseur de modèles IA. Sa clé ne passe jamais par le serveur.
class AiProviderEntry {
  const AiProviderEntry({
    required this.id,
    required this.name,
    required this.driver,
    this.baseUrl,
    this.models = const <AiModelEntry>[],
  });

  factory AiProviderEntry.fromJson(Map<String, Object?> j) => AiProviderEntry(
    id: _id(j['id']),
    name: j['name'] as String? ?? '',
    driver: j['driver'] as String? ?? '',
    baseUrl: j['base_url'] as String?,
    models: <AiModelEntry>[
      if (j['models'] case final List<Object?> list)
        for (final m in list)
          if (m is Map<String, Object?>) AiModelEntry.fromJson(m),
    ],
  );

  final int id;
  final String name;
  final String driver;
  final String? baseUrl;
  final List<AiModelEntry> models;
}

/// Libellés des étiquettes d'activité d'une unité.
const Map<String, String> activityTagLabels = <String, String>{
  'pilotage': 'Pilotage',
  'conception': 'Conception',
  'code': 'Code',
  'infrastructure': 'Infrastructure',
  'tests': 'Tests',
  'securite': 'Sécurité',
  'design': 'Design',
  'redaction': 'Rédaction',
  'media': 'Médias',
  'vente': 'Vente',
  'appels': 'Appels',
  'recrutement': 'Recrutement',
  'finance': 'Finance',
  'documents': 'Documents',
  'recherche': 'Recherche',
  'formation': 'Formation',
  'crise': 'Crise',
  'donnees': 'Données',
  'calme': 'Calme',
};
