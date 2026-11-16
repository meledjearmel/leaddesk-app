import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/realtime.dart';
import '../app/theme.dart';
import '../engine/host.dart';
import '../engine/run_controller.dart';
import '../live_office/live_office_screen.dart';
import '../live_office/office_source.dart';
import 'auth_screens.dart';
import 'auth_service.dart';
import 'session.dart';

/// Porte d'entrée de l'application (D-017) : session gardée → bureau ;
/// compte sans entreprise → création ; sinon → connexion.
///
/// `LD_API_URL` et `LD_API_TOKEN`, s'ils sont définis, ouvrent directement
/// le bureau (développement).
class AppGate extends StatefulWidget {
  const AppGate({
    required this.store,
    required this.auth,
    this.httpClient,
    this.realtimeConnector,
    this.vault,
    super.key,
  });

  /// Coffre local (clé du fournisseur, identifiant d'installation) ; par
  /// défaut le stockage sécurisé de Windows.
  final LocalVault? vault;

  final SessionStore store;
  final AuthService auth;

  /// Client HTTP du bureau ; par défaut un client réel.
  final http.Client? httpClient;

  /// Connexion WebSocket du temps réel ; par défaut une vraie connexion.
  final RealtimeConnector? realtimeConnector;

  @override
  State<AppGate> createState() => _AppGateState();
}

enum _Stage { loading, signIn, signUp, forgot, setup, office, demo }

class _AppGateState extends State<AppGate> {
  _Stage _stage = _Stage.loading;
  Session? _session;
  ApiClient? _client;
  RealtimeClient? _realtime;
  RunController? _engine;
  String _lastServer = '';

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final environment = ApiConfig.fromEnvironment();
    if (environment != null) {
      _open(
        Session(
          baseUrl: environment.baseUrl,
          token: environment.token,
          userName: '',
          email: '',
          companyName: '',
        ),
        persist: false,
      );
      return;
    }
    final session = await widget.store.read();
    if (!mounted) {
      return;
    }
    if (session == null) {
      setState(() => _stage = _Stage.signIn);
    } else {
      _open(session, persist: false);
    }
  }

  void _open(Session session, {bool persist = true}) {
    if (persist) {
      unawaited(widget.store.write(session));
    }
    _closeClients();
    _lastServer = session.baseUrl.toString().replaceFirst(
      RegExp(r'/api/v1/?$'),
      '',
    );
    setState(() {
      _session = session;
      if (session.companyName == null) {
        _client = null;
        _stage = _Stage.setup;
      } else {
        _client = ApiClient(session.config, httpClient: widget.httpClient);
        _realtime = RealtimeClient(
          _client!,
          connector: widget.realtimeConnector,
        );
        final vault = widget.vault ?? SecureVault();
        _engine = RunController(
          api: _client!,
          keys: ProviderKeys(vault),
          host: HostDevice(api: _client!, vault: vault),
        );
        _stage = _Stage.office;
      }
    });
  }

  Future<void> _signOut() async {
    final session = _session;
    setState(() {
      _stage = _Stage.signIn;
      _session = null;
    });
    _closeClients();
    await widget.store.clear();
    if (session != null) {
      await widget.auth.signOut(session);
    }
  }

  void _closeClients() {
    _engine?.dispose();
    _engine = null;
    final realtime = _realtime;
    _realtime = null;
    if (realtime != null) {
      unawaited(realtime.dispose());
    }
    _client?.close();
    _client = null;
  }

  @override
  void dispose() {
    _closeClients();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.loading => const ColoredBox(color: LdColors.background),
      _Stage.signIn => SignInScreen(
        auth: widget.auth,
        initialServer: _lastServer,
        onSignedIn: _open,
        onDemo: () => setState(() => _stage = _Stage.demo),
        onCreateAccount: (server) => setState(() {
          _lastServer = server;
          _stage = _Stage.signUp;
        }),
        onForgotPassword: (server) => setState(() {
          _lastServer = server;
          _stage = _Stage.forgot;
        }),
      ),
      _Stage.forgot => ForgotPasswordScreen(
        auth: widget.auth,
        initialServer: _lastServer,
        onBack: (server) => setState(() {
          _lastServer = server;
          _stage = _Stage.signIn;
        }),
      ),
      _Stage.signUp => SignUpScreen(
        auth: widget.auth,
        initialServer: _lastServer,
        onSignedUp: _open,
        onBack: (server) => setState(() {
          _lastServer = server;
          _stage = _Stage.signIn;
        }),
      ),
      _Stage.setup => CompanySetupScreen(
        auth: widget.auth,
        session: _session!,
        onCreated: _open,
        onSignOut: _signOut,
      ),
      _Stage.office => LiveOfficeScreen(
        key: ValueKey<Uri>(_session!.baseUrl),
        source: ApiOfficeSource(_client!),
        realtime: _realtime,
        engine: _engine,
        onSignOut: _signOut,
      ),
      _Stage.demo => LiveOfficeScreen(
        source: const DemoOfficeSource(),
        onSignOut: () => setState(() => _stage = _Stage.signIn),
      ),
    };
  }
}
