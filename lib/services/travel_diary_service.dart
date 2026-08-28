import 'package:http/http.dart' as http;
import 'package:myapp/model/travel_diary_entry.dart';
import 'package:myapp/services/api_client.dart';
import 'package:myapp/services/image_upload.dart';
import 'package:myapp/utils/destination_display.dart';

class TravelDiaryService {
  const TravelDiaryService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<List<TravelDiaryEntry>> load() async {
    try {
      final response = await _client.get('/mobile/diary');
      if (response.statusCode != 200) return [];
      final payload = ApiClient.decodeMap(response.body);
      final rawEntries = payload?['data'];
      if (rawEntries is! List) return [];

      final entries = rawEntries.whereType<Map>().map((raw) {
        final json = Map<String, dynamic>.from(raw);
        json['insight'] = stripHtmlText('${json['insight'] ?? ''}');
        return TravelDiaryEntry.fromJson(json);
      }).toList()..sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<bool> upsert(TravelDiaryEntry entry) async {
    try {
      final response = await _client.post(
        '/mobile/diary',
        body: entry.toJson(),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(String entryId) async {
    try {
      final response = await _client.delete(
        '/mobile/diary/${Uri.encodeComponent(entryId)}',
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Upload image เพื่อใช้ใน diary entry
  /// คืน URL ของรูปที่ upload ไปยัง server (relative path หรือ full URL)
  /// คืน null ถ้า upload ไม่สำเร็จ
  Future<String?> uploadImage(ImageUpload image) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _client.uri('/mobile/diary/upload'),
      )..files.add(image.asMultipartFile('image'));
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = ApiClient.decodeMap(response.body);
        final url = data?['url'] ?? data?['data']?['url'];
        if (url is String && url.isNotEmpty) return url;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
