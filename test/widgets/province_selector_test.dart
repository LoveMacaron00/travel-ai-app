import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/widgets/province_selector.dart';

void main() {
  testWidgets('selects a database-backed province', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProvinceSelector(
            value: selected,
            options: const [
              ProvinceOption(
                value: 'เชียงราย',
                label: 'เชียงราย',
                destinationCount: 2,
              ),
              ProvinceOption(
                value: 'ลพบุรี',
                label: 'ลพบุรี',
                destinationCount: 1,
              ),
            ],
            loading: false,
            decoration: const InputDecoration(labelText: 'จังหวัด'),
            selectHint: 'เลือกจังหวัด',
            loadingHint: 'กำลังโหลดจังหวัด…',
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('plan-province-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เชียงราย (2)').last);
    await tester.pumpAndSettle();

    expect(selected, 'เชียงราย');
    expect(tester.takeException(), isNull);
  });
}
