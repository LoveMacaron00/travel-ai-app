import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// ข้อมูลรูปสำหรับ multipart ที่ใช้ bytes แทน path จึงทำงานได้ทั้ง native
/// และ browser ซึ่ง XFile.path เป็น blob URL ไม่ใช่ path ของไฟล์จริง
class ImageUpload {
  const ImageUpload({
    required this.bytes,
    required this.filename,
    this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String? mimeType;

  http.MultipartFile asMultipartFile(String field) =>
      http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: _safeFilename(filename),
        contentType: MediaType.parse(_normalizedMimeType()),
      );

  String _normalizedMimeType() {
    final declared = mimeType?.trim().toLowerCase();
    if (declared == 'image/jpg') return 'image/jpeg';
    if (declared == 'image/jpeg' ||
        declared == 'image/png' ||
        declared == 'image/gif' ||
        declared == 'image/webp') {
      return declared!;
    }

    final lowerName = filename.toLowerCase();
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.gif')) return 'image/gif';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  static String _safeFilename(String value) {
    final name = value.replaceAll('\\', '/').split('/').last.trim();
    return name.isEmpty ? 'upload' : name;
  }
}
