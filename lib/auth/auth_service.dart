import 'dart:io';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import 'session.dart';

/// Modèle de départ d'une nouvelle entreprise (RM-02, RM-04).
enum CompanyTemplate {
  studio(
    'studio',
    'Studio de développement',
    'Huit départements et leurs postes, prêts à adapter.',
  ),
  blank(
    'blank',
    'Entreprise vierge',
    'Seulement la RH et les Moyens généraux ; le reste est à créer.',
  );

  const CompanyTemplate(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;
}

/// Connexion du CEO à l'API (D-017).
class AuthService {
  AuthService({http.Client? httpClient, String? deviceName})
    : _http = httpClient,
      deviceName = deviceName ?? _defaultDeviceName();

  final http.Client? _http;

  /// Nom de l'appareil, visible dans la liste des jetons du compte.
  final String deviceName;

  static String _defaultDeviceName() {
    try {
      return 'LeadDesk · ${Platform.localHostname}';
    } on Exception {
      return 'LeadDesk';
    }
  }

  ApiClient _client(Uri baseUrl, [String token = '']) => ApiClient(
    ApiConfig(baseUrl: baseUrl, token: token),
    httpClient: _http,
  );

  /// Adresse normalisée (`https://hôte/api/v1/`), ou `null` si invalide.
  static Uri? normalizeBaseUrl(String input) {
    var text = input.trim();
    if (text.isEmpty) {
      return null;
    }
    if (!text.contains('://')) {
      text = 'https://$text';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (!path.endsWith('/api/v1')) {
      path = '$path/api/v1';
    }
    return uri.replace(path: '$path/');
  }

  /// Ouvre une session. Lève [ApiException] (422 si les identifiants sont
  /// refusés).
  Future<Session> signIn({
    required Uri baseUrl,
    required String email,
    required String password,
  }) async {
    final json = await _client(baseUrl).postRaw('auth/token', <String, Object?>{
      'email': email.trim(),
      'password': password,
      'device_name': deviceName,
    });
    final token = json['token'];
    final user = json['user'];
    if (token is! String || user is! Map<String, Object?>) {
      throw const ApiException(500, 'Réponse inattendue du serveur.');
    }
    final company = user['company'];
    return Session(
      baseUrl: baseUrl,
      token: token,
      userName: user['name'] as String? ?? '',
      email: user['email'] as String? ?? email.trim(),
      companyName: company is Map<String, Object?>
          ? company['name'] as String?
          : null,
    );
  }

  /// Crée l'entreprise du compte (RM-01 : une seule par compte).
  Future<Session> createCompany(
    Session session, {
    required String name,
    required CompanyTemplate template,
  }) async {
    final data = await _client(session.baseUrl, session.token).post(
      'company',
      <String, Object?>{'name': name.trim(), 'template': template.value},
    );
    final created = data is Map<String, Object?>
        ? data['name'] as String?
        : null;
    return session.withCompany(created ?? name.trim());
  }

  /// Révoque le jeton de cet appareil. Une erreur réseau n'empêche pas de se
  /// déconnecter localement.
  Future<void> signOut(Session session) async {
    try {
      await _client(session.baseUrl, session.token).delete('auth/token');
    } on Exception {
      // Le jeton reste valable sur le serveur ; il sera révocable depuis le
      // compte.
    }
  }
}
