import 'package:myapp/services/app_services.dart';

/// รวมกติกาแปลงข้อมูลสถานที่จาก API ให้พร้อมแสดงผลใน UI
///
/// ข้อมูลเก่าและข้อมูลจาก TAT มี shape ต่างกัน ฟังก์ชันในไฟล์นี้จึงเป็น
/// compatibility boundary เพื่อไม่ให้แต่ละหน้าจอเขียน fallback ซ้ำกันเอง
String stripHtmlText(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<String> collectDestinationImages(
  Map<String, dynamic> detail, {
  String fallback = '',
}) {
  final urls = <String>[
    if (fallback.isNotEmpty) AppServices.media.fullUrl(fallback),
  ];
  if (detail['image_url'] != null) {
    urls.add(AppServices.media.fullUrl('${detail['image_url']}'));
  }
  if (detail['images'] is List) {
    for (final image in detail['images'] as List) {
      if (image is Map && image['image_url'] != null) {
        urls.add(AppServices.media.fullUrl('${image['image_url']}'));
      }
    }
  }
  return urls.where((url) => url.isNotEmpty).toSet().toList();
}

String formatDestinationOpeningHours(Map<String, dynamic> detail) {
  final raw = detail['opening_hours'];
  if (raw is List && raw.isNotEmpty) {
    final entries = raw
        .whereType<Map>()
        .map((item) {
          final day = '${item['day'] ?? ''}';
          final open = '${item['open'] ?? item['openTime'] ?? ''}';
          final close = '${item['close'] ?? item['closeTime'] ?? ''}';
          return [
            day,
            if (open.isNotEmpty) open,
            if (close.isNotEmpty) close,
          ].join(' ').trim();
        })
        .where((line) => line.isNotEmpty)
        .toList();
    if (entries.isNotEmpty) return entries.join('\n');
  }

  final open = '${detail['opening_time'] ?? ''}';
  final close = '${detail['closing_time'] ?? ''}';
  return [
    open,
    close,
  ].where((time) => time.isNotEmpty && time != '00:00').join(' – ');
}

/// เลือกค่า admission fee ตามลำดับความน่าเชื่อถือ:
/// ค่าที่แอดมินบันทึก > TAT information.fee > TAT fee แบบเก่า
Map<dynamic, dynamic>? resolveAdmissionFee(Map<String, dynamic> detail) {
  final savedFee = detail['admission_fee'];
  if (savedFee is Map && savedFee.isNotEmpty) return savedFee;

  final raw = detail['tat_raw'];
  if (raw is! Map) return null;
  final information = raw['information'];
  if (information is Map && information['fee'] is Map) {
    return information['fee'] as Map;
  }
  return raw['fee'] is Map ? raw['fee'] as Map : null;
}
