import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Erreur d'un appel à l'API LeadDesk.
class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Session ouverte auprès du serveur : jeton Sanctum et canal privé du compte.
class ApiSession {
  const ApiSession({
    required this.baseUrl,
    required this.token,
    required this.userId,
    required this.channel,
  });

  final Uri baseUrl;
  final String token;
  final int userId;
  final String channel;

  Map<String, String> get headers => <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

/// Appels HTTP du prototype (routes `/api/prototypes/realtime`).
class PrototypeApi {
  PrototypeApi(this.baseUrl, {http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;

  Uri _url(String path) => baseUrl.resolve(path);

  Map<String, Object?> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  Future<ApiSession> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final response = await _client.post(
      _url('/api/prototypes/realtime/token'),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    );
    final body = _decode(response);
    final user = body['user']! as Map<String, Object?>;
    return ApiSession(
      baseUrl: baseUrl,
      token: body['token']! as String,
      userId: user['id']! as int,
      channel: body['channel']! as String,
    );
  }

  /// Demande au serveur de diffuser un événement sur le canal du compte.
  Future<DateTime> ping(ApiSession session, String message) async {
    final response = await _client.post(
      _url('/api/prototypes/realtime/ping'),
      headers: session.headers,
      body: jsonEncode(<String, String>{'message': message}),
    );
    return DateTime.parse(_decode(response)['sent_at']! as String);
  }

  /// Signature d'abonnement à un canal privé (`POST /api/broadcasting/auth`).
  Future<String> authorizeChannel(
    ApiSession session, {
    required String socketId,
    required String channelName,
  }) async {
    final response = await _client.post(
      _url('/api/broadcasting/auth'),
      headers: session.headers,
      body: jsonEncode(<String, String>{
        'socket_id': socketId,
        'channel_name': channelName,
      }),
    );
    return _decode(response)['auth']! as String;
  }

  void close() => _client.close();
}

/// Événement reçu de Reverb.
class ReverbEvent {
  const ReverbEvent({required this.name, required this.channel, this.data});

  final String name;
  final String? channel;

  /// Charge utile décodée (Reverb l'envoie en JSON dans une chaîne).
  final Object? data;

  /// Décode une trame du protocole Pusher.
  static ReverbEvent parse(String frame) {
    final message = jsonDecode(frame) as Map<String, Object?>;
    final raw = message['data'];
    Object? data = raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        data = jsonDecode(raw);
      } on FormatException {
        data = raw;
      }
    }
    return ReverbEvent(
      name: message['event']! as String,
      channel: message['channel'] as String?,
      data: data,
    );
  }
}

/// Client minimal du protocole Pusher parlé par Reverb : connexion,
/// abonnement à un canal privé, réception des événements, réponse aux pings.
class ReverbClient {
  ReverbClient._(this._socket) {
    _subscription = _socket.listen(
      _onFrame,
      onDone: _events.close,
      onError: _events.addError,
    );
  }

  final WebSocket _socket;
  late final StreamSubscription<dynamic> _subscription;
  final StreamController<ReverbEvent> _events =
      StreamController<ReverbEvent>.broadcast();

  String? _socketId;

  /// Identifiant de connexion donné par Reverb, requis pour signer un canal.
  String get socketId => _socketId!;

  /// Tous les événements reçus, y compris ceux du protocole (`pusher:*`).
  Stream<ReverbEvent> get events => _events.stream;

  /// Adresse WebSocket d'une application Reverb.
  static Uri endpoint({
    required String host,
    required int port,
    required String appKey,
    bool secure = false,
  }) {
    return Uri(
      scheme: secure ? 'wss' : 'ws',
      host: host,
      port: port,
      path: '/app/$appKey',
      queryParameters: const <String, String>{
        'protocol': '7',
        'client': 'leaddesk-prototype',
        'version': '0.1',
      },
    );
  }

  static Future<ReverbClient> connect(
    Uri endpoint, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Fermé par ReverbClient.close().
    // ignore: close_sinks
    final socket = await WebSocket.connect(endpoint.toString())
        .timeout(timeout);
    final client = ReverbClient._(socket);
    final established = client.events
        .firstWhere((event) => event.name == 'pusher:connection_established')
        .timeout(timeout);
    final event = await established;
    final data = event.data! as Map<String, Object?>;
    client._socketId = data['socket_id']! as String;
    return client;
  }

  void _onFrame(dynamic frame) {
    if (frame is! String) {
      return;
    }
    final event = ReverbEvent.parse(frame);
    if (event.name == 'pusher:ping') {
      _send('pusher:pong', const <String, Object?>{});
    }
    _events.add(event);
  }

  void _send(String event, Map<String, Object?> data) {
    _socket.add(jsonEncode(<String, Object?>{'event': event, 'data': data}));
  }

  /// S'abonne au canal privé [channel] (sans le préfixe `private-`).
  ///
  /// [authorize] reçoit l'identifiant de connexion et le nom complet du canal,
  /// et renvoie la signature délivrée par le serveur.
  Future<Stream<ReverbEvent>> subscribePrivate(
    String channel, {
    required Future<String> Function(String socketId, String channelName)
    authorize,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final channelName = 'private-$channel';
    final auth = await authorize(socketId, channelName);
    final subscribed = events
        .firstWhere(
          (event) =>
              event.channel == channelName &&
              event.name == 'pusher_internal:subscription_succeeded',
        )
        .timeout(timeout);
    _send('pusher:subscribe', <String, Object?>{
      'channel': channelName,
      'auth': auth,
    });
    await subscribed;
    return events.where(
      (event) =>
          event.channel == channelName &&
          !event.name.startsWith('pusher_internal:') &&
          !event.name.startsWith('pusher:'),
    );
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _socket.close();
    await _events.close();
  }
}
