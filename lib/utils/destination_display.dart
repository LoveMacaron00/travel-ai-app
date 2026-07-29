import 'package:myapp/services/app_services.dart';

/// รวมกติกาแปลงข้อมูลสถานที่จาก API ให้พร้อมแสดงผลใน UI
///
/// ข้อมูลเก่าและข้อมูลจาก TAT มี shape ต่างกัน ฟังก์ชันในไฟล์นี้จึงเป็น
/// เป็นขอบเขตความเข้ากันได้ เพื่อไม่ให้แต่ละหน้าจอเขียนค่าทดแทนซ้ำกันเอง
String stripHtmlText(String value) {
  var decoded = value;

  // เนื้อหาจาก TAT อาจมี HTML entity ทั้งแบบปกติและแบบเข้ารหัสซ้ำ
  // ถอดรหัสหลายรอบเพื่อจัดการค่าอย่าง &amp;ldquo; ให้เรียบร้อยด้วย
  for (var pass = 0; pass < 3; pass++) {
    final next = _decodeHtmlEntities(decoded);
    if (next == decoded) break;
    decoded = next;
  }

  return decoded
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _decodeHtmlEntities(String value) {
  const namedEntities = <String, String>{
    'amp': '&',
    'apos': "'",
    'gt': '>',
    'hellip': '…',
    'ldquo': '“',
    'lsquo': '‘',
    'lt': '<',
    'mdash': '—',
    'nbsp': ' ',
    'ndash': '–',
    'quot': '"',
    'rdquo': '”',
    'rsquo': '’',
  };

  return value.replaceAllMapped(
    RegExp(r'&(#(?:[xX][0-9a-fA-F]+|[0-9]+)|[a-zA-Z]+);'),
    (match) {
      final entity = match.group(1)!;
      if (entity.startsWith('#')) {
        final isHex =
            entity.length > 2 && (entity[1] == 'x' || entity[1] == 'X');
        final digits = entity.substring(isHex ? 2 : 1);
        final codePoint = int.tryParse(digits, radix: isHex ? 16 : 10);
        if (codePoint == null ||
            codePoint < 0 ||
            codePoint > 0x10ffff ||
            (codePoint >= 0xd800 && codePoint <= 0xdfff)) {
          return match.group(0)!;
        }
        return String.fromCharCode(codePoint);
      }
      return namedEntities[entity.toLowerCase()] ?? match.group(0)!;
    },
  );
}

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
          final time = _formatOpeningTimeRange(open, close);
          return [
            if (day.isNotEmpty) day,
            if (time.isNotEmpty) time,
          ].join(' ').trim();
        })
        .where((line) => line.isNotEmpty)
        .toList();
    if (entries.isNotEmpty) return entries.join('\n');
  }

  final open = '${detail['opening_time'] ?? ''}';
  final close = '${detail['closing_time'] ?? ''}';
  return _formatOpeningTimeRange(open, close);
}

String formatDestinationOpeningTimeSummary(Map<String, dynamic> detail) {
  final raw = detail['opening_hours'];
  if (raw is List) {
    for (final item in raw.whereType<Map>()) {
      final open = '${item['open'] ?? item['openTime'] ?? ''}';
      final close = '${item['close'] ?? item['closeTime'] ?? ''}';
      final time = _formatOpeningTimeRange(open, close);
      if (time.isNotEmpty) return time;
    }
  }

  final open = '${detail['opening_time'] ?? ''}';
  final close = '${detail['closing_time'] ?? ''}';
  return _formatOpeningTimeRange(open, close);
}

String _formatOpeningTimeRange(String open, String close) => [
  open,
  close,
].where((time) => time.isNotEmpty && time != '00:00').join(' – ');

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
