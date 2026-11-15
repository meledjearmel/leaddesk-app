import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_client.dart';

/// Changement annoncé par le serveur (`company.changed`) : seulement de quoi
/// savoir quoi recharger, jamais de donnée métier.
class CompanyChange {
  const CompanyChange({
    required this.id,
    required this.event,
    this.subjectId,
    this.actorType,
  });

  factory CompanyChange.fromJson(Map<String, Object?> json) => CompanyChange(
    id: (json['id'] as num?)?.toInt() ?? 0,
    event: json['event'] as String? ?? '',
    subjectId: (json['subject_id'] as num?)?.toInt(),
    actorType: json['actor_type'] as String?,
  );

  final int id;

  /// `<ressource>.<verbe>`, par exemple `office_plan.created`.
  final String event;
  final int? subjectId;
  final String? actorType;
}

/// État de la connexion au temps réel.
enum RealtimeStatus { idle, connecting, live, offline }

/// Prise WebSocket minimale, remplaçable dans les tests.
abstract interface class RealtimeSocket {
  Stream<Object?> get messages;
  void send(String message);
  Future<void> close();
}

typedef RealtimeConnector = Future<RealtimeSocket> Function(Uri uri);

class _IoSocket implements RealtimeSocket {
  _IoSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<Object?> get messages => _socket;

  @override
  void send(String message) => _socket.add(message);

  @override
  Future<void> close() => _socket.close();
}

Future<RealtimeSocket> _connect(Uri uri) async =>
    _IoSocket(await WebSocket.connect(uri.toString()));

/// Client Reverb (protocole Pusher) du canal privé de l'entreprise (D-020).
///
/// 1. `GET /realtime` donne l'adresse, la clé publique et le canal ;
/// 2. connexion WebSocket, puis `POST /broadcasting/auth` avec le jeton ;
/// 3. abonnement, puis chaque `company.changed` est publié sur [changes].
///
/// Reconnexion automatique, de plus en plus espacée (jusqu'à 30 s).
class RealtimeClient {
  RealtimeClient(this.api, {RealtimeConnector? connector})
    : _connector = connector ?? _connect;

  final ApiClient api;
  final RealtimeConnector _connector;

  final StreamController<CompanyChange> _changes =
      StreamController<CompanyChange>.broadcast();
  final StreamController<RealtimeStatus> _statuses =
      StreamController<RealtimeStatus>.broadcast();

  RealtimeSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _retry;
  Timer? _ping;
  int _attempt = 0;
  bool _stopped = true;
  String? _channel;
  RealtimeStatus _status = RealtimeStatus.idle;

  Stream<CompanyChange> get changes => _changes.stream;
  Stream<RealtimeStatus> get statuses => _statuses.stream;
  RealtimeStatus get status => _status;

  /// Délai avant la tentative suivante : 1, 2, 4, 8… jusqu'à 30 secondes.
  static Duration backoff(int attempt) =>
      Duration(seconds: attempt <= 0 ? 1 : (1 << attempt).clamp(1, 30));

  void _setStatus(RealtimeStatus status) {
    if (_status == status) {
      return;
    }
    _status = status;
    if (!_statuses.isClosed) {
      _statuses.add(status);
    }
  }

  Future<void> start() async {
    if (!_stopped) {
      return;
    }
    _stopped = false;
    await _open();
  }

  Future<void> _open() async {
    if (_stopped) {
      return;
    }
    _setStatus(RealtimeStatus.connecting);
    try {
      final info = await api.get('realtime');
      if (info is! Map<String, Object?>) {
        throw const ApiException(500, 'Temps réel indisponible.');
      }
      final key = info['key'] as String?;
      final host = info['host'] as String?;
      if (key == null || key.isEmpty || host == null || host.isEmpty) {
        throw const ApiException(503, 'Temps réel non configuré.');
      }
      _channel = info['channel'] as String?;
      final uri = Uri(
        scheme: info['scheme'] as String? ?? 'wss',
        host: host,
        port: (info['port'] as num?)?.toInt(),
        path: '/app/$key',
        queryParameters: <String, String>{
          'protocol': '7',
          'client': 'leaddesk-dart',
          'version': '1.0',
        },
      );
      final socket = await _connector(uri);
      if (_stopped) {
        await socket.close();
        return;
      }
      _socket = socket;
      _subscription = socket.messages.listen(
        (message) => unawaited(_onMessage(message)),
        onDone: _onClosed,
        onError: (Object _) => _onClosed(),
        cancelOnError: true,
      );
    } on Object {
      _scheduleRetry();
    }
  }

  Future<void> _onMessage(Object? raw) async {
    if (raw is! String) {
      return;
    }
    final Map<String, Object?> frame;
    try {
      frame = jsonDecode(raw) as Map<String, Object?>;
    } on FormatException {
      return;
    }
    final event = frame['event'];
    final data = _decodeData(frame['data']);
    switch (event) {
      case 'pusher:connection_established':
        await _subscribe(data['socket_id'] as String?);
        final timeout = (data['activity_timeout'] as num?)?.toInt() ?? 30;
        _ping?.cancel();
        _ping = Timer.periodic(
          Duration(seconds: timeout),
          (_) => _send(<String, Object?>{'event': 'pusher:ping', 'data': {}}),
        );
      case 'pusher:ping':
        _send(<String, Object?>{'event': 'pusher:pong', 'data': {}});
      case 'pusher_internal:subscription_succeeded':
        _attempt = 0;
        _setStatus(RealtimeStatus.live);
      case 'pusher:error':
        // Erreur de protocole (clé, quota…) : on recommence plus tard.
        await _drop();
        _scheduleRetry();
      case 'company.changed' when frame['channel'] == _channel:
        if (!_changes.isClosed) {
          _changes.add(CompanyChange.fromJson(data));
        }
    }
  }

  static Map<String, Object?> _decodeData(Object? data) {
    if (data is Map<String, Object?>) {
      return data;
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, Object?>) {
          return decoded;
        }
      } on FormatException {
        return const <String, Object?>{};
      }
    }
    return const <String, Object?>{};
  }

  Future<void> _subscribe(String? socketId) async {
    final channel = _channel;
    if (socketId == null || channel == null) {
      return;
    }
    try {
      final auth = await api.postRaw('broadcasting/auth', <String, Object?>{
        'socket_id': socketId,
        'channel_name': channel,
      });
      _send(<String, Object?>{
        'event': 'pusher:subscribe',
        'data': <String, Object?>{'auth': auth['auth'], 'channel': channel},
      });
    } on Object {
      await _drop();
      _scheduleRetry();
    }
  }

  void _send(Map<String, Object?> frame) {
    try {
      _socket?.send(jsonEncode(frame));
    } on Object {
      // Prise fermée : la reconnexion s'en occupe.
    }
  }

  void _onClosed() {
    unawaited(_drop());
    _scheduleRetry();
  }

  Future<void> _drop() async {
    _ping?.cancel();
    _ping = null;
    final socket = _socket;
    _socket = null;
    await _subscription?.cancel();
    _subscription = null;
    await socket?.close();
  }

  void _scheduleRetry() {
    if (_stopped) {
      return;
    }
    _setStatus(RealtimeStatus.offline);
    _retry?.cancel();
    _retry = Timer(backoff(_attempt++), () => unawaited(_open()));
  }

  Future<void> stop() async {
    _stopped = true;
    _retry?.cancel();
    _retry = null;
    await _drop();
    _setStatus(RealtimeStatus.idle);
  }

  Future<void> dispose() async {
    await stop();
    await _changes.close();
    await _statuses.close();
  }
}
