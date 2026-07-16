import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/model/scan_result.dart';

void main() {
  test('parses a structured Thai food scan result', () {
    final result = ScanResult.fromJson({
      'mode': 'food',
      'title': 'ผัดไทย · Pad Thai',
      'subtitle': 'Central Thailand',
      'confidence': 0.91,
      'sections': [
        {'title': 'About this dish', 'body': 'Stir-fried rice noodles.'},
      ],
      'candidates': [
        {'name': 'ผัดไทย', 'score': 0.91},
        {'name': 'ผัดซีอิ๊ว', 'score': 0.42},
      ],
      'originalText': '',
      'translatedText': '',
    });

    expect(result.mode, ScanMode.food);
    expect(result.title, contains('Pad Thai'));
    expect(result.sections.single.title, 'About this dish');
    expect(result.candidates.last.score, 0.42);
  });

  test('parses Thai sign text and English translation', () {
    final result = ScanResult.fromJson({
      'mode': 'sign',
      'title': 'Thai sign translation',
      'confidence': 0.88,
      'originalText': 'ทางออก',
      'translatedText': 'Exit',
    });

    expect(result.mode, ScanMode.sign);
    expect(result.originalText, 'ทางออก');
    expect(result.translatedText, 'Exit');
  });
}
