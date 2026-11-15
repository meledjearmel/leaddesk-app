import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'live_office/live_office_screen.dart';

void main() {
  runApp(const LeadDeskApp());
}

/// Racine de l'application de bureau LeadDesk.
class LeadDeskApp extends StatelessWidget {
  const LeadDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeadDesk',
      debugShowCheckedModeBanner: false,
      theme: buildLeadDeskTheme(),
      home: const LiveOfficeScreen(),
    );
  }
}
