import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/destination_display.dart';

void main() {
  group('destination display compatibility', () {
    test('strips HTML and collapses whitespace', () {
      expect(
        stripHtmlText('<p>วัดไทย</p>\n  <strong>Bangkok</strong>'),
        'วัดไทย Bangkok',
      );
    });

    test('collects and deduplicates relative image URLs', () {
      final images = collectDestinationImages({
        'image_url': '/uploads/cover.jpg',
        'images': [
          {'image_url': '/uploads/cover.jpg'},
          {'image_url': 'https://example.com/detail.jpg'},
        ],
      });

      expect(images, [
        'http://10.0.2.2:5000/uploads/cover.jpg',
        'https://example.com/detail.jpg',
      ]);
    });

    test('prefers saved fee over legacy TAT values', () {
      final fee = resolveAdmissionFee({
        'admission_fee': {'thai_adult': 50},
        'tat_raw': {
          'information': {
            'fee': {'thai_adult': 100},
          },
        },
      });

      expect(fee?['thai_adult'], 50);
    });

    test('formats structured hours before legacy open and close fields', () {
      expect(
        formatDestinationOpeningHours({
          'opening_hours': [
            {'day': 'Mon', 'open': '09:00', 'close': '17:00'},
          ],
          'opening_time': '08:00',
          'closing_time': '18:00',
        }),
        'Mon 09:00 17:00',
      );
    });
  });
}
