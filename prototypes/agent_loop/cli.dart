// Prototype 4 (phase 0) : boucle d'agent minimale.
//
//   dart run prototypes/agent_loop/cli.dart --folder=<dossier autorisé> \
//     --task="Résume brief.md en trois points." [--model=claude-opus-5-5]
//
// La clé est lue dans la variable d'environnement ANTHROPIC_API_KEY : jamais
// dans le dépôt ni dans le dossier de travail. En production elle viendra du
// stockage sécurisé de Windows.
import 'dart:io';

import 'agent_loop.dart';
import 'anthropic_client.dart';
import 'sandbox.dart';

Map<String, String> _parse(List<String> args) {
  final options = <String, String>{};
  for (final arg in args) {
    final match = RegExp(r'^--([a-z-]+)=(.*)$', dotAll: true).firstMatch(arg);
    if (match != null) {
      options[match.group(1)!] = match.group(2)!;
    }
  }
  return options;
}

Future<void> main(List<String> args) async {
  final options = _parse(args);
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];
  final folderPath = options['folder'];
  final task = options['task'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln(
      "La variable d'environnement ANTHROPIC_API_KEY est absente.",
    );
    exitCode = 78;
    return;
  }
  if (folderPath == null || task == null) {
    stderr.writeln('Options requises : --folder et --task.');
    exitCode = 64;
    return;
  }

  final client = AnthropicClient(apiKey: apiKey);
  final ledger = CostLedger(
    file: File(options['ledger'] ?? 'agent_loop_costs.jsonl'),
  );
  final loop = AgentLoop(
    client: client,
    folder: AllowedFolder(folderPath),
    ledger: ledger,
    model: options['model'] ?? 'claude-opus-5-5',
    effort: options['effort'] ?? 'low',
  );

  try {
    final result = await loop.run(task);
    for (final action in result.actions) {
      stdout.writeln(
        '${action.allowed ? 'Lu' : 'Refusé'} : ${action.input['path']} '
        '(${action.detail})',
      );
    }
    stdout
      ..writeln('--- Réponse (${result.stopReason}, ${result.turns} appels)')
      ..writeln(result.answer);
  } on ProviderException catch (error) {
    stderr.writeln('Le fournisseur a refusé la requête : $error');
    exitCode = 1;
  } finally {
    client.close();
  }

  stdout.writeln('--- Coûts réels');
  for (final record in ledger.records) {
    stdout.writeln(
      '${record.model} · ${record.usage.inputTokens} jetons en entrée, '
      '${record.usage.outputTokens} en sortie · '
      '${record.costUsd?.toStringAsFixed(6) ?? 'non chiffré'} \$ · '
      '${record.durationMs} ms',
    );
  }
  stdout.writeln(
    'Total : ${ledger.totalUsd.toStringAsFixed(6)} \$'
    '${ledger.hasUnpricedCalls ? ' (hors appels non chiffrés)' : ''}',
  );
}
