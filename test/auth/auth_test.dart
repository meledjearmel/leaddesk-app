import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/app/theme.dart';
import 'package:leaddesk_app/auth/app_gate.dart';
import 'package:leaddesk_app/auth/auth_screens.dart';
import 'package:leaddesk_app/auth/auth_service.dart';
import 'package:leaddesk_app/auth/session.dart';
import 'package:leaddesk_app/live_office/live_office_screen.dart';

final Uri _base = Uri.parse('https://api.test/api/v1/');

Map<String, Object?> _user({String? company}) => <String, Object?>{
  'id': 1,
  'name': 'Armel Exemple',
  'email': 'ceo@exemple.test',
  'company': company == null
      ? null
      : <String, Object?>{'id': 3, 'name': company},
};

/// Faux serveur : identifiants `ceo@exemple.test` / `secret`.
MockClient _server({
  String? company,
  List<String>? calls,
  int officeStatus = 404,
}) => MockClient((request) async {
  final path = request.url.path.replaceFirst('/api/v1/', '');
  calls?.add(
    '${request.method} $path ${request.headers['Authorization'] ?? '-'}',
  );
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: <String, String>{'content-type': 'application/json'},
  );
  switch ((request.method, path)) {
    case ('POST', 'auth/token'):
      final body = jsonDecode(request.body) as Map<String, Object?>;
      if (body['email'] == 'ceo@exemple.test' && body['password'] == 'secret') {
        return json(<String, Object?>{
          'token': '1|abc',
          'user': _user(company: company),
        });
      }
      return json(<String, Object?>{
        'message': 'Identifiants refusés.',
        'errors': <String, Object?>{
          'email': <String>[
            'Ces identifiants ne correspondent à aucun compte.',
          ],
        },
      }, 422);
    case ('POST', 'auth/register'):
      final body = jsonDecode(request.body) as Map<String, Object?>;
      if (body['email'] == 'pris@exemple.test') {
        return json(<String, Object?>{
          'message': 'Invalide.',
          'errors': <String, Object?>{
            'email': <String>['Cette adresse e-mail est déjà utilisée.'],
          },
        }, 422);
      }
      return json(<String, Object?>{
        'token': '2|new',
        'user': <String, Object?>{
          'id': 2,
          'name': body['name'],
          'email': body['email'],
          'company': null,
        },
      }, 201);
    case ('POST', 'company'):
      final body = jsonDecode(request.body) as Map<String, Object?>;
      return json(<String, Object?>{
        'data': <String, Object?>{'id': 3, 'name': body['name']},
      }, 201);
    case ('DELETE', 'auth/token'):
      return http.Response('', 204);
  }
  return json(<String, Object?>{'message': 'Non authentifié.'}, officeStatus);
});

Future<void> _pumpGate(
  WidgetTester tester, {
  required SessionStore store,
  required AuthService auth,
  http.Client? office,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLeadDeskTheme(),
        home: AppGate(store: store, auth: auth, httpClient: office),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  await tester.pump();
}

void main() {
  group('AuthService', () {
    test('l\'adresse du serveur est complétée', () {
      expect(
        AuthService.normalizeBaseUrl('leaddesk.exemple.com').toString(),
        'https://leaddesk.exemple.com/api/v1/',
      );
      expect(
        AuthService.normalizeBaseUrl('http://leaddesk-api.test:8000/')
            .toString(),
        'http://leaddesk-api.test:8000/api/v1/',
      );
      expect(
        AuthService.normalizeBaseUrl('https://x.test/api/v1').toString(),
        'https://x.test/api/v1/',
      );
      expect(AuthService.normalizeBaseUrl('  '), isNull);
    });

    test(
      'se connecter donne une session avec le jeton de l\'appareil',
      () async {
        final calls = <String>[];
        final auth = AuthService(
          httpClient: _server(company: 'Atelier Nord', calls: calls),
          deviceName: 'Poste test',
        );

        final session = await auth.signIn(
          baseUrl: _base,
          email: ' ceo@exemple.test ',
          password: 'secret',
        );

        expect(session.token, '1|abc');
        expect(session.userName, 'Armel Exemple');
        expect(session.companyName, 'Atelier Nord');
        // Pas de jeton envoyé pour se connecter.
        expect(calls, <String>['POST auth/token -']);
      },
    );

    test('des identifiants refusés donnent un message clair', () async {
      final auth = AuthService(httpClient: _server());

      await expectLater(
        auth.signIn(baseUrl: _base, email: 'x@y.z', password: 'non'),
        throwsA(
          isA<ApiException>().having(
            describeError,
            'message',
            'Ces identifiants ne correspondent à aucun compte.',
          ),
        ),
      );
    });

    test('créer l\'entreprise puis se déconnecter', () async {
      final calls = <String>[];
      final auth = AuthService(httpClient: _server(calls: calls));
      final session = await auth.signIn(
        baseUrl: _base,
        email: 'ceo@exemple.test',
        password: 'secret',
      );
      expect(session.companyName, isNull);

      final ready = await auth.createCompany(
        session,
        name: ' Atelier Nord ',
        template: CompanyTemplate.blank,
      );
      await auth.signOut(ready);

      expect(ready.companyName, 'Atelier Nord');
      expect(calls.skip(1), <String>[
        'POST company Bearer 1|abc',
        'DELETE auth/token Bearer 1|abc',
      ]);
    });

    test('D-019 : créer un compte ouvre une session sans entreprise', () async {
      final calls = <String>[];
      final auth = AuthService(httpClient: _server(calls: calls));

      final session = await auth.signUp(
        baseUrl: _base,
        name: ' Awa Kouassi ',
        email: 'awa@exemple.test',
        password: 'motdepasse',
        confirmation: 'motdepasse',
      );

      expect(session.token, '2|new');
      expect(session.userName, 'Awa Kouassi');
      expect(session.companyName, isNull);
      expect(calls, <String>['POST auth/register -']);
    });

    test('un e-mail déjà pris donne un message clair', () async {
      final auth = AuthService(httpClient: _server());

      await expectLater(
        auth.signUp(
          baseUrl: _base,
          name: 'A',
          email: 'pris@exemple.test',
          password: 'x',
          confirmation: 'x',
        ),
        throwsA(
          isA<ApiException>().having(
            describeError,
            'message',
            'Cette adresse e-mail est déjà utilisée.',
          ),
        ),
      );
    });

    test('la session se relit telle qu\'elle a été écrite', () async {
      final store = MemorySessionStore();
      final session = Session(
        baseUrl: _base,
        token: 't',
        userName: 'A',
        email: 'a@b.c',
        companyName: 'C',
      );
      await store.write(Session.fromJson(session.toJson()));

      final read = await store.read();
      expect(read!.toJson(), session.toJson());
    });
  });

  group('AppGate', () {
    testWidgets('sans session, l\'écran de connexion s\'affiche', (
      tester,
    ) async {
      await _pumpGate(
        tester,
        store: MemorySessionStore(),
        auth: AuthService(httpClient: _server()),
      );

      expect(find.text('Connexion'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('D-017 : se connecter ouvre le bureau et garde la session', (
      tester,
    ) async {
      final store = MemorySessionStore();
      await _pumpGate(
        tester,
        store: store,
        auth: AuthService(httpClient: _server(company: 'Atelier Nord')),
        office: _server(company: 'Atelier Nord'),
      );

      await tester.enterText(find.byType(TextField).at(0), 'api.test');
      await tester.enterText(find.byType(TextField).at(1), 'ceo@exemple.test');
      await tester.enterText(find.byType(TextField).at(2), 'secret');
      await tester.runAsync(() async {
        await tester.tap(find.text('Se connecter'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.byType(LiveOfficeScreen), findsOneWidget);
      final saved = await store.read();
      expect(saved!.token, '1|abc');
      expect(saved.baseUrl.toString(), 'https://api.test/api/v1/');
    });

    testWidgets('un compte sans entreprise la crée d\'abord', (tester) async {
      final store = MemorySessionStore(
        Session(
          baseUrl: _base,
          token: '1|abc',
          userName: 'Armel Exemple',
          email: 'x',
        ),
      );
      await _pumpGate(
        tester,
        store: store,
        auth: AuthService(httpClient: _server()),
        office: _server(),
      );

      expect(find.text('Bienvenue, Armel'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Atelier Nord');
      await tester.tap(find.text('Entreprise vierge'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Créer l\'entreprise'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.byType(LiveOfficeScreen), findsOneWidget);
      expect((await store.read())!.companyName, 'Atelier Nord');
    });

    testWidgets('un jeton refusé ramène à la connexion', (tester) async {
      final store = MemorySessionStore(
        Session(
          baseUrl: _base,
          token: 'revoque',
          userName: 'A',
          email: 'a',
          companyName: 'C',
        ),
      );
      await _pumpGate(
        tester,
        store: store,
        auth: AuthService(httpClient: _server()),
        office: _server(officeStatus: 401),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Connexion'), findsOneWidget);
      expect(await store.read(), isNull);
    });

    testWidgets('créer un compte mène à la création de l\'entreprise', (
      tester,
    ) async {
      final store = MemorySessionStore();
      await _pumpGate(
        tester,
        store: store,
        auth: AuthService(httpClient: _server()),
      );
      await tester.enterText(find.byType(TextField).at(0), 'api.test');
      await tester.tap(find.text('Créer un compte'));
      await tester.pump();

      expect(find.text('Créer le compte'), findsOneWidget);
      // L'adresse saisie est reprise.
      expect(find.text('api.test'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'Awa Kouassi');
      await tester.enterText(find.byType(TextField).at(2), 'awa@exemple.test');
      await tester.enterText(find.byType(TextField).at(3), 'motdepasse');
      await tester.enterText(find.byType(TextField).at(4), 'autre');
      await tester.tap(find.text('Créer le compte'));
      await tester.pump();
      expect(
        find.text('Les deux mots de passe ne sont pas identiques.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(4), 'motdepasse');
      await tester.runAsync(() async {
        await tester.tap(find.text('Créer le compte'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Bienvenue, Awa'), findsOneWidget);
      expect((await store.read())!.token, '2|new');
    });

    testWidgets('la démonstration s\'ouvre sans serveur', (tester) async {
      await _pumpGate(
        tester,
        store: MemorySessionStore(),
        auth: AuthService(httpClient: _server()),
      );

      await tester.tap(find.text('Voir la démonstration'));
      await tester.pump();

      expect(find.byType(LiveOfficeScreen), findsOneWidget);
      expect(find.byTooltip('Se déconnecter'), findsOneWidget);
    });
  });
}
