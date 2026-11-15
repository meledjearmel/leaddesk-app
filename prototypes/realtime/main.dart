// Prototype 3 (phase 0) : connexion Flutter → Laravel avec Sanctum et
// réception d'un événement Reverb, dans une fenêtre de bureau.
//
// Côté serveur (dépôt leaddesk-api, PROTOTYPES_ENABLED=true) :
//   php artisan serve --port=8123
//   php artisan reverb:start --port=8080
// Côté application :
//   flutter run -d windows -t prototypes/realtime/main.dart \
//     --dart-define=REVERB_KEY=<clé de l'application Reverb>
//
// Code jetable : rien ici n'est importé par lib/.
import 'dart:async';

import 'package:flutter/material.dart';

import 'reverb_client.dart';

const String _reverbKey = String.fromEnvironment('REVERB_KEY');
const String _baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://127.0.0.1:8123',
);
const String _reverbHost = String.fromEnvironment(
  'REVERB_HOST',
  defaultValue: '127.0.0.1',
);
const int _reverbPort = int.fromEnvironment('REVERB_PORT', defaultValue: 8080);

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RealtimePrototypePage(),
    ),
  );
}

class RealtimePrototypePage extends StatefulWidget {
  const RealtimePrototypePage({super.key});

  @override
  State<RealtimePrototypePage> createState() => _RealtimePrototypePageState();
}

class _RealtimePrototypePageState extends State<RealtimePrototypePage> {
  final TextEditingController _email = TextEditingController(
    text: 'proto@leaddesk.test',
  );
  final TextEditingController _password = TextEditingController();
  final List<String> _log = <String>[];
  final PrototypeApi _api = PrototypeApi(Uri.parse(_baseUrl));

  ApiSession? _session;
  ReverbClient? _reverb;
  StreamSubscription<ReverbEvent>? _events;
  bool _busy = false;
  int _pings = 0;

  void _say(String line) {
    setState(() => _log.insert(0, line));
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final watch = Stopwatch()..start();
    try {
      final session = await _api.login(
        email: _email.text.trim(),
        password: _password.text,
        deviceName: 'prototype-fenetre',
      );
      _say('Connecté par jeton Sanctum (${watch.elapsedMilliseconds} ms).');

      watch.reset();
      final reverb = await ReverbClient.connect(
        ReverbClient.endpoint(
          host: _reverbHost,
          port: _reverbPort,
          appKey: _reverbKey,
        ),
      );
      final events = await reverb.subscribePrivate(
        session.channel,
        authorize: (socketId, channelName) => _api.authorizeChannel(
          session,
          socketId: socketId,
          channelName: channelName,
        ),
      );
      _say(
        'Abonné au canal privé ${session.channel} '
        '(${watch.elapsedMilliseconds} ms).',
      );

      _events = events.listen(
        (event) => _say('Événement ${event.name} : ${event.data}'),
      );
      setState(() {
        _session = session;
        _reverb = reverb;
      });
    } on Object catch (error) {
      _say('Échec : $error');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _ping() async {
    final session = _session;
    if (session == null) {
      return;
    }
    _pings++;
    try {
      await _api.ping(session, 'ping $_pings depuis la fenêtre');
    } on Object catch (error) {
      _say('Échec du ping : $error');
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(_reverb?.close());
    _api.close();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _session != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Prototype 3 — Sanctum + Reverb')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Serveur : $_baseUrl · Reverb : $_reverbHost:$_reverbPort',
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _email,
                    enabled: !connected,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _password,
                    enabled: !connected,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: connected || _busy ? null : _connect,
                  child: const Text('Se connecter'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: connected ? _ping : null,
                  child: const Text('Envoyer un ping'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(_log[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
