import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/screen/sign_in_screen.dart';
import 'package:myapp/screen/welcome_screen.dart';

void main() {
  testWidgets('welcome screen opens the sign-in flow without runtime errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: WelcomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Login to your\naccount'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
