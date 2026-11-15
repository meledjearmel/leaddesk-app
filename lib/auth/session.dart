import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';

/// Session du CEO sur ce poste : adresse du serveur, jeton de l'appareil et
/// compte (D-017).
class Session {
  const Session({
    required this.baseUrl,
    required this.token,
    required this.userName,
    required this.email,
    this.companyName,
  });

  factory Session.fromJson(Map<String, Object?> json) => Session(
    baseUrl: Uri.parse(json['base_url']! as String),
    token: json['token']! as String,
    userName: json['user_name']! as String,
    email: json['email']! as String,
    companyName: json['company_name'] as String?,
  );

  final Uri baseUrl;
  final String token;
  final String userName;
  final String email;

  /// Entreprise du compte ; `null` tant qu'elle n'est pas créée.
  final String? companyName;

  ApiConfig get config => ApiConfig(baseUrl: baseUrl, token: token);

  Session withCompany(String name) => Session(
    baseUrl: baseUrl,
    token: token,
    userName: userName,
    email: email,
    companyName: name,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'base_url': baseUrl.toString(),
    'token': token,
    'user_name': userName,
    'email': email,
    'company_name': companyName,
  };
}

/// Où la session est gardée entre deux lancements.
abstract interface class SessionStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

/// Stockage sécurisé de Windows (Credential Manager, chiffré par le
/// système) : le jeton n'est jamais écrit en clair sur le disque (D-017).
class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'leaddesk.session';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) {
        return null;
      }
      return Session.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Exception {
      // Session illisible (format ancien, stockage indisponible) : on
      // repart de l'écran de connexion.
      return null;
    }
  }

  @override
  Future<void> write(Session session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Stockage en mémoire, pour les tests et la démonstration.
class MemorySessionStore implements SessionStore {
  MemorySessionStore([this._session]);

  Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
