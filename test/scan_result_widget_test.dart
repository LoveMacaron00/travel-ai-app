import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/model/scan_result.dart';
import 'package:myapp/screen/chatbot_screen.dart';

void main() {
  testWidgets('renders translated Thai sign content', (tester) async {
    const result = ScanResult(
      mode: ScanMode.sign,
      title: 'Thai sign translation',
      subtitle: '',
      confidence: 0.92,
      sections: [],
      candidates: [],
      originalText: 'กรุณาถอดรองเท้า',
      translatedText: 'Please remove your shoes',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ScanResultView(result: result)),
        ),
      ),
    );

    expect(find.text('กรุณาถอดรองเท้า'), findsOneWidget);
    expect(find.text('Please remove your shoes'), findsOneWidget);
    expect(find.textContaining('92%'), findsOneWidget);
  });
}
