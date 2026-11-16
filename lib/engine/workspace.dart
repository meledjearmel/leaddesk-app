import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Refus d'accès à un chemin hors des dossiers autorisés.
class WorkspaceException implements Exception {
  const WorkspaceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Dossiers autorisés d'un projet sur ce poste (D-031 de l'API) : tout chemin
/// demandé par un agent est résolu dans l'un d'eux, liens symboliques
/// compris ; rien n'en sort (D-023).
class Workspace {
  Workspace(Map<String, String> folders)
    : folders = <String, String>{
        for (final MapEntry(:key, :value) in folders.entries)
          key: p.normalize(p.absolute(value)),
      };

  /// Nature (`documentation`, `code`) → chemin absolu.
  final Map<String, String> folders;

  /// Taille maximale lue d'un fichier (les plus gros sont tronqués, avec
  /// mention).
  static const int maxReadBytes = 200 * 1024;

  /// Nombre maximal d'entrées listées.
  static const int maxEntries = 500;

  bool get isEmpty => folders.isEmpty;

  /// Chemin absolu d'un chemin relatif `nature/chemin`, vérifié.
  String resolve(String relative, {bool mustExist = true}) {
    final cleaned = relative.replaceAll('\\', '/').trim();
    final slash = cleaned.indexOf('/');
    final kind = slash < 0 ? cleaned : cleaned.substring(0, slash);
    final rest = slash < 0 ? '' : cleaned.substring(slash + 1);
    final root = folders[kind];
    if (root == null) {
      throw WorkspaceException(
        'Dossier inconnu « $kind ». Dossiers autorisés : '
        '${folders.keys.join(', ')}.',
      );
    }
    if (p.isAbsolute(rest)) {
      throw const WorkspaceException('Chemin absolu refusé.');
    }
    final full = p.normalize(p.join(root, rest));
    if (!_inside(root, full)) {
      throw const WorkspaceException('Chemin hors du dossier autorisé.');
    }
    // Un lien symbolique ne doit pas mener ailleurs.
    final probe = mustExist ? full : _existingAncestor(full);
    if (probe != null &&
        FileSystemEntity.typeSync(probe) != FileSystemEntityType.notFound) {
      final real = File(probe).resolveSymbolicLinksSync();
      final realRoot = Directory(root).existsSync()
          ? Directory(root).resolveSymbolicLinksSync()
          : root;
      if (!_inside(realRoot, real)) {
        throw const WorkspaceException('Chemin hors du dossier autorisé.');
      }
    } else if (mustExist) {
      throw WorkspaceException('« $relative » n\'existe pas.');
    }
    return full;
  }

  static bool _inside(String root, String path) =>
      p.equals(root, path) || p.isWithin(root, path);

  static String? _existingAncestor(String path) {
    var current = path;
    while (FileSystemEntity.typeSync(current) ==
        FileSystemEntityType.notFound) {
      final parent = p.dirname(current);
      if (parent == current) {
        return null;
      }
      current = parent;
    }
    return current;
  }

  /// Contenu d'un dossier, en chemins relatifs `nature/…`.
  String list(String relative) {
    final full = resolve(relative.isEmpty ? folders.keys.first : relative);
    final dir = Directory(full);
    if (!dir.existsSync()) {
      throw WorkspaceException('« $relative » n\'est pas un dossier.');
    }
    final kind = relative.replaceAll('\\', '/').split('/').first;
    final root = folders[kind]!;
    final lines = <String>[];
    for (final entity in dir.listSync(followLinks: false)) {
      if (lines.length >= maxEntries) {
        lines.add('… (liste tronquée à $maxEntries entrées)');
        break;
      }
      final rel = p.posix.joinAll(<String>[
        kind,
        ...p.split(p.relative(entity.path, from: root)),
      ]);
      lines.add(entity is Directory ? '$rel/' : rel);
    }
    lines.sort();
    return lines.isEmpty ? '(dossier vide)' : lines.join('\n');
  }

  String read(String relative) {
    final file = File(resolve(relative));
    if (!file.existsSync()) {
      throw WorkspaceException('« $relative » n\'est pas un fichier.');
    }
    final bytes = file.readAsBytesSync();
    final slice = bytes.length > maxReadBytes
        ? bytes.sublist(0, maxReadBytes)
        : bytes;
    final decoded = utf8.decode(slice, allowMalformed: true);
    return bytes.length > maxReadBytes
        ? '$decoded\n… (fichier tronqué à ${maxReadBytes ~/ 1024} Ko)'
        : decoded;
  }

  /// Écrit un fichier (dossiers intermédiaires créés).
  String write(String relative, String content) {
    final full = resolve(relative, mustExist: false);
    final file = File(full)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
    return '${file.lengthSync()} octets écrits dans « $relative ».';
  }
}
