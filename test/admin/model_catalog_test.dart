import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/admin/admin_controller.dart';
import 'package:leaddesk_app/admin/model_catalog.dart';
import 'package:leaddesk_app/engine/host.dart';

import '../support/admin_fakes.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

void main() {
  test('Anthropic : clé en en-tête et pages suivies', () async {
    final seen = <http.Request>[];
    final catalog = ModelCatalog(
      MockClient((request) async {
        seen.add(request);
        return request.url.queryParameters['after_id'] == null
            ? _json(<String, Object?>{
                'data': <Object?>[
                  <String, Object?>{
                    'id': 'claude-opus-5-5',
                    'display_name': 'Claude Opus 5.5',
                  },
                ],
                'has_more': true,
                'last_id': 'claude-opus-5-5',
              })
            : _json(<String, Object?>{
                'data': <Object?>[
                  <String, Object?>{'id': 'claude-haiku-5-5'},
                ],
                'has_more': false,
              });
      }),
    );

    final models = await catalog.fetch(
      driver: 'anthropic',
      providerName: 'Anthropic',
      key: 'sk-ant-test',
    );

    expect(models.map((m) => m.identifier), <String>[
      'claude-haiku-5-5',
      'claude-opus-5-5',
    ]);
    expect(models.last.label, 'Claude Opus 5.5');
    expect(seen.first.url.host, 'api.anthropic.com');
    expect(seen.first.headers['x-api-key'], 'sk-ant-test');
    expect(seen.last.url.queryParameters['after_id'], 'claude-opus-5-5');
  });

  test('Google : seuls les modèles qui génèrent du texte', () async {
    final catalog = ModelCatalog(
      MockClient(
        (request) async => _json(<String, Object?>{
          'models': <Object?>[
            <String, Object?>{
              'name': 'models/gemini-x',
              'displayName': 'Gemini X',
              'supportedGenerationMethods': <String>['generateContent'],
            },
            <String, Object?>{
              'name': 'models/embedding-1',
              'supportedGenerationMethods': <String>['embedContent'],
            },
          ],
        }),
      ),
    );

    final models = await catalog.fetch(
      driver: 'google',
      providerName: 'Google AI',
      key: 'AIza-test',
    );

    expect(models.single.identifier, 'gemini-x');
  });

  test(
    'compatibles OpenAI : liste enveloppée ou nue, adresse propre',
    () async {
      final urls = <String>[];
      final catalog = ModelCatalog(
        MockClient((request) async {
          urls.add(request.url.toString());
          expect(request.headers['Authorization'], 'Bearer k');
          return request.url.host == 'api.together.xyz'
              ? _json(<Object?>[
                  <String, Object?>{'id': 'llama-x'},
                ])
              : _json(<String, Object?>{
                  'data': <Object?>[
                    <String, Object?>{'id': 'gpt-x'},
                    <String, Object?>{'id': 'gpt-x'},
                  ],
                });
        }),
      );

      expect(
        (await catalog.fetch(
          driver: 'openai',
          providerName: 'O',
          key: 'k',
        )).single.identifier,
        'gpt-x',
      );
      expect(
        (await catalog.fetch(
          driver: 'together',
          providerName: 'T',
          key: 'k',
        )).single.identifier,
        'llama-x',
      );
      await catalog.fetch(
        driver: 'freebuff',
        providerName: 'F',
        key: 'k',
        baseUrl: 'https://llm.example.com/v1/',
      );
      expect(urls.last, 'https://llm.example.com/v1/models');
    },
  );

  test('clé refusée : message clair, sans la clé', () async {
    final catalog = ModelCatalog(
      MockClient((_) async => _json(<String, Object?>{'error': 'x'}, 401)),
    );

    await expectLater(
      catalog.fetch(driver: 'openai', providerName: 'OpenAI', key: 'sk-secret'),
      throwsA(
        isA<CatalogException>()
            .having((e) => e.message, 'message', contains('Clé refusée'))
            .having((e) => e.message, 'message', isNot(contains('sk-secret'))),
      ),
    );
    expect(ModelCatalog.supports('anyrouter', null), isFalse);
    expect(ModelCatalog.supports('anyrouter', 'https://a.test/v1'), isTrue);
  });

  test('import : clé locale, modèles déjà présents ignorés', () async {
    final server = FakeAdminServer();
    final vault = MemoryVault();
    final admin = AdminController(
      server.api(),
      keys: ProviderKeys(vault),
      catalog: ModelCatalog(
        MockClient(
          (_) async => _json(<String, Object?>{
            'data': <Object?>[
              <String, Object?>{'id': 'claude-opus-5-5'},
              <String, Object?>{
                'id': 'claude-sonnet-5-5',
                'display_name': 'Claude Sonnet 5.5',
              },
            ],
            'has_more': false,
          }),
        ),
      ),
    );
    await admin.load();
    final provider = admin.provider(50)!;

    await admin.fetchRemoteModels(provider);
    expect(admin.error, contains('Enregistrez d\'abord la clé'));

    await admin.setProviderKey('anthropic', 'sk-ant-local-9z8y');
    expect(admin.keyMasks['anthropic'], '…9z8y');
    // La clé ne part jamais vers le serveur LeadDesk.
    expect(
      server.calls.any((c) => jsonEncode(c.$2).contains('sk-ant')),
      isFalse,
    );

    await admin.fetchRemoteModels(provider);
    expect(admin.remoteModels, hasLength(2));

    await admin.importModels(50, admin.remoteModels!);
    expect(server.writes, <String>['POST ai-providers/50/models']);
    expect(admin.notice, '1 modèle importé.');
    expect(
      admin.provider(50)!.models.map((m) => m.displayName),
      contains('Claude Sonnet 5.5'),
    );
    admin.dispose();
  });
}
