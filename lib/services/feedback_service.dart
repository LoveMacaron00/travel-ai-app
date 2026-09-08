import 'dart:convert';

import 'package:myapp/services/api_client.dart';

class FeedbackService {
  const FeedbackService({
    required ApiClient client,
  }) : _client = client;

  final ApiClient _client;

  // POST /api/mobile/feedback — ส่ง feedback ของผู้ใช้ถึงทีมงาน
  // ใช้โดย: widgets/feedback_dialog.dart (เรียกจาก profile_screen.dart)
  Future<Map<String, dynamic>> submitFeedback({
    required String message,
  }) async {
    try {
      final response = await _client.post(
        '/mobile/feedback',
        body: {'message': message},
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        return {
          'success': false,
          'message': ApiClient.responseMessage(response, response.body),
        };
      }
      return {
        'success': true,
        'data': jsonDecode(response.body),
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // GET /api/mobile/feedback/my — ประวัติ feedback ที่ผู้ใช้เคยส่ง
  // ใช้โดย: feedback_history_screen.dart
  Future<Map<String, dynamic>> getUserFeedback() async {
    try {
      final response = await _client.get('/mobile/feedback/my');
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': ApiClient.responseMessage(response, response.body),
        };
      }
      final decoded = jsonDecode(response.body);
      return {
        'success': true,
        'data': decoded is List ? decoded : const [],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
