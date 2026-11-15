import 'package:flutter_test/flutter_test.dart';
import 'package:leaddesk_app/main.dart';

void main() {
  testWidgets("l'application démarre et affiche son nom", (tester) async {
    await tester.pumpWidget(const LeadDeskApp());

    expect(find.text('LeadDesk'), findsOneWidget);
  });
}
