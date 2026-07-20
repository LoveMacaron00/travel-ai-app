import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myapp/config/app_config.dart';

typedef TokenProvider = String? Function();
typedef LanguageProvider = String Function();

/// HTTP boundary กลางของ mobile app
///
/// class นี้ไม่รู้จัก UI หรือ SharedPreferences จึงส่ง mock `http.Client` เข้ามา
/// ทดสอบแต่ละ domain service ได้โดยไม่ต้องเปิด server จริง
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String baseUrl = AppConfig.apiBaseUrl,
    required TokenProvider tokenProvider,
    LanguageProvider? languageProvider,
  }) : httpClient = httpClient ?? http.Client(),
       baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _tokenProvider = tokenProvider,
       _languageProvider = languageProvider ?? (() => 'th');

  final http.Client httpClient;
  final String baseUrl;
  final TokenProvider _tokenProvider;
  final LanguageProvider _languageProvider;

  String get languageCode => _languageProvider();

  Uri uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }

  Map<String, String> headers({bool json = true}) {
    final headers = <String, String>{
      if (json) 'Content-Type': 'application/json',
      'Accept-Language': languageCode,
    };
    final token = _tokenProvider();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String path) =>
      httpClient.get(uri(path), headers: headers());

  Future<http.Response> post(String path, {Object? body}) => httpClient.post(
    uri(path),
    headers: headers(),
    body: body == null ? null : jsonEncode(body),
  );

  Future<http.Response> put(String path, {Object? body}) => httpClient.put(
    uri(path),
    headers: headers(),
    body: body == null ? null : jsonEncode(body),
  );

  Future<http.Response> delete(String path) =>
      httpClient.delete(uri(path), headers: headers());

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers(json: request is! http.MultipartRequest));
    return httpClient.send(request);
  }

  static Map<String, dynamic>? decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  static String responseMessage(http.Response response, String fallback) =>
      decodeMap(response.body)?['message']?.toString() ?? fallback;

  String fullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final apiUri = Uri.parse(baseUrl);
    final origin = apiUri.replace(path: '', query: null, fragment: null);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '${origin.toString().replaceFirst(RegExp(r'/$'), '')}$normalizedPath';
  }

  /// คืน Authorization header เฉพาะ private media บน API origin ของเรา
  /// เพื่อไม่ให้ user token ถูกส่งไปกับรูปภายนอก เช่น TAT หรือ CDN
  Map<String, String> mediaHeaders(String imageUrl) {
    final token = _tokenProvider();
    if (token == null || token.isEmpty || !_isPrivateMediaUrl(imageUrl)) {
      return const {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  bool _isPrivateMediaUrl(String imageUrl) {
    final resolved = Uri.tryParse(fullImageUrl(imageUrl));
    final api = Uri.tryParse(baseUrl);
    if (resolved == null || api == null) return false;
    return resolved.scheme == api.scheme &&
        resolved.host == api.host &&
        resolved.port == api.port &&
        (resolved.path.startsWith('/uploads/') ||
            (resolved.path.startsWith('/api/chat/messages/') &&
                resolved.path.endsWith('/image')));
  }
}
