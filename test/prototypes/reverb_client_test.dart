import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../prototypes/realtime/reverb_client.dart';

/// Faux serveur local : API du prototype et protocole Pusher de Reverb.
class _FakeServer {
  _FakeServer(this._server);

  final HttpServer _server;
  WebSocket? socket;
  final List<Map<String, Object?>> received = <Map<String, Object?>>[];
  final List<Map<String, Object?>> authRequests = <Map<String, Object?>>[];
  String? lastAuthorization;

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeServer> start() async {
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = _FakeServer(http);
    unawaited(http.forEach(server._handle));
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path.startsWith('/app/')) {
      // Fermé par stop().
      // ignore: close_sinks
      final ws = await WebSocketTransformer.upgrade(request);
      socket = ws;
      _emit('pusher:connection_established', <String, Object?>{
        'socket_id': '42.4242',
        'activity_timeout': 30,
      });
      ws.listen((dynamic frame) {
        final message = jsonDecode(frame as String) as Map<String, Object?>;
        received.add(message);
        if (message['event'] == 'pusher:subscribe') {
          final data = message['data']! as Map<String, Object?>;
          _emit(
            'pusher_internal:subscription_succeeded',
            <String, Object?>{},
            channel: data['channel']! as String,
          );
        }
      });
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    final json = jsonDecode(body) as Map<String, Object?>;
    lastAuthorization = request.headers.value('authorization');
    Map<String, Object?> payload;
    var status = 200;
    switch (request.uri.path) {
      case '/api/prototypes/realtime/token':
        if (json['password'] == 'bon') {
          payload = <String, Object?>{
            'token': 'jeton-test',
            'user': <String, Object?>{'id': 7, 'name': 'Ada'},
            'channel': 'prototypes.user.7',
          };
        } else {
          status = 422;
          payload = <String, Object?>{'message': 'Identifiants incorrects.'};
        }
      case '/api/broadcasting/auth':
        authRequests.add(json);
        payload = <String, Object?>{'auth': 'cle:signature'};
      case '/api/prototypes/realtime/ping':
        payload = <String, Object?>{'sent_at': '2026-11-15T08:00:00.000Z'};
        emitOnChannel('private-prototypes.user.7', 'prototype.ping', json);
      default:
        status = 404;
        payload = <String, Object?>{};
    }
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    await request.response.close();
  }

  void _emit(String event, Map<String, Object?> data, {String? channel}) {
    socket!.add(
      jsonEncode(<String, Object?>{
        'event': event,
        'data': jsonEncode(data),
        'channel': ?channel,
      }),
    );
  }

  void emitOnChannel(String channel, String event, Map<String, Object?> data) {
    _emit(event, data, channel: channel);
  }

  void emitPing() => socket!.add(jsonEncode({'event': 'pusher:ping'}));

  Future<void> stop() async {
    await socket?.close();
    await _server.close(force: true);
  }
}

void main() {
  test('décode une trame dont la charge est du JSON dans une chaîne', () {
    final event = ReverbEvent.parse(
      '{"event":"prototype.ping","channel":"private-x",'
      r'"data":"{\"message\":\"bonjour\"}"}',
    );
    expect(event.name, 'prototype.ping');
    expect(event.channel, 'private-x');
    expect((event.data! as Map<String, Object?>)['message'], 'bonjour');
  });

  test('accepte une trame sans charge ni canal', () {
    final event = ReverbEvent.parse('{"event":"pusher:ping"}');
    expect(event.name, 'pusher:ping');
    expect(event.channel, isNull);
    expect(event.data, isNull);
  });

  test('construit l adresse WebSocket d une application Reverb', () {
    final uri = ReverbClient.endpoint(
      host: '127.0.0.1',
      port: 8080,
      appKey: 'cle',
    );
    expect(uri.scheme, 'ws');
    expect(uri.path, '/app/cle');
    expect(uri.queryParameters['protocol'], '7');
    expect(
      ReverbClient.endpoint(
        host: 'h',
        port: 443,
        appKey: 'k',
        secure: true,
      ).scheme,
      'wss',
    );
  });

  group('contre un faux serveur', () {
    late _FakeServer server;
    late PrototypeApi api;

    setUp(() async {
      server = await _FakeServer.start();
      api = PrototypeApi(server.baseUrl);
    });

    tearDown(() async {
      api.close();
      await server.stop();
    });

    test('un mauvais mot de passe lève une ApiException 422', () async {
      await expectLater(
        api.login(email: 'a@b.c', password: 'faux', deviceName: 'test'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
    });

    test('connexion, abonnement privé signé puis réception du ping', () async {
      final session = await api.login(
        email: 'a@b.c',
        password: 'bon',
        deviceName: 'test',
      );
      expect(session.token, 'jeton-test');
      expect(session.channel, 'prototypes.user.7');

      final reverb = await ReverbClient.connect(
        ReverbClient.endpoint(
          host: '127.0.0.1',
          port: server.baseUrl.port,
          appKey: 'cle',
        ),
      );
      expect(reverb.socketId, '42.4242');

      final events = await reverb.subscribePrivate(
        session.channel,
        authorize: (socketId, channelName) => api.authorizeChannel(
          session,
          socketId: socketId,
          channelName: channelName,
        ),
      );

      // La signature a été demandée avec le jeton, puis transmise à Reverb.
      expect(server.lastAuthorization, 'Bearer jeton-test');
      expect(server.authRequests.single, <String, Object?>{
        'socket_id': '42.4242',
        'channel_name': 'private-prototypes.user.7',
      });
      final subscribe = server.received.single;
      expect(subscribe['event'], 'pusher:subscribe');
      expect(subscribe['data'], <String, Object?>{
        'channel': 'private-prototypes.user.7',
        'auth': 'cle:signature',
      });

      final received = events.first;
      await api.ping(session, 'bonjour');
      final event = await received.timeout(const Duration(seconds: 5));
      expect(event.name, 'prototype.ping');
      expect((event.data! as Map<String, Object?>)['message'], 'bonjour');

      await reverb.close();
    });

    test('répond pong au ping du serveur', () async {
      final reverb = await ReverbClient.connect(
        ReverbClient.endpoint(
          host: '127.0.0.1',
          port: server.baseUrl.port,
          appKey: 'cle',
        ),
      );
      server.emitPing();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(server.received.single['event'], 'pusher:pong');
      await reverb.close();
    });
  });
}
