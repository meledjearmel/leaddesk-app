import 'office_plan.dart';
import 'room_catalog.dart';

/// Départements du modèle « studio » (huit départements, conception du
/// studio virtuel), avec leurs activités. Ce sont des données de départ :
/// l'entreprise reste libre de les modifier (RM-03).
///
/// Au lancement, chaque département compte un responsable et un employé ;
/// [headcount] peut être augmenté pour simuler la croissance.
List<OfficeDepartment> studioDepartments({int headcount = 2}) {
  return <OfficeDepartment>[
    OfficeDepartment(
      id: 'direction',
      name: 'Direction',
      color: 0xFFF2B34C,
      headcount: headcount,
      tags: const <String>{ActivityTag.management, ActivityTag.data},
    ),
    OfficeDepartment(
      id: 'produit',
      name: 'Produit',
      color: 0xFF8B5CF6,
      headcount: headcount,
      tags: const <String>{ActivityTag.product, ActivityTag.design},
    ),
    OfficeDepartment(
      id: 'technique',
      name: 'Technique',
      color: 0xFF2BB5B0,
      headcount: headcount + 2,
      tags: const <String>{ActivityTag.code, ActivityTag.infrastructure},
    ),
    OfficeDepartment(
      id: 'qualite',
      name: 'Qualité et sécurité',
      color: 0xFF3B6FE0,
      headcount: headcount,
      tags: const <String>{ActivityTag.testing, ActivityTag.security},
    ),
    OfficeDepartment(
      id: 'contenu',
      name: 'Contenu',
      color: 0xFFE5484D,
      headcount: headcount,
      tags: const <String>{ActivityTag.writing, ActivityTag.media},
    ),
    OfficeDepartment(
      id: 'marketing',
      name: 'Marketing et commercial',
      color: 0xFFF08A5D,
      headcount: headcount,
      tags: const <String>{
        ActivityTag.sales,
        ActivityTag.calls,
        ActivityTag.media,
      },
    ),
    OfficeDepartment(
      id: 'rh',
      name: 'Ressources humaines',
      color: 0xFF3FA65A,
      headcount: headcount,
      tags: const <String>{
        ActivityTag.people,
        ActivityTag.training,
        ActivityTag.calm,
      },
    ),
    OfficeDepartment(
      id: 'finances',
      name: 'Administration et finances',
      color: 0xFFC08A3A,
      headcount: headcount,
      tags: const <String>{
        ActivityTag.finance,
        ActivityTag.documents,
        ActivityTag.calm,
      },
    ),
  ];
}
