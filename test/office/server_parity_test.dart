import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/office/office_plan.dart';
import 'package:leaddesk_app/office/room_catalog.dart';

/// Les règles d'aménagement sont les mêmes dans l'application et sur le
/// serveur (D-012, D-036 de `leaddesk-api`). Ces tests lisent les fichiers
/// du dépôt frère `../api` ; sans lui (CI de l'application seule), ils sont
/// ignorés.
void main() {
  const apiRoot = '../api';
  final catalogFile = File('$apiRoot/resources/office/room-types.json');
  final casesFile = File(
    '$apiRoot/tests/Fixtures/office/validation-cases.json',
  );
  final skip = catalogFile.existsSync() && casesFile.existsSync()
      ? false
      : 'dépôt leaddesk-api absent';

  test('le catalogue du serveur est identique à celui de l\'application', () {
    final server = (jsonDecode(catalogFile.readAsStringSync()) as List<Object?>)
        .cast<Map<String, Object?>>();
    final local = <Map<String, Object?>>[
      for (final type in RoomCatalog.all)
        <String, Object?>{
          'id': type.id,
          'name': type.name,
          'category': type.category.name,
          'scope': type.scope.name,
          'min_cols': type.minCols,
          'min_rows': type.minRows,
          'seats_per_row': type.seatsPerRow,
          'tags': type.tags.toList()..sort(),
          'proposed': type.proposed,
        },
    ];

    expect(server, local);
  }, skip: skip);

  test('les cas de validation du serveur donnent les mêmes problèmes', () {
    final cases = (jsonDecode(casesFile.readAsStringSync()) as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(cases, isNotEmpty);

    for (final entry in cases) {
      final departments = <OfficeDepartment>[
        for (final raw
            in (entry['departments']! as List<Object?>)
                .cast<Map<String, Object?>>())
          OfficeDepartment(
            id: raw['id']! as String,
            name: raw['name']! as String,
            color: 0,
            headcount: raw['headcount']! as int,
          ),
      ];
      final plan = OfficePlan.fromJson(
        entry['layout']! as Map<String, Object?>,
      );

      expect(
        plan.validate(departments),
        (entry['problems']! as List<Object?>).cast<String>(),
        reason: entry['name']! as String,
      );
    }
  }, skip: skip);

  test('un type de salle inconnu est signalé, sans planter', () {
    const plan = OfficePlan(
      cols: 10,
      rows: 10,
      rooms: <PlacedRoom>[
        PlacedRoom(id: 'a', typeId: 'teleporter', x: 0, y: 0, cols: 2, rows: 2),
        PlacedRoom(id: 'b', typeId: 'reception', x: 1, y: 1, cols: 5, rows: 4),
      ],
    );

    expect(plan.validate(const <OfficeDepartment>[]), <String>[
      'Type de salle inconnu : « teleporter ».',
      'teleporter et Hall d\'accueil se chevauchent : '
          'deux départements ne partagent jamais une salle.',
    ]);
  });
}
