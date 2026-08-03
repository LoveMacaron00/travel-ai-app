import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/widgets/media_image.dart';

void main() {
  testWidgets('renders fallback without requesting a placeholder media URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: mediaNetworkImage(
          'https://example.com/invented.jpg',
          errorBuilder: (_, __, ___) => const Text('image fallback'),
        ),
      ),
    );

    expect(find.text('image fallback'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
