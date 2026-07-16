import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myapp/services/api_client.dart';

class ChatService {
  const ChatService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<Map<String, dynamic>> getOrCreateSession() async {
    try {
      var response = await _client.get('/chat/sessions/latest');
      if (response.statusCode == 404) {
        response = await _client.post('/chat/sessions', body: const {});
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'Unable to open chat history'};
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  Future<Map<String, dynamic>> getMessages(int sessionId) async {
    try {
      final response = await _client.get('/chat/sessions/$sessionId/messages');
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'Unable to load chat history'};
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required int sessionId,
    required String message,
  }) async {
    try {
      final request = http.Request(
        'POST',
        _client.uri('/chat/sessions/$sessionId/messages'),
      )..body = jsonEncode({'message': message});
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        return {'success': false, 'message': 'The assistant is unavailable'};
      }

      final answer = StringBuffer();
      List<dynamic> sources = const [];
      String? error;
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        try {
          final event = jsonDecode(line.substring(6));
          if (event['type'] == 'token') answer.write(event['text'] ?? '');
          if (event['type'] == 'done' && event['sources'] is List) {
            sources = event['sources'];
          }
          if (event['type'] == 'error') error = '${event['message']}';
        } on FormatException {
          // ข้าม event ที่ไม่สมบูรณ์แล้วอ่าน stream ต่อ
        }
      }
      if (error != null) return {'success': false, 'message': error};
      return {
        'success': true,
        'data': {'answer': answer.toString(), 'sources': sources},
      };
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  Future<Map<String, dynamic>> sendImage({
    required int sessionId,
    required String filePath,
    required String mode,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _client.uri('/chat/sessions/$sessionId/images'),
      );
      request.fields['mode'] = mode;
      if (latitude != null) request.fields['latitude'] = '$latitude';
      if (longitude != null) request.fields['longitude'] = '$longitude';
      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      final payload = ApiClient.decodeMap(response.body);
      if (response.statusCode == 200 && payload != null) {
        return {'success': true, 'data': payload};
      }
      return {
        'success': false,
        'message':
            payload?['message'] ??
            (response.statusCode == 413
                ? 'The image is too large. Please use a photo under 2 MB.'
                : 'The photo could not be analyzed.'),
      };
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }
}
