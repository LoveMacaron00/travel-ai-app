import 'package:myapp/model/travel_diary_entry.dart';
import 'package:myapp/services/api_client.dart';
import 'package:myapp/services/image_upload.dart';
import 'package:myapp/services/media_upload_service.dart';
import 'package:myapp/utils/destination_display.dart';

class TravelDiaryService {
  const TravelDiaryService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  // GET /api/mobile/diary — โหลดบันทึก Smart Diary ทั้งหมดของผู้ใช้ (เรียงใหม่→เก่า)
  // ใช้โดย: travel_diary_screen.dart, travel_footprint_screen.dart (ผ่าน diaryAutomation)
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

  // POST /api/mobile/diary — เพิ่ม/อัปเดต (upsert) บันทึก diary หนึ่งรายการ
  // ใช้โดย: travel_diary_screen.dart (บันทึกฟอร์ม), travel_diary_automation_service.dart
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

  // DELETE /api/mobile/diary/:entryId — ลบบันทึก diary หนึ่งรายการ
  // ใช้โดย: travel_diary_screen.dart
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

  // POST /api/mobile/diary/upload — อัปโหลดรูปประกอบ diary แบบ multipart
  // server คืน URL รูป (relative path) นำไปใส่ใน entry ก่อนบันทึก
  // ใช้โดย: travel_diary_screen.dart, travel_diary_automation_service.dart
  Future<String?> uploadImage(ImageUpload image) =>
      MediaUploadService(_client).uploadSingle(
        endpoint: '/mobile/diary/upload',
        image: image,
        field: 'image',
      );
}
