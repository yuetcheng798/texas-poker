import 'package:flutter_test/flutter_test.dart';
import 'package:texas_poker/main.dart';

void main() {
  testWidgets('poker table renders correctly', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Texas Poker'), findsOneWidget);
    expect(find.text('Community cards'), findsOneWidget);
    expect(find.text('Your chips'), findsOneWidget);
  });
}
