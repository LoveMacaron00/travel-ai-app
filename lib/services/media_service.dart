import 'package:myapp/config/app_config.dart';
import 'package:myapp/services/api_client.dart';

class MediaService {
  const MediaService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  String get defaultAvatarUrl => AppConfig.defaultAvatarUrl;
  String fullUrl(String? path) => _client.fullImageUrl(path);
  Map<String, String> headersFor(String url) => _client.mediaHeaders(url);
}
