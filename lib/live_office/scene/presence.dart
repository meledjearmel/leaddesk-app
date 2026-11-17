import 'pixel_people.dart';

/// Où se trouve la personne d'un poste.
enum SeatPresence {
  /// Assise à son bureau.
  seated,

  /// Debout à côté de son bureau : elle attend le CEO.
  standing,

  /// Partie (café, couloir) : la chaise est reculée, vide.
  away,
}

/// Ce qu'affiche l'écran d'un poste.
enum ScreenMode {
  /// Code qui défile : on travaille.
  code,

  /// Veille : écran sombre, horloge.
  standby,

  /// Fenêtre ambrée au milieu : une demande attend le CEO.
  waiting,

  /// Rouge : la dernière exécution a échoué.
  error,

  /// Éteint : poste vacant.
  off,
}

/// Position de la chaise d'un poste.
enum ChairPosition {
  /// Rentrée sous le bureau : poste vacant (D-031).
  tucked,

  /// Reculée, vide : l'agent est debout ou parti.
  pulledOut,

  /// L'agent y est assis.
  occupied,
}

/// Ce qu'on voit à un poste : la chaise, l'écran, et où dessiner la
/// personne (`null` : personne au poste).
typedef SeatView = (ChairPosition, ScreenMode, SeatPresence?);

/// Ce qu'on voit à un poste, selon qu'il a un agent ([occupied]) et l'état
/// de celui-ci. Un poste vacant reste un bureau vide : chaise rentrée,
/// écran éteint.
SeatView seatViewOf({required bool occupied, required SeatState state}) {
  if (!occupied) {
    return (ChairPosition.tucked, ScreenMode.off, null);
  }
  return switch (state.presence) {
    SeatPresence.seated => (
      ChairPosition.occupied,
      state.screen,
      SeatPresence.seated,
    ),
    SeatPresence.standing => (
      ChairPosition.pulledOut,
      state.screen,
      SeatPresence.standing,
    ),
    // Parti : dessiné en direct ailleurs (café, couloir).
    SeatPresence.away => (ChairPosition.pulledOut, state.screen, null),
  };
}

/// État visible d'un poste occupé.
class SeatState {
  const SeatState({
    this.presence = SeatPresence.seated,
    this.screen = ScreenMode.code,
    this.mood = PersonMood.neutral,
    this.holdsPaper = false,
  });

  final SeatPresence presence;
  final ScreenMode screen;

  /// Expression, visible de près (niveau ×3).
  final PersonMood mood;

  /// Debout avec une feuille à la main (limite de coût : la note).
  final bool holdsPaper;
}
