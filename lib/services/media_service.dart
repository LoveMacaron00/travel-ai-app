import 'package:flutter/foundation.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/services/api_client.dart';

class MediaService {
  const MediaService({required ApiClient client, bool useWebProxy = kIsWeb})
    : _client = client,
      _useWebProxy = useWebProxy;

  final ApiClient _client;
  final bool _useWebProxy;

  String get defaultAvatarUrl => AppConfig.defaultAvatarUrl;
  String fullUrl(String? path) {
    final resolved = _client.fullImageUrl(path);
    if (!_useWebProxy || resolved.isEmpty) return resolved;

    final mediaUri = Uri.tryParse(resolved);
    final apiUri = Uri.tryParse(_client.baseUrl);
    if (mediaUri == null || apiUri == null || !mediaUri.hasScheme) {
      return resolved;
    }
    final isApiOrigin =
        mediaUri.scheme == apiUri.scheme &&
        mediaUri.host == apiUri.host &&
        mediaUri.port == apiUri.port;
    if (isApiOrigin) return resolved;

    // Browser fetch ภาพข้าม origin ต้องอาศัย CORS ซึ่ง CDN ภายนอกบางแห่ง
    // ไม่ส่ง header นี้ จึงผ่าน proxy ที่ตรวจ allow-list ใน API เฉพาะบน Web
    return _client
        .uri('/mobile/media')
        .replace(queryParameters: {'url': resolved})
        .toString();
  }

  Map<String, String> headersFor(String url) => _client.mediaHeaders(url);
}
