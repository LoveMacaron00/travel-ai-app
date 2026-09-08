import 'dart:convert';

import 'package:myapp/services/api_client.dart';

class DestinationService {
  DestinationService({required ApiClient client}) : _client = client;

  final ApiClient _client;
  List<dynamic>? _cache;
  DateTime? _cacheTime;
  String? _cacheLanguage;

  // GET /api/mobile/destinations — รายการสถานที่ท่องเที่ยวทั้งหมด (มี cache 10 นาที)
  // ใช้โดย: home_screen.dart, map_screen.dart, plan_screen.dart, all_destinations_screen.dart
  Future<Map<String, dynamic>> getDestinations({
    int? limit,
    bool forceRefresh = false,
  }) async {
    final cacheFresh =
        _cache != null &&
        _cacheTime != null &&
        _cacheLanguage == _client.languageCode &&
        DateTime.now().difference(_cacheTime!) < const Duration(minutes: 10);
    if (!forceRefresh && cacheFresh) {
      final cached = limit == null
          ? List<dynamic>.from(_cache!)
          : _cache!.take(limit).toList();
      return {'success': true, 'data': cached, 'cached': true};
    }

    try {
      final query = limit == null ? '' : '?limit=$limit';
      final response = await _client.get('/mobile/destinations$query');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final destinations = data['data'] ?? [];
        // เก็บ cache เฉพาะรายการเต็ม เพื่อไม่ให้หน้า All ได้ข้อมูลจากชุด limit
        if (limit == null) {
          _cache = List<dynamic>.from(destinations);
          _cacheTime = DateTime.now();
          _cacheLanguage = _client.languageCode;
        }
        return {'success': true, 'data': destinations};
      }
      return {
        'success': false,
        'message': ApiClient.responseMessage(
          response,
          'Failed to load destinations',
        ),
      };
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // GET /api/mobile/destinations/:id — รายละเอียดสถานที่หนึ่งแห่ง
  // ใช้โดย: destination_detail_screen.dart, plan/plan_details.dart
  Future<Map<String, dynamic>> getDestinationDetails(int id) async {
    try {
      final response = await _client.get('/mobile/destinations/$id');
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {
        'success': false,
        'message': ApiClient.responseMessage(
          response,
          'Unable to load place details',
        ),
      };
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // GET /api/mobile/provinces — รายชื่อจังหวัดสำหรับ dropdown ในแบบฟอร์มสร้างแผน
  // ใช้โดย: plan_screen.dart (_loadProvinces)
  Future<Map<String, dynamic>> getProvinces() async {
    try {
      final response = await _client.get('/mobile/provinces');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }
      return {
        'success': false,
        'message': ApiClient.responseMessage(
          response,
          'Failed to load provinces',
        ),
      };
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }
}
