import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Réglages de connexion au serveur `leaddesk-api`.
///
/// En attendant l'écran de connexion, ils viennent de l'environnement
/// (`LD_API_URL`, `LD_API_TOKEN`), en `--dart-define` ou en variable du
/// système (D-014). Sans eux, l'application montre ses données de
/// démonstration.
class ApiConfig {
  const ApiConfig({required this.baseUrl, required this.token});

  /// Adresse de l'API, par exemple `https://leaddesk-api.test/api/v1`.
  final Uri baseUrl;

  /// Jeton Sanctum du CEO.
  final String token;

  static ApiConfig? fromEnvironment([Map<String, String>? environment]) {
    final env = environment ?? Platform.environment;
    const definedUrl = String.fromEnvironment('LD_API_URL');
    const definedToken = String.fromEnvironment('LD_API_TOKEN');
    final url = definedUrl.isNotEmpty ? definedUrl : env['LD_API_URL'];
    final token = definedToken.isNotEmpty ? definedToken : env['LD_API_TOKEN'];
    if (url == null || url.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    final base = Uri.tryParse(url.endsWith('/') ? url : '$url/');
    if (base == null || !base.hasScheme) {
      return null;
    }
    return ApiConfig(baseUrl: base, token: token);
  }
}

/// Erreur renvoyée par l'API, avec son message en français.
class ApiException implements Exception {
  const ApiException(this.status, this.message, [this.errors = const {}]);

  final int status;
  final String message;

  /// Erreurs de validation (422), par champ.
  final Map<String, List<String>> errors;

  @override
  String toString() => 'ApiException($status) : $message';
}

/// Client JSON minimal de l'API `/api/v1`.
class ApiClient {
  ApiClient(
    this.config, {
    http.Client? httpClient,
    this.extraHeaders = const <String, String>{},
  }) : _http = httpClient ?? http.Client();

  final ApiConfig config;
  final http.Client _http;

  /// En-têtes ajoutés à chaque requête (agent qui agit).
  final Map<String, String> extraHeaders;

  /// Même connexion, au nom d'un agent : tout ce qu'il fait est journalisé
  /// à son nom (RM-34). Ne pas fermer le client obtenu séparément.
  ApiClient asAgent(int agentId) => ApiClient(
    config,
    httpClient: _http,
    extraHeaders: <String, String>{'X-LeadDesk-Agent': '$agentId'},
  );

  /// Client HTTP partagé (pour les appels qui ne passent pas par `data`).
  http.Client get httpClient => _http;

  static const Duration timeout = Duration(seconds: 15);

  Map<String, String> get _headers => <String, String>{
    HttpHeaders.acceptHeader: 'application/json',
    HttpHeaders.contentTypeHeader: 'application/json',
    if (config.token.isNotEmpty)
      HttpHeaders.authorizationHeader: 'Bearer ${config.token}',
    ...extraHeaders,
  };

  /// En-têtes d'authentification, pour un appel fait à côté (MCP).
  Map<String, String> get headers => _headers;

  Uri _uri(String path) =>
      config.baseUrl.resolve(path.startsWith('/') ? path.substring(1) : path);

  /// Lit `data` d'une réponse JSON.
  Future<Object?> get(String path) async {
    final response = await _http
        .get(_uri(path), headers: _headers)
        .timeout(timeout);
    return _data(response);
  }

  Future<Object?> post(String path, [Map<String, Object?>? body]) async {
    final response = await _http
        .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(timeout);
    return _data(response);
  }

  Future<Object?> put(String path, Map<String, Object?> body) async {
    final response = await _http
        .put(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(timeout);
    return _data(response);
  }

  Future<Object?> patch(String path, Map<String, Object?> body) async {
    final response = await _http
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(timeout);
    return _data(response);
  }

  /// Réponse JSON complète, pour les routes qui n'enveloppent pas leur
  /// réponse dans `data` (jeton de connexion).
  Future<Map<String, Object?>> postRaw(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(timeout);
    _data(response);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, Object?> ? decoded : <String, Object?>{};
  }

  Future<void> delete(String path) async {
    final response = await _http
        .delete(_uri(path), headers: _headers)
        .timeout(timeout);
    _data(response);
  }

  /// Liste d'objets contenue dans `data`.
  Future<List<Map<String, Object?>>> getList(String path) async {
    final data = await get(path);
    if (data is! List<Object?>) {
      throw ApiException(500, 'Réponse inattendue pour $path.');
    }
    return data.cast<Map<String, Object?>>();
  }

  Object? _data(http.Response response) {
    final decoded = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    final json = decoded is Map<String, Object?>
        ? decoded
        : const <String, Object?>{};
    if (response.statusCode >= 400) {
      final errors = <String, List<String>>{
        if (json['errors'] case final Map<String, Object?> raw)
          for (final MapEntry(:key, :value) in raw.entries)
            if (value is List<Object?>) key: value.cast<String>(),
      };
      throw ApiException(
        response.statusCode,
        json['message'] as String? ?? 'Erreur ${response.statusCode}.',
        errors,
      );
    }
    return json['data'];
  }

  void close() => _http.close();
}
