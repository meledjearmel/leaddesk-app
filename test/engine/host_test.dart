import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leaddesk_app/api/api_client.dart';
import 'package:leaddesk_app/engine/host.dart';

void main() {
  test('la clé Anthropic reste dans le coffre local', () async {
    final vault = MemoryVault();
    final keys = ProviderKeys(vault);

    expect(await keys.anthropic(), isNull);
    await keys.setAnthropic('  sk-ant-test-a1b2  ');
    expect(await keys.anthropic(), 'sk-ant-test-a1b2');
    expect(ProviderKeys.mask('sk-ant-test-a1b2'), '…a1b2');
    await keys.setAnthropic('');
    expect(await keys.anthropic(), isNull);
  });

  test('enregistre le poste une fois et envoie des signes de vie', () async {
    final requests = <(String, Map<String, Object?>)>[];
    final client = MockClient((request) async {
      requests.add((
        request.url.path,
        request.body.isEmpty
            ? <String, Object?>{}
            : jsonDecode(request.body) as Map<String, Object?>,
      ));
      return http.Response(
        jsonEncode(<String, Object?>{
          'data': <String, Object?>{'id': 4},
        }),
        200,
      );
    });
    final api = ApiClient(
      ApiConfig(baseUrl: Uri.parse('https://ld.test/api/v1/'), token: 't'),
      httpClient: client,
    );
    final vault = MemoryVault();

    final first = HostDevice(
      api: api,
      vault: vault,
      name: 'PC',
      platform: 'windows',
    );
    expect(await first.register(), 4);
    await first.heartbeat();
    first.dispose();
    final second = HostDevice(
      api: api,
      vault: vault,
      name: 'PC',
      platform: 'windows',
    );
    await second.register();
    second.dispose();

    final registrations = requests.where((r) => r.$1 == '/api/v1/devices');
    expect(registrations, hasLength(2));
    // Même installation_id d'un lancement à l'autre : pas de doublon.
    expect(
      registrations.map((r) => r.$2['installation_id']).toSet(),
      hasLength(1),
    );
    expect(
      registrations.first.$2['installation_id'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(requests.map((r) => r.$1), contains('/api/v1/devices/4/heartbeat'));
    // La clé du fournisseur n'est jamais envoyée au serveur.
    expect(
      jsonEncode(requests.map((r) => r.$2).toList()),
      isNot(contains('sk-')),
    );
  });
}
