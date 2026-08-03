import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/model/travel_plan.dart';

Map<String, dynamic> stopJson(String imageUrl) => {
  'place': 'สถานที่ทดสอบ',
  'imageUrl': imageUrl,
};

void main() {
  test('treats documentation-only image URLs as missing media', () {
    final stop = TravelStop.fromJson(
      stopJson('https://example.com/invented.jpg'),
    );

    expect(stop.imageUrl, isEmpty);
  });

  test('keeps real destination image URLs', () {
    const imageUrl = 'https://dmc.tatdataapi.io/assets/real-destination.jpeg';
    final stop = TravelStop.fromJson(stopJson(imageUrl));

    expect(stop.imageUrl, imageUrl);
  });
}
