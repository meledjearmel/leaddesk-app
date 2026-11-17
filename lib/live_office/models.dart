import 'package:flutter/material.dart';

import 'scene/pixel_people.dart';
import 'scene/presence.dart';

export 'scene/presence.dart' show SeatPresence, SeatState;

/// Fournisseur du modèle d'un agent, représenté par un pictogramme générique
/// (aucun logo de marque n'est repris).
enum AgentProvider {
  flare(Icons.flare, Color(0xFFF08A5D)),
  loop(Icons.all_inclusive, Color(0xFFF5F3EF)),
  spark(Icons.auto_awesome, Color(0xFFA78BFA)),
  bot(Icons.smart_toy_outlined, Color(0xFFF5F3EF)),
  cube(Icons.view_in_ar_outlined, Color(0xFFF5F3EF)),
  hub(Icons.hub_outlined, Color(0xFFF2617A));

  const AgentProvider(this.icon, this.color);

  final IconData icon;
  final Color color;
}

/// Portrait d'un agent dans les listes.
class AvatarStyle {
  const AvatarStyle({
    required this.background,
    required this.skin,
    required this.hair,
    required this.top,
    this.glasses = false,
    this.longHair = false,
  });

  final Color background;
  final Color skin;
  final Color hair;
  final Color top;
  final bool glasses;
  final bool longHair;
}

/// Où placer l'étiquette d'un agent par rapport à son personnage.
enum TagPlacement { aboveLeft, above, aboveRight, belowRight }

/// État réel d'un agent, lu sur le serveur (phase 5) : ce que le bureau
/// montre de lui.
enum AgentState {
  /// Exécute une tâche.
  working('Au travail', Color(0xFF3FB950)),

  /// Sa tâche attend que l'ordinateur hôte revienne en ligne.
  waitingHost('Attend son ordinateur', Color(0xFF8B949E)),

  /// Une demande attend le CEO.
  waitingDecision('Attend votre décision', Color(0xFFF2B34C)),

  /// Limite de coût atteinte : pause jusqu'à la décision du CEO.
  pausedCost('Limite de coût atteinte', Color(0xFFF08A5D)),

  /// Mis en pause par le CEO.
  paused('En pause', Color(0xFF8B949E)),

  /// Sa dernière exécution a échoué.
  blocked('Bloqué', Color(0xFFE5484D)),

  /// En service, sans tâche en cours.
  idle('Disponible', Color(0xFF6E7681)),

  /// Pas encore en service.
  draft('En brouillon', Color(0xFF484F58));

  const AgentState(this.label, this.color);

  final String label;
  final Color color;

  /// Vrai quand le CEO doit regarder : l'étiquette passe devant.
  bool get needsAttention =>
      this == waitingDecision || this == pausedCost || this == blocked;

  /// Ce que le bureau montre de cet état (vue « Salle ») :
  /// - au travail : assis, code à l'écran ;
  /// - attend une décision ou limite de coût : debout près du bureau ;
  /// - en pause ou disponible : au café ou dans le couloir ;
  /// - bloqué : assis devant un écran rouge ;
  /// - attend son ordinateur, brouillon : assis, écran en veille.
  SeatState get seat => switch (this) {
    working => const SeatState(mood: PersonMood.focused),
    waitingDecision => const SeatState(
      presence: SeatPresence.standing,
      screen: ScreenMode.waiting,
      mood: PersonMood.worried,
    ),
    pausedCost => const SeatState(
      presence: SeatPresence.standing,
      screen: ScreenMode.waiting,
      mood: PersonMood.worried,
      holdsPaper: true,
    ),
    paused || idle => const SeatState(
      presence: SeatPresence.away,
      screen: ScreenMode.standby,
      mood: PersonMood.happy,
    ),
    blocked => const SeatState(
      screen: ScreenMode.error,
      mood: PersonMood.worried,
    ),
    waitingHost || draft => const SeatState(screen: ScreenMode.standby),
  };
}

/// Agent affiché dans le bureau vivant.
class OfficeAgent {
  const OfficeAgent({
    required this.id,
    required this.name,
    required this.position,
    required this.status,
    required this.provider,
    required this.avatar,
    required this.tagPlacement,
    required this.departmentId,
    this.working = false,
    this.inConversation = false,
    this.tagDetail,
    this.speech,
    this.typing = false,
    this._state,
  });

  final AgentState? _state;

  /// État réel ; en démonstration, déduit de [working].
  AgentState get state =>
      _state ?? (working ? AgentState.working : AgentState.idle);

  final String id;
  final String name;

  /// Intitulé du poste occupé.
  final String position;

  /// Activité en cours, affichée dans la liste.
  final String status;
  final AgentProvider provider;
  final AvatarStyle avatar;
  final TagPlacement tagPlacement;

  /// Département de l'agent : il travaille dans les salles de celui-ci.
  final String departmentId;

  /// Vrai quand l'agent exécute une tâche : pastille verte.
  final bool working;

  /// Vrai quand l'agent participe à la conversation ouverte : liseré ambre.
  final bool inConversation;

  /// Complément de l'étiquette sur la scène (« Parle à … »).
  final String? tagDetail;

  /// Dernière phrase prononcée, affichée en bulle sur la scène.
  final String? speech;

  /// Vrai quand l'agent rédige une réponse.
  final bool typing;
}

/// Entrée du fil de conversation.
sealed class ChatEntry {
  const ChatEntry();
}

class AgentMessage extends ChatEntry {
  const AgentMessage({
    required this.agentId,
    required this.time,
    required this.text,
  });

  final String agentId;
  final String time;
  final String text;
}

class UserMessage extends ChatEntry {
  const UserMessage({required this.time, required this.text});

  final String time;
  final String text;
}

class SystemNote extends ChatEntry {
  const SystemNote({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

/// Données de démonstration : elles seront remplacées par l'API `/api/v1`
/// et les événements Reverb à partir de la phase 2.
abstract final class DemoData {
  static const String projectName = 'Campagne de lancement';

  static const List<OfficeAgent> agents = <OfficeAgent>[
    OfficeAgent(
      id: 'atlas',
      departmentId: 'produit',
      name: 'Atlas',
      position: 'Chef de projet',
      status: 'En conversation avec vous',
      provider: AgentProvider.loop,
      tagPlacement: TagPlacement.aboveRight,
      inConversation: true,
      tagDetail: 'Parle à Quill',
      speech: 'Voici le brief de lancement. Notes attendues à l\'étape 18.',
      avatar: AvatarStyle(
        background: Color(0xFF8B5CF6),
        skin: Color(0xFFEBC29A),
        hair: Color(0xFF3B2A22),
        top: Color(0xFF3F7650),
        glasses: true,
      ),
    ),
    OfficeAgent(
      id: 'forge',
      departmentId: 'technique',
      name: 'Forge',
      position: 'Développeur',
      status: 'Écrit du code · étape 14 sur 22',
      provider: AgentProvider.flare,
      tagPlacement: TagPlacement.aboveRight,
      working: true,
      avatar: AvatarStyle(
        background: Color(0xFF2BB5B0),
        skin: Color(0xFFE9BE95),
        hair: Color(0xFF2E211C),
        top: Color(0xFF2A3854),
      ),
    ),
    OfficeAgent(
      id: 'scout',
      departmentId: 'technique',
      name: 'Scout',
      position: 'Développeur',
      status: 'Lit l\'API de publication',
      provider: AgentProvider.cube,
      tagPlacement: TagPlacement.aboveLeft,
      working: true,
      avatar: AvatarStyle(
        background: Color(0xFF3FA65A),
        skin: Color(0xFFD9A47A),
        hair: Color(0xFF4A2E1E),
        top: Color(0xFF3C5FA8),
        glasses: true,
      ),
    ),
    OfficeAgent(
      id: 'relay',
      departmentId: 'qualite',
      name: 'Relay',
      position: 'Testeur QA',
      status: 'Attend de tester le build',
      provider: AgentProvider.bot,
      tagPlacement: TagPlacement.aboveRight,
      avatar: AvatarStyle(
        background: Color(0xFF3B6FE0),
        skin: Color(0xFFE9BE95),
        hair: Color(0xFF2B1F1C),
        top: Color(0xFF2E5661),
      ),
    ),
    OfficeAgent(
      id: 'quill',
      departmentId: 'contenu',
      name: 'Quill',
      position: 'Rédacteur technique',
      status: 'Vous répond',
      provider: AgentProvider.spark,
      tagPlacement: TagPlacement.belowRight,
      inConversation: true,
      tagDetail: 'Vous répond',
      typing: true,
      avatar: AvatarStyle(
        background: Color(0xFFE5484D),
        skin: Color(0xFFEBC29A),
        hair: Color(0xFF7A3A22),
        top: Color(0xFF2C2A31),
        longHair: true,
      ),
    ),
  ];

  static const List<ChatEntry> conversation = <ChatEntry>[
    AgentMessage(
      agentId: 'atlas',
      time: '14:34',
      text:
          'Journal des modifications pour les développeurs. Moins de '
          '200 mots, avec un lien vers la pull request #214.',
    ),
    SystemNote(
      icon: Icons.description_outlined,
      text: 'Atlas a transmis le brief de lancement · 3 fichiers',
    ),
    AgentMessage(
      agentId: 'quill',
      time: '14:34',
      text:
          'Je m\'en occupe. Je récupère d\'abord le résumé du diff chez Forge.',
    ),
    SystemNote(
      icon: Icons.person_add_alt_1_outlined,
      text: 'Vous avez rejoint la conversation',
    ),
    UserMessage(
      time: '14:35',
      text: 'Ajoute aussi une ligne sur les nouvelles limites de débit de l\'API.',
    ),
  ];
}
