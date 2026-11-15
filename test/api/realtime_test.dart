import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/api/realtime.dart';
import 'package:leaddesk_app/live_office/live_office_controller.dart';
import 'package:leaddesk_app/live_office/office_source.dart';

/// Fausse prise : ce que le serveur envoie, ce que le client écrit.
class FakeSocket implements RealtimeSocket {
  final StreamController<Object?> incoming = StreamController<Object?>();
  final List<Map<String, Object?>> sent = <Map<String, Object?>>[];
  bool closed = false;

  @override
  Stream<Object?> get messages => incoming.stream;

  @override
  void send(String message) =>
      sent.add(jsonDecode(message) as Map<String, Object?>);

  @override
  Future<void> close() async {
    closed = true;
    await incoming.close();
  }

  void serverSends(String event, Object data, {String? channel}) =>
      incoming.add(
        jsonEncode(<String, Object?>{
          'event': event,
          'channel': ?channel,
          'data': data is String ? data : jsonEncode(data),
        }),
      );
}

ApiClient _api(List<String> calls) => ApiClient(
  ApiConfig(baseUrl: Uri.parse('https://api.test/api/v1/'), token: 'jeton'),
  httpClient: MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/v1/', '');
    calls.add('${request.method} $path ${request.body}');
    final body = switch (path) {
      'realtime' => <String, Object?>{
        'data': <String, Object?>{
          'key': 'cle',
          'host': 'reverb.test',
          'port': 443,
          'scheme': 'wss',
          'channel': 'private-company.3',
          'event': 'company.changed',
        },
      },
      'broadcasting/auth' => <String, Object?>{'auth': 'cle:signature'},
      _ => <String, Object?>{'message': 'Introuvable.'},
    };
    return http.Response(
      jsonEncode(body),
      path == 'realtime' || path == 'broadcasting/auth' ? 200 : 404,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('les tentatives s\'espacent jusqu\'à 30 secondes', () {
    expect(
      <int>[for (var i = 0; i < 7; i++) RealtimeClient.backoff(i).inSeconds],
      <int>[1, 2, 4, 8, 16, 30, 30],
    );
  });

  test(
    'D-020 : connexion, autorisation du canal privé, puis changements',
    () async {
      final calls = <String>[];
      final socket = FakeSocket();
      Uri? connected;
      final client = RealtimeClient(
        _api(calls),
        connector: (uri) async {
          connected = uri;
          return socket;
        },
      );
      final changes = <CompanyChange>[];
      final statuses = <RealtimeStatus>[];
      client.changes.listen(changes.add);
      client.statuses.listen(statuses.add);

      await client.start();
      expect(
        connected.toString(),
        'wss://reverb.test:443/app/cle?protocol=7&client=leaddesk-dart&version=1.0',
      );

      socket.serverSends('pusher:connection_established', <String, Object?>{
        'socket_id': '123.456',
        'activity_timeout': 30,
      });
      await _settle();
      expect(calls.last, contains('broadcasting/auth'));
      expect(calls.last, contains('"socket_id":"123.456"'));
      expect(socket.sent.last, <String, Object?>{
        'event': 'pusher:subscribe',
        'data': <String, Object?>{
          'auth': 'cle:signature',
          'channel': 'private-company.3',
        },
      });

      socket.serverSends(
        'pusher_internal:subscription_succeeded',
        <String, Object?>{},
        channel: 'private-company.3',
      );
      socket
        ..serverSends('company.changed', <String, Object?>{
          'id': 42,
          'event': 'office_plan.created',
          'subject_id': 7,
        }, channel: 'private-company.3')
        // Un autre canal n'est jamais écouté.
        ..serverSends('company.changed', <String, Object?>{
          'id': 43,
          'event': 'unit.created',
        }, channel: 'private-company.9')
        ..serverSends('pusher:ping', <String, Object?>{});
      await _settle();

      expect(client.status, RealtimeStatus.live);
      expect(statuses, <RealtimeStatus>[
        RealtimeStatus.connecting,
        RealtimeStatus.live,
      ]);
      expect(changes.map((c) => c.event), <String>['office_plan.created']);
      expect(changes.single.subjectId, 7);
      expect(socket.sent.last['event'], 'pusher:pong');

      await client.dispose();
      expect(socket.closed, isTrue);
      expect(client.status, RealtimeStatus.idle);
    },
  );

  test('une connexion perdue passe hors ligne puis se rétablit', () async {
    final sockets = <FakeSocket>[];
    final client = RealtimeClient(
      _api(<String>[]),
      connector: (uri) async {
        final socket = FakeSocket();
        sockets.add(socket);
        return socket;
      },
    );

    await client.start();
    await sockets.single.incoming.close();
    await _settle();
    expect(client.status, RealtimeStatus.offline);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(sockets, hasLength(2));
    await client.dispose();
  });

  test('sans temps réel configuré, le client reste hors ligne', () async {
    final client = RealtimeClient(
      ApiClient(
        ApiConfig(baseUrl: Uri.parse('https://api.test/'), token: 't'),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{
              'data': <String, Object?>{'key': null, 'host': null},
            }),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      ),
      connector: (_) async => fail('aucune connexion attendue'),
    );

    await client.start();
    expect(client.status, RealtimeStatus.offline);
    await client.dispose();
  });

  group('LiveOfficeController et changements annoncés', () {
    test('un changement recharge le bureau, regroupé', () async {
      var loads = 0;
      final controller = LiveOfficeController();
      await controller.load(_CountingSource(() => loads++));
      expect(loads, 1);

      for (var i = 0; i < 3; i++) {
        controller.onRemoteChange(
          CompanyChange(id: i, event: 'office_plan.created'),
        );
      }
      await Future<void>.delayed(
        LiveOfficeController.remoteDebounce + const Duration(milliseconds: 50),
      );

      expect(loads, 2);
      controller.dispose();
    });

    test('suivi en direct coupé : rechargement à la reprise', () async {
      var loads = 0;
      final controller = LiveOfficeController();
      await controller.load(_CountingSource(() => loads++));
      controller
        ..toggleLive()
        ..onRemoteChange(const CompanyChange(id: 1, event: 'unit.created'));
      await Future<void>.delayed(
        LiveOfficeController.remoteDebounce + const Duration(milliseconds: 50),
      );
      expect(loads, 1);

      controller.toggleLive();
      await Future<void>.delayed(
        LiveOfficeController.remoteDebounce + const Duration(milliseconds: 50),
      );
      expect(loads, 2);
      controller.dispose();
    });
  });
}

class _CountingSource implements OfficeSource {
  _CountingSource(this.onLoad);

  final void Function() onLoad;

  @override
  Future<OfficeSnapshot> load() async {
    onLoad();
    return DemoOfficeSource.snapshot();
  }
}
