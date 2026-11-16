import 'dart:async';
import 'dart:convert';

import '../api/api_client.dart';
import 'anthropic.dart';
import 'mcp_client.dart';
import 'model.dart';
import 'run_journal.dart';
import 'workspace.dart';

/// Comment une exécution s'est arrêtée.
enum RunOutcome {
  /// L'agent a fini et rendu son compte rendu.
  completed,

  /// Erreur, refus du modèle ou trop de tours.
  failed,

  /// Limite de coût atteinte : l'exécution attend la décision du CEO (RM-36).
  pausedCost,

  /// Le CEO a mis l'exécution en pause ou l'a arrêtée.
  stoppedByCeo,
}

/// Une étape visible de l'exécution (journal local de l'application).
class RunStep {
  const RunStep(this.kind, this.text);

  /// `model`, `tool`, `approval`, `error`, `info`.
  final String kind;
  final String text;
}

/// Bilan d'une exécution.
class RunReport {
  const RunReport({
    required this.outcome,
    required this.summary,
    required this.costMicros,
    required this.steps,
    this.runId,
  });

  final RunOutcome outcome;

  /// Exécution sur le serveur, `null` si elle n'a pas pu être ouverte.
  final int? runId;

  /// Dernier texte de l'agent, ou la raison de l'arrêt.
  final String summary;

  /// Coût réel cumulé connu, en millionièmes de dollar.
  final int costMicros;
  final List<RunStep> steps;
}

/// Exécution ouverte sur le serveur (`task_runs`).
class TaskRunRef {
  const TaskRunRef({
    required this.id,
    required this.taskId,
    required this.agentId,
    required this.deviceId,
  });

  final int id;
  final int taskId;
  final int agentId;
  final int deviceId;
}

/// Boucle d'agent du moteur d'exécution local (D-022, phase 4).
///
/// L'agent reçoit le contexte de sa tâche (RM-33), les outils permis par son
/// poste, et travaille jusqu'à rendre son compte rendu. Chaque appel de
/// modèle est enregistré avec son coût réel (RM-35) ; une limite atteinte
/// arrête la boucle (RM-36). Avant chaque outil local, le serveur dit si
/// l'action est permise, interdite ou soumise au CEO (D-031). Les fichiers
/// restent sur ce poste : seuls les chemins et les coûts vont au serveur.
class AgentRunner {
  AgentRunner({
    required this.api,
    required this.model,
    this.maxTurns = 40,
    this.approvalPoll = const Duration(seconds: 3),
    this.approvalTimeout = const Duration(minutes: 30),
    this.retryDelay = const Duration(seconds: 2),
    Workspace Function(Map<String, String> folders)? workspaceFactory,
    RunJournal? journal,
  }) : _workspaceFactory = workspaceFactory ?? Workspace.new,
       journal = journal ?? FileRunJournal();

  /// Client d'API du CEO (le runner se place au nom de l'agent).
  final ApiClient api;
  final ModelProvider model;
  final int maxTurns;
  final Duration approvalPoll;
  final Duration approvalTimeout;
  final Duration retryDelay;
  final Workspace Function(Map<String, String> folders) _workspaceFactory;

  /// Où en est chaque exécution, pour la reprendre (D-025).
  final RunJournal journal;

  final StreamController<RunStep> _steps =
      StreamController<RunStep>.broadcast();

  /// Étapes en direct, pour l'interface.
  Stream<RunStep> get steps => _steps.stream;

  /// Démarre l'exécution d'une tâche (CEO) puis la mène à son terme.
  Future<RunReport> start({
    required int taskId,
    required int agentId,
    required int deviceId,
  }) async {
    final data = await api.post('tasks/$taskId/runs', <String, Object?>{
      'agent_id': agentId,
      'device_id': deviceId,
    });
    final created = data! as Map<String, Object?>;
    return run(
      TaskRunRef(
        id: (created['id']! as num).toInt(),
        taskId: taskId,
        agentId: agentId,
        deviceId: deviceId,
      ),
    );
  }

  Future<RunReport> run(TaskRunRef ref) async {
    final agentApi = api.asAgent(ref.agentId);
    final log = <RunStep>[];
    final deliverables = <String>[];
    int? activityId;
    var cost = 0;

    void note(String kind, String text) {
      final step = RunStep(kind, text);
      log.add(step);
      if (!_steps.isClosed) {
        _steps.add(step);
      }
    }

    Future<RunReport> finish(RunOutcome outcome, String summary) async {
      final serverOutcome = switch (outcome) {
        RunOutcome.completed => 'completed',
        RunOutcome.failed => 'failed',
        _ => null,
      };
      if (serverOutcome != null) {
        // Fin définitive : le journal local n'a plus d'usage.
        await journal.delete(ref.id);
        try {
          await agentApi.post('task-runs/${ref.id}/finish', <String, Object?>{
            'outcome': serverOutcome,
            'reason': summary.length > 500
                ? '${summary.substring(0, 497)}…'
                : summary,
          });
        } on Object catch (error) {
          note('error', 'Fin non enregistrée sur le serveur : $error');
        }
        if (activityId != null) {
          await _postReport(
            agentApi,
            activityId: activityId,
            ref: ref,
            outcome: outcome,
            summary: summary,
            deliverables: deliverables,
            note: note,
          );
        }
      }
      return RunReport(
        outcome: outcome,
        summary: summary,
        costMicros: cost,
        steps: List<RunStep>.unmodifiable(log),
        runId: ref.id,
      );
    }

    // 1. Contexte de la tâche et dossiers autorisés.
    final Map<String, Object?> context;
    final Workspace workspace;
    try {
      context =
          (await agentApi.get(
                'agents/${ref.agentId}/tasks/${ref.taskId}/context',
              ))!
              as Map<String, Object?>;
      final activity = context['activity'];
      activityId = activity is Map<String, Object?>
          ? (activity['id'] as num?)?.toInt()
          : null;
      workspace = _workspaceFactory(
        await _folders(agentApi, activityId, ref.deviceId),
      );
    } on Object catch (error) {
      note('error', 'Contexte illisible : $error');
      return finish(RunOutcome.failed, 'Contexte de la tâche illisible.');
    }

    final permissions = <String, String>{
      if (context['tool_permissions'] case final Map<String, Object?> raw)
        for (final MapEntry(:key, :value) in raw.entries)
          if (value is String) key: value,
    };
    final tools = toolsFor(permissions, workspace);
    final mcp = LeadDeskMcp(agentApi);
    final system = systemPrompt(context, workspace);
    // Reprise : on repart de la conversation gardée sur ce poste.
    final saved = await journal.read(ref.id);
    final messages = <Map<String, Object?>>[
      ...?saved?.messages,
      if (saved == null || saved.messages.isEmpty)
        <String, Object?>{
          'role': 'user',
          'content':
              'Réalise ta tâche. Quand tu as fini, termine par un compte '
              'rendu court : ce que tu as fait, les livrables produits, ce '
              'qui reste.',
        },
    ];
    if (saved != null) {
      cost = saved.costMicros;
      deliverables.addAll(saved.deliverables);
      note('info', 'Reprise : ${tools.length} outils disponibles.');
    } else {
      note('info', 'Début : ${tools.length} outils disponibles.');
    }

    Future<void> save() => journal.write(
      ref.id,
      RunState(
        messages: messages,
        costMicros: cost,
        deliverables: deliverables,
      ),
    );
    await save();

    var lastText = '';
    for (var turn = 0; turn < maxTurns; turn++) {
      // 2. Un tour du modèle, avec reprise sur erreur passagère.
      ModelTurn? response;
      for (var attempt = 0; response == null; attempt++) {
        try {
          response = await model.next(
            system: system,
            tools: tools,
            messages: messages,
          );
        } on ProviderException catch (error) {
          if (!error.retryable || attempt >= 2) {
            note('error', error.message);
            return finish(RunOutcome.failed, error.message);
          }
          await Future<void>.delayed(retryDelay * (attempt + 1));
        }
      }
      cost += response.costMicros ?? 0;
      if (response.text.isNotEmpty) {
        lastText = response.text;
        note('model', response.text);
      }

      // 3. Coût réel au serveur ; une limite atteinte arrête tout.
      final status = await _recordUsage(agentApi, ref.id, response);
      if (status == 'paused_cost' || status == 'paused') {
        // Le coût de ce tour est dépensé : il compte à la reprise, même si
        // sa réponse est écartée (le tour sera rejoué).
        await save();
      }
      if (status == 'paused_cost') {
        note('info', 'Limite de coût atteinte : en attente du CEO.');
        return finish(
          RunOutcome.pausedCost,
          'Limite de coût atteinte : l\'exécution attend votre décision.',
        );
      }
      if (status == 'paused' || status == 'cancelled') {
        note('info', 'Exécution arrêtée par le CEO.');
        return finish(RunOutcome.stoppedByCeo, 'Exécution arrêtée par le CEO.');
      }

      messages.add(<String, Object?>{
        'role': 'assistant',
        'content': response.assistantContent,
      });

      switch (response.stopReason) {
        case StopReason.endTurn:
          return finish(
            RunOutcome.completed,
            lastText.isEmpty ? 'Tâche terminée.' : lastText,
          );
        case StopReason.refusal:
          return finish(RunOutcome.failed, 'Le modèle a refusé la demande.');
        case StopReason.maxTokens:
          return finish(
            RunOutcome.failed,
            'Réponse trop longue pour une seule étape.',
          );
        case StopReason.pauseTurn:
          await save();
          continue;
        case StopReason.toolUse || StopReason.other:
          break;
      }
      if (response.toolCalls.isEmpty) {
        return finish(RunOutcome.completed, lastText);
      }

      // 4. Outils : tous les résultats dans un seul message.
      final results = <Map<String, Object?>>[];
      for (final call in response.toolCalls) {
        final result = await _runTool(
          call,
          agentApi: agentApi,
          runId: ref.id,
          workspace: workspace,
          mcp: mcp,
          note: note,
          onWritten: (path) {
            if (!deliverables.contains(path)) {
              deliverables.add(path);
            }
          },
        );
        if (result == null) {
          return finish(
            RunOutcome.stoppedByCeo,
            'Exécution arrêtée pendant une demande d\'approbation.',
          );
        }
        results.add(result.toJson());
      }
      messages.add(<String, Object?>{'role': 'user', 'content': results});
      await save();
    }
    return finish(
      RunOutcome.failed,
      'Trop d\'étapes ($maxTurns) : tâche interrompue.',
    );
  }

  Future<Map<String, String>> _folders(
    ApiClient agentApi,
    int? activityId,
    int deviceId,
  ) async {
    if (activityId == null) {
      return const <String, String>{};
    }
    final activity = await agentApi.get('activities/$activityId');
    final projectId = activity is Map<String, Object?>
        ? (activity['project_id'] as num?)?.toInt()
        : null;
    if (projectId == null) {
      return const <String, String>{};
    }
    final folders = await agentApi.getList(
      'projects/$projectId/folders?device_id=$deviceId',
    );
    return <String, String>{
      for (final folder in folders)
        if (folder['kind'] case final String kind)
          kind: folder['path']! as String,
    };
  }

  /// Compte rendu final dans la conversation de l'activité : texte de
  /// l'agent et livrables écrits (chemins sur cet hôte, jamais le contenu).
  Future<void> _postReport(
    ApiClient agentApi, {
    required int activityId,
    required TaskRunRef ref,
    required RunOutcome outcome,
    required String summary,
    required List<String> deliverables,
    required void Function(String kind, String text) note,
  }) async {
    final body = outcome == RunOutcome.completed
        ? summary
        : 'Tâche interrompue : $summary';
    try {
      await agentApi.post('activities/$activityId/messages', <String, Object?>{
        'body': body.length > 20000 ? body.substring(0, 20000) : body,
        'task_id': ref.taskId,
        if (deliverables.isNotEmpty)
          'file_references': <Object?>[
            for (final path in deliverables.take(20))
              <String, Object?>{
                'label': path.split('/').last,
                'path': path,
                'device_id': ref.deviceId,
              },
          ],
      });
    } on Object catch (error) {
      note('error', 'Compte rendu non publié : $error');
    }
  }

  Future<String?> _recordUsage(
    ApiClient agentApi,
    int runId,
    ModelTurn turn,
  ) async {
    final data = await agentApi.post(
      'task-runs/$runId/usage',
      <String, Object?>{
        'kind': 'model',
        'provider': model.provider,
        'model': turn.model,
        'input_tokens': turn.usage.inputTokens,
        'output_tokens': turn.usage.outputTokens,
        'cache_read_tokens': turn.usage.cacheReadTokens,
        'cache_write_tokens': turn.usage.cacheWriteTokens,
        'cost_micros': turn.costMicros,
      },
    );
    return data is Map<String, Object?> ? data['status'] as String? : null;
  }

  /// Exécute un outil ; `null` si l'exécution a été arrêtée entre-temps.
  Future<ToolResult?> _runTool(
    ToolCall call, {
    required ApiClient agentApi,
    required int runId,
    required Workspace workspace,
    required LeadDeskMcp mcp,
    required void Function(String kind, String text) note,
    required void Function(String path) onWritten,
  }) async {
    final path = call.input['path'] as String? ?? '';
    try {
      switch (call.name) {
        case 'list_files' || 'read_file' || 'write_file':
          final permission = call.name == 'write_file'
              ? 'write_file'
              : 'read_file';
          final summary = switch (call.name) {
            'list_files' => 'Lister « $path »',
            'read_file' => 'Lire « $path »',
            _ =>
              'Écrire « $path » '
                  '(${(call.input['content'] as String? ?? '').length} caractères)',
          };
          final allowed = await _approve(
            agentApi,
            runId,
            permission,
            summary,
            note,
          );
          if (allowed == null) {
            return null;
          }
          if (!allowed) {
            note('approval', 'Refusé : $summary');
            return ToolResult(
              call.id,
              'Action refusée : le poste ne le permet pas ou le CEO a refusé.',
              isError: true,
            );
          }
          note('tool', summary);
          final output = switch (call.name) {
            'list_files' => workspace.list(path),
            'read_file' => workspace.read(path),
            _ => workspace.write(path, call.input['content'] as String? ?? ''),
          };
          if (call.name == 'write_file') {
            onWritten(path.replaceAll('\\', '/'));
          }
          return ToolResult(call.id, output);
        case 'office_context':
          note('tool', 'Contexte du bureau (MCP)');
          final result = await mcp.call('office.context', <String, Object?>{});
          return ToolResult(call.id, result.text, isError: result.isError);
        case 'office_propose_plan':
          note('tool', 'Proposition d\'aménagement (MCP)');
          final result = await mcp.call('office.propose_plan', call.input);
          return ToolResult(call.id, result.text, isError: result.isError);
        default:
          return ToolResult(call.id, 'Outil inconnu.', isError: true);
      }
    } on WorkspaceException catch (error) {
      note('error', error.message);
      return ToolResult(call.id, error.message, isError: true);
    } on Object catch (error) {
      note('error', '$error');
      return ToolResult(call.id, 'Erreur : $error', isError: true);
    }
  }

  /// Vrai si l'action est permise, faux si refusée, `null` si l'exécution
  /// s'est arrêtée pendant l'attente.
  Future<bool?> _approve(
    ApiClient agentApi,
    int runId,
    String tool,
    String summary,
    void Function(String kind, String text) note,
  ) async {
    final data =
        (await agentApi.post('task-runs/$runId/approvals', <String, Object?>{
              'tool': tool,
              'summary': summary,
            }))!
            as Map<String, Object?>;
    switch (data['outcome']) {
      case 'allowed':
        return true;
      case 'denied':
        return false;
    }
    final decision = data['decision'];
    final decisionId = decision is Map<String, Object?>
        ? (decision['id'] as num?)?.toInt()
        : null;
    if (decisionId == null) {
      return false;
    }
    note('approval', 'En attente du CEO : $summary');
    final deadline = DateTime.now().add(approvalTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(approvalPoll);
      final current = await agentApi.get('decisions/$decisionId');
      final status = current is Map<String, Object?> ? current['status'] : null;
      if (status == 'approved') {
        return true;
      }
      if (status == 'rejected') {
        return false;
      }
      final run = await agentApi.get('task-runs/$runId');
      final runStatus = run is Map<String, Object?> ? run['status'] : null;
      if (runStatus != 'running') {
        return null;
      }
    }
    return false;
  }

  /// Outils proposés au modèle : seulement ceux que le poste ne refuse pas.
  static List<ToolSpec> toolsFor(
    Map<String, String> permissions,
    Workspace workspace,
  ) {
    bool open(String tool) => (permissions[tool] ?? 'deny') != 'deny';
    final kinds = workspace.folders.keys.join(', ');
    const pathSchema = <String, Object?>{
      'type': 'string',
      'description':
          'Chemin relatif qui commence par la nature du dossier, par exemple '
          '« documentation/notes.md » ou « code/src ».',
    };
    return <ToolSpec>[
      if (open('read_file') && !workspace.isEmpty) ...<ToolSpec>[
        ToolSpec(
          name: 'list_files',
          description:
              'Liste le contenu d\'un dossier autorisé du projet ($kinds).',
          inputSchema: const <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{'path': pathSchema},
            'required': <String>['path'],
          },
        ),
        ToolSpec(
          name: 'read_file',
          description:
              'Lit un fichier texte d\'un dossier autorisé du projet ($kinds).',
          inputSchema: const <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{'path': pathSchema},
            'required': <String>['path'],
          },
        ),
      ],
      if (open('write_file') && !workspace.isEmpty)
        ToolSpec(
          name: 'write_file',
          description:
              'Crée ou remplace un fichier texte dans un dossier autorisé '
              '($kinds) : c\'est ainsi que tu rends un livrable.',
          inputSchema: const <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'path': pathSchema,
              'content': <String, Object?>{
                'type': 'string',
                'description': 'Contenu complet du fichier.',
              },
            },
            'required': <String>['path', 'content'],
          },
        ),
      if (open('office.propose_plan')) ...<ToolSpec>[
        const ToolSpec(
          name: 'office_context',
          description:
              'Départements, effectifs, catalogue des salles, plan du bureau '
              'en vigueur et règles d\'aménagement.',
          inputSchema: <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{},
          },
        ),
        const ToolSpec(
          name: 'office_propose_plan',
          description:
              'Propose au CEO un nouvel aménagement du bureau (format de '
              'office_context). Un plan invalide est refusé avec la liste '
              'des problèmes.',
          inputSchema: <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'layout': <String, Object?>{
                'type': 'object',
                'description': 'Plan : cols, rows et rooms.',
              },
              'reason': <String, Object?>{
                'type': 'string',
                'description': 'Motif montré au CEO.',
              },
            },
            'required': <String>['layout', 'reason'],
          },
        ),
      ],
    ];
  }

  /// Consigne de l'agent, construite depuis le contexte de sa tâche (RM-33).
  static String systemPrompt(
    Map<String, Object?> context,
    Workspace workspace,
  ) {
    String section(String title, Object? value) {
      if (value == null ||
          (value is List && value.isEmpty) ||
          (value is Map && value.isEmpty)) {
        return '';
      }
      return '\n## $title\n${const JsonEncoder.withIndent('  ').convert(value)}\n';
    }

    final agent = context['agent'];
    final name = agent is Map<String, Object?> ? agent['name'] : 'l\'agent';
    final folders = workspace.isEmpty
        ? 'Aucun dossier de projet n\'est autorisé sur cet ordinateur.'
        : workspace.folders.keys.map((kind) => '- « $kind/… »').join('\n');
    return '''
Tu es $name, agent d'une entreprise pilotée par son CEO dans LeadDesk. Tu travailles en français, dans le cadre de ton poste et des règles ci-dessous.

Méthode :
- Lis ce qu'il faut avant d'agir ; ne devine pas le contenu d'un fichier.
- Rends tes livrables sous forme de fichiers dans les dossiers autorisés.
- Si une action est refusée, adapte-toi ou explique ce qui bloque dans ton compte rendu.
- Termine par un compte rendu court.

Dossiers autorisés :
$folders
${section('Ton poste', agent is Map<String, Object?> ? agent['position'] : null)}${section('Ta tâche', context['task'])}${section('Activité', context['activity'])}${section('Autres tâches de l\'activité', context['related_tasks'])}${section('Personnes', context['people'])}${section('Contexte partagé', context['shared_context'])}${section('Règles à respecter', context['rules'])}''';
  }

  Future<void> dispose() => _steps.close();
}
