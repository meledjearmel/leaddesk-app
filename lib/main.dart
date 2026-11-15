import 'package:flutter/material.dart';

void main() {
  runApp(const LeadDeskApp());
}

/// Racine de l'application de bureau LeadDesk.
///
/// Socle minimal : les écrans arrivent à partir de la phase 2 du plan.
class LeadDeskApp extends StatelessWidget {
  const LeadDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LeadDesk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8E7CC3)),
      ),
      home: const Scaffold(body: Center(child: Text('LeadDesk'))),
    );
  }
}
