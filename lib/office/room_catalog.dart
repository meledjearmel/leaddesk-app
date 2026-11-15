/// Catalogue des types de salle du bureau vivant.
///
/// Données pures, sans dessin : le dessin d'une salle est choisi par son
/// [RoomLook]. Les étiquettes d'activité ([RoomType.tags]) relient une salle
/// aux départements qui en ont besoin, sans jamais nommer un département :
/// les départements restent configurables (RM-03).
library;

/// Famille de salle, pour ranger le catalogue.
enum RoomCategory {
  production('Production et travail'),
  collaboration('Collaboration et réunion'),
  wellbeing('Détente et bien-être'),
  knowledge('Savoir, accueil et logistique'),
  steering('Pilotage');

  const RoomCategory(this.label);

  final String label;
}

/// À qui une salle peut appartenir.
enum RoomScope {
  /// Salle d'un seul département (open space, laboratoire…).
  department,

  /// Lieu commun, sans département (accueil, café, sanitaires…).
  shared,
}

/// Dessin utilisé pour meubler la salle.
enum RoomLook {
  workDesks,
  privateOffice,
  executive,
  creative,
  lab,
  servers,
  archives,
  meeting,
  boardroom,
  warRoom,
  brainstorm,
  phoneBooth,
  videoCall,
  cafe,
  cafeteria,
  lounge,
  arcade,
  nap,
  gym,
  terrace,
  auditorium,
  training,
  library,
  reception,
  waiting,
  printRoom,
  lockers,
  studio,
  controlRoom,
}

/// Type de salle : nom, taille, places, besoins servis.
class RoomType {
  const RoomType({
    required this.id,
    required this.name,
    required this.category,
    required this.scope,
    required this.look,
    required this.minCols,
    required this.minRows,
    this.seatsPerRow = 0,
    this.tags = const <String>{},
    this.proposed = false,
  });

  /// Identifiant stable, utilisé dans les plans enregistrés.
  final String id;
  final String name;
  final RoomCategory category;
  final RoomScope scope;
  final RoomLook look;

  /// Taille minimale, en cases de la grille.
  final int minCols;
  final int minRows;

  /// Postes de travail ajoutés par rangée de deux cases ; 0 si la salle
  /// n'accueille pas de postes permanents.
  final int seatsPerRow;

  /// Activités servies : un département qui porte une de ces étiquettes
  /// peut demander cette salle.
  final Set<String> tags;

  /// Vrai pour les salles ajoutées au-delà de la liste d'Armel.
  final bool proposed;

  bool get hasDesks => seatsPerRow > 0;

  /// Postes disponibles pour une salle de [rows] rangées de cases.
  int seatsFor(int rows) => hasDesks ? seatsPerRow * (rows ~/ 2) : 0;

  /// Rangées nécessaires pour asseoir [people] personnes.
  int rowsFor(int people) {
    if (!hasDesks || people <= 0) {
      return minRows;
    }
    final pairs = (people + seatsPerRow - 1) ~/ seatsPerRow;
    return pairs * 2 > minRows ? pairs * 2 : minRows;
  }
}

/// Étiquettes d'activité reconnues par le catalogue.
abstract final class ActivityTag {
  static const String management = 'pilotage';
  static const String product = 'conception';
  static const String code = 'code';
  static const String infrastructure = 'infrastructure';
  static const String testing = 'tests';
  static const String security = 'securite';
  static const String design = 'design';
  static const String writing = 'redaction';
  static const String media = 'media';
  static const String sales = 'vente';
  static const String calls = 'appels';
  static const String people = 'recrutement';
  static const String finance = 'finance';
  static const String documents = 'documents';
  static const String research = 'recherche';
  static const String training = 'formation';
  static const String crisis = 'crise';
  static const String data = 'donnees';

  /// Le département préfère une zone calme, loin de l'accueil.
  static const String calm = 'calme';

  static const List<String> all = <String>[
    management,
    product,
    code,
    infrastructure,
    testing,
    security,
    design,
    writing,
    media,
    sales,
    calls,
    people,
    finance,
    documents,
    research,
    training,
    crisis,
    data,
    calm,
  ];
}

/// Catalogue complet : les 27 salles demandées et les salles proposées.
abstract final class RoomCatalog {
  static const List<RoomType> all = <RoomType>[
    // ------------------------------------------------ Production et travail
    RoomType(
      id: 'open_space',
      name: 'Open space',
      category: RoomCategory.production,
      scope: RoomScope.department,
      look: RoomLook.workDesks,
      minCols: 6,
      minRows: 2,
      seatsPerRow: 4,
    ),
    RoomType(
      id: 'private_office',
      name: 'Bureau individuel',
      category: RoomCategory.production,
      scope: RoomScope.department,
      look: RoomLook.privateOffice,
      minCols: 3,
      minRows: 3,
      seatsPerRow: 1,
      tags: <String>{ActivityTag.people, ActivityTag.finance, ActivityTag.calm},
    ),
    RoomType(
      id: 'executive_office',
      name: 'Bureau de direction',
      category: RoomCategory.production,
      scope: RoomScope.department,
      look: RoomLook.executive,
      minCols: 5,
      minRows: 4,
      seatsPerRow: 1,
      tags: <String>{ActivityTag.management},
    ),
    RoomType(
      id: 'creative_studio',
      name: 'Atelier créatif',
      category: RoomCategory.production,
      scope: RoomScope.department,
      look: RoomLook.creative,
      minCols: 5,
      minRows: 4,
      tags: <String>{ActivityTag.design, ActivityTag.writing},
    ),
    RoomType(
      id: 'rnd_lab',
      name: 'Laboratoire R&D',
      category: RoomCategory.production,
      scope: RoomScope.department,
      look: RoomLook.lab,
      minCols: 5,
      minRows: 4,
      tags: <String>{ActivityTag.research, ActivityTag.product},
    ),
    RoomType(
      id: 'server_room',
      name: 'Salle des serveurs',
      category: RoomCategory.production,
      scope: RoomScope.department,
      look: RoomLook.servers,
      minCols: 4,
      minRows: 3,
      tags: <String>{ActivityTag.infrastructure, ActivityTag.code},
    ),
    RoomType(
      id: 'archives',
      name: "Salle d'archives",
      category: RoomCategory.production,
      scope: RoomScope.department,
      look: RoomLook.archives,
      minCols: 3,
      minRows: 3,
      tags: <String>{ActivityTag.documents, ActivityTag.finance},
    ),
    // --------------------------------------------- Collaboration et réunion
    RoomType(
      id: 'meeting_room',
      name: 'Salle de réunion',
      category: RoomCategory.collaboration,
      scope: RoomScope.shared,
      look: RoomLook.meeting,
      minCols: 4,
      minRows: 4,
    ),
    RoomType(
      id: 'boardroom',
      name: 'Salle du conseil',
      category: RoomCategory.collaboration,
      scope: RoomScope.department,
      look: RoomLook.boardroom,
      minCols: 6,
      minRows: 4,
      tags: <String>{ActivityTag.management},
    ),
    RoomType(
      id: 'war_room',
      name: 'Salle de crise',
      category: RoomCategory.collaboration,
      scope: RoomScope.department,
      look: RoomLook.warRoom,
      minCols: 5,
      minRows: 4,
      tags: <String>{ActivityTag.crisis, ActivityTag.security},
    ),
    RoomType(
      id: 'brainstorm_room',
      name: 'Salle de brainstorming',
      category: RoomCategory.collaboration,
      scope: RoomScope.department,
      look: RoomLook.brainstorm,
      minCols: 4,
      minRows: 4,
      tags: <String>{
        ActivityTag.product,
        ActivityTag.design,
        ActivityTag.sales,
      },
    ),
    RoomType(
      id: 'phone_booth',
      name: "Cabine d'appel",
      category: RoomCategory.collaboration,
      scope: RoomScope.department,
      look: RoomLook.phoneBooth,
      minCols: 2,
      minRows: 2,
      tags: <String>{ActivityTag.calls, ActivityTag.sales},
    ),
    RoomType(
      id: 'video_room',
      name: 'Espace de visioconférence',
      category: RoomCategory.collaboration,
      scope: RoomScope.shared,
      look: RoomLook.videoCall,
      minCols: 3,
      minRows: 3,
    ),
    // ------------------------------------------------ Détente et bien-être
    RoomType(
      id: 'micro_kitchen',
      name: 'Café',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.cafe,
      minCols: 4,
      minRows: 3,
    ),
    RoomType(
      id: 'cafeteria',
      name: 'Cafétéria',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.cafeteria,
      minCols: 6,
      minRows: 4,
    ),
    RoomType(
      id: 'lounge',
      name: 'Salon de détente',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.lounge,
      minCols: 4,
      minRows: 4,
    ),
    RoomType(
      id: 'game_room',
      name: 'Salle de jeux',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.arcade,
      minCols: 4,
      minRows: 3,
    ),
    RoomType(
      id: 'nap_room',
      name: 'Salle de sieste',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.nap,
      minCols: 4,
      minRows: 3,
    ),
    RoomType(
      id: 'gym',
      name: 'Salle de sport et yoga',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.gym,
      minCols: 5,
      minRows: 4,
    ),
    RoomType(
      id: 'terrace',
      name: 'Terrasse',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.terrace,
      minCols: 5,
      minRows: 4,
    ),
    // -------------------------------------- Savoir, accueil et logistique
    RoomType(
      id: 'auditorium',
      name: 'Auditorium',
      category: RoomCategory.knowledge,
      scope: RoomScope.shared,
      look: RoomLook.auditorium,
      minCols: 7,
      minRows: 5,
    ),
    RoomType(
      id: 'training_room',
      name: 'Salle de formation',
      category: RoomCategory.knowledge,
      scope: RoomScope.department,
      look: RoomLook.training,
      minCols: 5,
      minRows: 4,
      tags: <String>{ActivityTag.training, ActivityTag.people},
    ),
    RoomType(
      id: 'library',
      name: 'Bibliothèque',
      category: RoomCategory.knowledge,
      scope: RoomScope.shared,
      look: RoomLook.library,
      minCols: 4,
      minRows: 3,
    ),
    RoomType(
      id: 'reception',
      name: "Hall d'accueil",
      category: RoomCategory.knowledge,
      scope: RoomScope.shared,
      look: RoomLook.reception,
      minCols: 5,
      minRows: 4,
    ),
    RoomType(
      id: 'waiting_room',
      name: "Salle d'attente",
      category: RoomCategory.knowledge,
      scope: RoomScope.shared,
      look: RoomLook.waiting,
      minCols: 3,
      minRows: 3,
    ),
    RoomType(
      id: 'print_room',
      name: 'Reprographie et courrier',
      category: RoomCategory.knowledge,
      scope: RoomScope.shared,
      look: RoomLook.printRoom,
      minCols: 3,
      minRows: 2,
    ),
    RoomType(
      id: 'restrooms',
      name: 'Vestiaires et sanitaires',
      category: RoomCategory.knowledge,
      scope: RoomScope.shared,
      look: RoomLook.lockers,
      minCols: 3,
      minRows: 3,
    ),
    // ------------------------------------------ Salles proposées en plus
    RoomType(
      id: 'qa_lab',
      name: 'Laboratoire de tests',
      category: RoomCategory.production,
      scope: RoomScope.department,
      look: RoomLook.lab,
      minCols: 5,
      minRows: 4,
      tags: <String>{ActivityTag.testing},
      proposed: true,
    ),
    RoomType(
      id: 'security_center',
      name: 'Centre de sécurité',
      category: RoomCategory.steering,
      scope: RoomScope.department,
      look: RoomLook.controlRoom,
      minCols: 5,
      minRows: 4,
      tags: <String>{ActivityTag.security},
      proposed: true,
    ),
    RoomType(
      id: 'media_studio',
      name: 'Studio son et vidéo',
      category: RoomCategory.production,
      scope: RoomScope.department,
      look: RoomLook.studio,
      minCols: 4,
      minRows: 4,
      tags: <String>{ActivityTag.media, ActivityTag.writing},
      proposed: true,
    ),
    RoomType(
      id: 'code_review_room',
      name: 'Salle de revue de code',
      category: RoomCategory.collaboration,
      scope: RoomScope.department,
      look: RoomLook.videoCall,
      minCols: 4,
      minRows: 3,
      tags: <String>{ActivityTag.code},
      proposed: true,
    ),
    RoomType(
      id: 'kanban_room',
      name: 'Salle Kanban',
      category: RoomCategory.collaboration,
      scope: RoomScope.department,
      look: RoomLook.brainstorm,
      minCols: 4,
      minRows: 3,
      tags: <String>{ActivityTag.product},
      proposed: true,
    ),
    RoomType(
      id: 'focus_room',
      name: 'Salle de concentration',
      category: RoomCategory.collaboration,
      scope: RoomScope.shared,
      look: RoomLook.library,
      minCols: 3,
      minRows: 3,
      proposed: true,
    ),
    RoomType(
      id: 'client_room',
      name: 'Salle clients',
      category: RoomCategory.collaboration,
      scope: RoomScope.department,
      look: RoomLook.meeting,
      minCols: 4,
      minRows: 4,
      tags: <String>{ActivityTag.sales},
      proposed: true,
    ),
    RoomType(
      id: 'control_room',
      name: 'Salle de pilotage',
      category: RoomCategory.steering,
      scope: RoomScope.department,
      look: RoomLook.controlRoom,
      minCols: 5,
      minRows: 4,
      tags: <String>{ActivityTag.management, ActivityTag.data},
      proposed: true,
    ),
    RoomType(
      id: 'decision_room',
      name: 'Salle des décisions',
      category: RoomCategory.steering,
      scope: RoomScope.department,
      look: RoomLook.boardroom,
      minCols: 5,
      minRows: 4,
      tags: <String>{ActivityTag.management},
      proposed: true,
    ),
    RoomType(
      id: 'hr_office',
      name: 'Bureau RH et entretiens',
      category: RoomCategory.steering,
      scope: RoomScope.department,
      look: RoomLook.meeting,
      minCols: 4,
      minRows: 3,
      tags: <String>{ActivityTag.people},
      proposed: true,
    ),
    RoomType(
      id: 'finance_office',
      name: 'Bureau des coûts',
      category: RoomCategory.steering,
      scope: RoomScope.department,
      look: RoomLook.controlRoom,
      minCols: 4,
      minRows: 3,
      tags: <String>{ActivityTag.finance},
      proposed: true,
    ),
    RoomType(
      id: 'meditation_room',
      name: 'Salle de méditation',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.gym,
      minCols: 3,
      minRows: 3,
      proposed: true,
    ),
    RoomType(
      id: 'infirmary',
      name: 'Infirmerie',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.nap,
      minCols: 3,
      minRows: 3,
      proposed: true,
    ),
    RoomType(
      id: 'music_room',
      name: 'Espace musique',
      category: RoomCategory.wellbeing,
      scope: RoomScope.shared,
      look: RoomLook.studio,
      minCols: 3,
      minRows: 3,
      proposed: true,
    ),
    RoomType(
      id: 'storage',
      name: 'Entrepôt et stock',
      category: RoomCategory.knowledge,
      scope: RoomScope.shared,
      look: RoomLook.archives,
      minCols: 4,
      minRows: 3,
      proposed: true,
    ),
    RoomType(
      id: 'shipping',
      name: 'Expédition et livraisons',
      category: RoomCategory.knowledge,
      scope: RoomScope.shared,
      look: RoomLook.printRoom,
      minCols: 3,
      minRows: 3,
      proposed: true,
    ),
    RoomType(
      id: 'vault',
      name: 'Coffre et sauvegardes',
      category: RoomCategory.knowledge,
      scope: RoomScope.department,
      look: RoomLook.servers,
      minCols: 3,
      minRows: 3,
      tags: <String>{ActivityTag.security, ActivityTag.data},
      proposed: true,
    ),
  ];

  static final Map<String, RoomType> _byId = <String, RoomType>{
    for (final type in all) type.id: type,
  };

  /// Type de salle par identifiant, ou `null` s'il est inconnu.
  static RoomType? byId(String id) => _byId[id];

  static RoomType of(String id) {
    final type = _byId[id];
    if (type == null) {
      throw ArgumentError.value(id, 'id', 'type de salle inconnu');
    }
    return type;
  }
}
