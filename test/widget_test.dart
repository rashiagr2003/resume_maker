import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resume_maker/main.dart';

void main() {
  testWidgets('ResumeMakerApp renders brand title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ResumeMakerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ResumeCraft AI'), findsOneWidget);
  });
}
