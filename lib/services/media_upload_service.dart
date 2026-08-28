import 'package:http/http.dart' as http;
import 'package:myapp/services/api_client.dart';
import 'package:myapp/services/image_upload.dart';

/// Centralized multipart upload helper.
/// Previously duplicated in:
/// - `auth_service.dart:108 uploadProfileImage`
/// - `travel_diary_service.dart:57 uploadImage`
/// - `chat_service.dart:178 sendImage` (partial)
/// Each duplicated `http.MultipartRequest` + `client.send` + `Response.fromStream` + `decodeMap`.
/// This keeps behavior identical (same field name, same error handling) but single source.
class MediaUploadService {
  const MediaUploadService(this._client);

  final ApiClient _client;

  /// Generic single-file upload. Returns file URL (`/uploads/...`) or null.
  /// Mirrors `TravelDiaryService.uploadImage` response parsing:
  /// `data['url'] ?? data['data']['url']`
  Future<String?> uploadSingle({
    required String endpoint,
    required ImageUpload image,
    String field = 'image',
  }) async {
    try {
      final request = http.MultipartRequest('POST', _client.uri(endpoint))
        ..files.add(image.asMultipartFile(field));
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

  /// Upload and return full JSON map (for auth profile which needs user object).
  /// Keeps `AuthService.uploadProfileImage` success envelope.
  Future<Map<String, dynamic>?> uploadWithJson({
    required String endpoint,
    required ImageUpload image,
    String field = 'image',
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _client.uri(endpoint))
        ..files.add(image.asMultipartFile(field));
      if (fields != null) request.fields.addAll(fields);
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      return ApiClient.decodeMap(response.body);
    } catch (_) {
      return null;
    }
  }
}
