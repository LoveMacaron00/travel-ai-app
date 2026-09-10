import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myapp/core/network/api_client.dart';
import 'package:myapp/features/media/data/image_upload.dart';

class ChatService {
  const ChatService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<Map<String, dynamic>> _readAssistantStream(
    http.StreamedResponse response, {
    required String fallbackMessage,
  }) async {
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      return {
        'success': false,
        'message': ApiClient.decodeMap(body)?['message'] ?? fallbackMessage,
      };
    }

    final answer = StringBuffer();
    List<dynamic> sources = const [];
    int? userMessageId;
    int? assistantMessageId;
    List<int> deletedAssistantMessageIds = const [];
    String? error;
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      try {
        final event = jsonDecode(line.substring(6));
        if (event['type'] == 'token') answer.write(event['text'] ?? '');
        if (event['type'] == 'done') {
          if (event['sources'] is List) sources = event['sources'];
          userMessageId = int.tryParse('${event['userMessageId'] ?? ''}');
          assistantMessageId = int.tryParse(
            '${event['assistantMessageId'] ?? ''}',
          );
          if (event['deletedAssistantMessageIds'] is List) {
            deletedAssistantMessageIds =
                (event['deletedAssistantMessageIds'] as List)
                    .map((id) => int.tryParse('$id'))
                    .whereType<int>()
                    .toList();
          }
        }
        if (event['type'] == 'error') error = '${event['message']}';
      } on FormatException {
        // ข้าม event ที่ไม่สมบูรณ์แล้วอ่าน stream ต่อ
      }
    }
    if (error != null) return {'success': false, 'message': error};
    return {
      'success': true,
      'data': {
        'answer': answer.toString(),
        'sources': sources,
        'user_message_id': userMessageId,
        'assistant_message_id': assistantMessageId,
        'deleted_assistant_message_ids': deletedAssistantMessageIds,
      },
    };
  }

  // GET /api/chat/sessions/latest — ดึง session แชทล่าสุดของผู้ใช้
  // ถ้ายังไม่เคยมี (404) จะตามด้วย POST /api/chat/sessions เพื่อสร้างใหม่
  // ใช้โดย: chatbot_screen.dart (_initializeChat)
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

  // GET /api/chat/sessions/:sessionId/messages — ดึงประวัติแชททั้ง session
  // server จะ enrich sources (ชื่อ/จังหวัด/รูปจาก source_chunk_ids) ให้ด้วย
  // ใช้โดย: chatbot_screen.dart (_initializeChat)
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

  // POST /api/chat/sessions/:sessionId/messages — ส่งข้อความหา AI Guide
  // คำตอบไหลกลับเป็น SSE stream (event: token/done/error) อ่านด้วย _readAssistantStream
  // ใช้โดย: chatbot_screen.dart (_requestAssistantAnswer)
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
      return _readAssistantStream(
        response,
        fallbackMessage: 'The assistant is unavailable',
      );
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // PATCH /api/chat/messages/:messageId — แก้ข้อความ user แล้วให้ AI ตอบใหม่
  // คำตอบใหม่ไหลกลับเป็น SSE พร้อม deletedAssistantMessageIds (id คำตอบเดิมที่ถูกลบ)
  // ใช้โดย: chatbot_screen.dart (_editMessage)
  Future<Map<String, dynamic>> updateMessage({
    required int messageId,
    required String message,
  }) async {
    try {
      final request = http.Request(
        'PATCH',
        _client.uri('/chat/messages/$messageId'),
      )..body = jsonEncode({'message': message});
      final response = await _client.send(request);
      return _readAssistantStream(
        response,
        fallbackMessage: 'Unable to edit this message',
      );
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // DELETE /api/chat/messages/:messageId — ลบข้อความ user (และคำตอบ AI ที่ตอบคู่กัน)
  // คืน deleted_message_ids เพื่อให้ UI ลบ bubble ออกให้ตรงกับฐานข้อมูล
  // ใช้โดย: chatbot_screen.dart (_deleteMessage)
  Future<Map<String, dynamic>> deleteMessage(int messageId) async {
    try {
      final response = await _client.delete('/chat/messages/$messageId');
      final payload = ApiClient.decodeMap(response.body);
      if (response.statusCode == 200 && payload != null) {
        return {'success': true, 'data': payload};
      }
      return {
        'success': false,
        'message': payload?['message'] ?? 'Unable to delete this message',
      };
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // POST /api/chat/navigation — บันทึกว่าผู้ใช้กด "ดูบนแผนที่" จาก source card ในแชท
  // เก็บลง chat_navigation_events เพื่อทำ analytics
  // ใช้โดย: chatbot/chat_message_widgets.dart (ปุ่มบน source card)
  Future<Map<String, dynamic>> logNavigation({
    required int messageId,
    required int destinationId,
    required int sessionId,
  }) async {
    try {
      final response = await _client.post(
        '/chat/navigation',
        body: {
          'messageId': messageId,
          'destinationId': destinationId,
          'sessionId': sessionId,
        },
      );
      final payload = ApiClient.decodeMap(response.body);
      if (response.statusCode == 201 && payload != null) {
        return {'success': true, 'data': payload};
      }
      return {
        'success': false,
        'message': payload?['message'] ?? 'Unable to log navigation',
      };
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // POST /api/chat/sessions/:sessionId/images — สแกนรูป (สถานที่/ป้าย/อาหาร)
  // ส่งเป็น multipart พร้อม mode + พิกัด GPS (ถ้าถ่ายสด) รอ JSON คำตอบเดียว
  // ใช้โดย: chatbot_screen.dart (_pickAndAnalyzeImage)
  Future<Map<String, dynamic>> sendImage({
    required int sessionId,
    required ImageUpload image,
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
      request.files.add(image.asMultipartFile('image'));

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
