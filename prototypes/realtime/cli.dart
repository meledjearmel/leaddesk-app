// Prototype 3 (phase 0), version ligne de commande : même client que la
// fenêtre Flutter, pour vérifier la liaison de bout en bout sans interface.
//
//   dart run prototypes/realtime/cli.dart \
//     --base=http://127.0.0.1:8123 --email=... --password=... \
//     --reverb-host=127.0.0.1 --reverb-port=8080 --reverb-key=...
//
// Le mot de passe peut aussi venir de la variable LEADDESK_PROTO_PASSWORD.
import 'dart:io';

import 'reverb_client.dart';

Map<String, String> _parse(List<String> args) {
  final options = <String, String>{};
  for (final arg in args) {
    final match = RegExp(r'^--([a-z-]+)=(.*)$').firstMatch(arg);
    if (match != null) {
      options[match.group(1)!] = match.group(2)!;
    }
  }
  return options;
}

Future<void> main(List<String> args) async {
  final options = _parse(args);
  final password =
      options['password'] ?? Platform.environment['LEADDESK_PROTO_PASSWORD'];
  final email = options['email'];
  final reverbKey = options['reverb-key'];
  if (email == null || password == null || reverbKey == null) {
    stderr.writeln('Options requises : --email, --password, --reverb-key.');
    exitCode = 64;
    return;
  }

  final api = PrototypeApi(
    Uri.parse(options['base'] ?? 'http://127.0.0.1:8000'),
  );
  final watch = Stopwatch()..start();

  final session = await api.login(
    email: email,
    password: password,
    deviceName: 'prototype-cli',
  );
  stdout.writeln('Connexion Sanctum : ${watch.elapsedMilliseconds} ms');

  watch.reset();
  final reverb = await ReverbClient.connect(
    ReverbClient.endpoint(
      host: options['reverb-host'] ?? '127.0.0.1',
      port: int.parse(options['reverb-port'] ?? '8080'),
      appKey: reverbKey,
    ),
  );
  stdout.writeln('Connexion Reverb : ${watch.elapsedMilliseconds} ms');

  watch.reset();
  final events = await reverb.subscribePrivate(
    session.channel,
    authorize: (socketId, channelName) => api.authorizeChannel(
      session,
      socketId: socketId,
      channelName: channelName,
    ),
  );
  stdout.writeln('Abonnement au canal privé : ${watch.elapsedMilliseconds} ms');

  final latencies = <int>[];
  for (var i = 1; i <= 5; i++) {
    final received = events.first.timeout(const Duration(seconds: 10));
    watch.reset();
    await api.ping(session, 'ping $i');
    final event = await received;
    latencies.add(watch.elapsedMilliseconds);
    stdout.writeln(
      'Événement ${event.name} reçu en ${latencies.last} ms : ${event.data}',
    );
  }
  latencies.sort();
  stdout.writeln(
    'Latence ping → événement : médiane ${latencies[2]} ms, '
    'max ${latencies.last} ms',
  );

  await reverb.close();
  api.close();
}
