import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'auth/app_gate.dart';
import 'auth/auth_service.dart';
import 'auth/session.dart';

void main() {
  runApp(const LeadDeskApp());
}

/// Racine de l'application de bureau LeadDesk.
class LeadDeskApp extends StatelessWidget {
  const LeadDeskApp({super.key, this.home});

  /// Écran d'accueil ; par défaut la porte d'entrée (connexion, puis bureau).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeadDesk',
      debugShowCheckedModeBanner: false,
      theme: buildLeadDeskTheme(),
      home: home ?? AppGate(store: SecureSessionStore(), auth: AuthService()),
    );
  }
}
