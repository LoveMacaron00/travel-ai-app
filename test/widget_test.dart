import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';
import 'package:myapp/services/api_service.dart';

void main() {
  testWidgets('shows the welcome screen for a signed-out user', (
    WidgetTester tester,
  ) async {
    ApiService.token = null;
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome to Application'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
