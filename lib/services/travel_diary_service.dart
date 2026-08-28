import 'package:myapp/model/travel_diary_entry.dart';
import 'package:myapp/services/api_client.dart';
import 'package:myapp/services/image_upload.dart';
import 'package:myapp/services/media_upload_service.dart';
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
  /// Delegates to [MediaUploadService] to avoid duplication with Auth/Chat.
  Future<String?> uploadImage(ImageUpload image) =>
      MediaUploadService(_client).uploadSingle(
        endpoint: '/mobile/diary/upload',
        image: image,
        field: 'image',
      );
}
