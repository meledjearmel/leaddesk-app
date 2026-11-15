import 'dart:io';

import 'package:path/path.dart' as p;

/// Accès refusé par le bac à sable (chemin hors du dossier autorisé, fichier
/// absent, trop gros…). Le message est renvoyé tel quel au modèle.
class SandboxViolation implements Exception {
  SandboxViolation(this.message);

  final String message;

  @override
  String toString() => 'SandboxViolation: $message';
}

/// Dossier autorisé d'un agent : toute lecture est confinée à ce dossier.
class AllowedFolder {
  AllowedFolder(String root, {this.maxBytes = 200 * 1024})
    : root = Directory(root).resolveSymbolicLinksSync();

  /// Chemin canonique du dossier autorisé (liens symboliques résolus).
  final String root;

  /// Taille maximale d'un fichier lisible, en octets.
  final int maxBytes;

  /// Chemin réel du fichier demandé, ou [SandboxViolation] s'il sort du
  /// dossier autorisé.
  String resolve(String requested) {
    final trimmed = requested.trim();
    if (trimmed.isEmpty) {
      throw SandboxViolation('Chemin vide.');
    }
    if (p.isAbsolute(trimmed) || trimmed.startsWith(RegExp(r'[\\/]'))) {
      throw SandboxViolation(
        'Chemin absolu refusé : donne un chemin relatif au dossier autorisé.',
      );
    }
    final candidate = p.normalize(p.join(root, trimmed));
    if (!_isInside(candidate)) {
      throw SandboxViolation('Chemin hors du dossier autorisé : $requested');
    }
    final file = File(candidate);
    if (!file.existsSync()) {
      throw SandboxViolation('Fichier introuvable : $requested');
    }
    // Un lien symbolique placé dans le dossier ne doit pas permettre d'en
    // sortir : on vérifie aussi le chemin réel.
    final real = file.resolveSymbolicLinksSync();
    if (!_isInside(real)) {
      throw SandboxViolation('Chemin hors du dossier autorisé : $requested');
    }
    return real;
  }

  bool _isInside(String path) => path == root || p.isWithin(root, path);

  /// Contenu texte du fichier demandé.
  String readText(String requested) {
    final file = File(resolve(requested));
    final length = file.lengthSync();
    if (length > maxBytes) {
      throw SandboxViolation(
        'Fichier trop volumineux ($length octets, maximum $maxBytes).',
      );
    }
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      throw SandboxViolation("Ce fichier n'est pas un texte lisible.");
    }
  }
}
