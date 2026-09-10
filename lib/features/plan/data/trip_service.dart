import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/network/api_client.dart';

class TripService {
  const TripService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  // POST /api/trips — สั่งสร้างแผนเที่ยวจาก AI (รับ input จากฟอร์มหน้า Plan)
  // server ตอบกลับเป็น SSE stream อ่าน event done/error จนได้ tripId
  // แล้วตามด้วย GET /api/trips/:tripId เพื่อเอา plan_data ฉบับเต็ม
  // ใช้โดย: plan_screen.dart (_generate)
  Future<Map<String, dynamic>> createTravelPlan(
    Map<String, dynamic> input,
  ) async {
    try {
      final request = http.Request('POST', _client.uri('/trips'))
        ..body = jsonEncode(input);
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        final fallback =
            'The AI travel planner is temporarily unavailable. Please try again.';
        return {
          'success': false,
          'message':
              ApiClient.decodeMap(body)?['message']?.toString() ?? fallback,
        };
      }

      int? tripId;
      String? error;
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        try {
          final event = jsonDecode(line.substring(6));
          if (event['type'] == 'done') {
            tripId = int.tryParse('${event['tripId']}');
          }
          if (event['type'] == 'error') error = '${event['message']}';
        } on FormatException {
          // ข้ามเฉพาะ SSE event ที่ถูกตัดกลางบรรทัด
        }
      }
      if (tripId == null) {
        return {'success': false, 'message': error ?? 'Plan generation failed'};
      }
      return getTravelPlan(tripId);
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // GET /api/trips/:tripId — โหลดแผนเที่ยวที่บันทึกไว้ (รวม plan_data จาก trip_plans)
  // ใช้โดย: plan_screen.dart (_loadExistingPlan เมื่อเปิดจาก Profile)
  Future<Map<String, dynamic>> getTravelPlan(int tripId) async {
    try {
      final response = await _client.get('/trips/$tripId');
      if (response.statusCode != 200) {
        return {'success': false, 'message': 'Unable to load plan'};
      }
      return {'success': true, 'data': jsonDecode(response.body)};
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // PUT /api/trips/:tripId/plan — บันทึกการแก้ไขแผน (ลบ/เพิ่ม/สลับลำดับสถานที่)
  // ส่ง plan_data ทั้งก้อนกลับ server เพื่อ upsert ลง trip_plans
  // ใช้โดย: plan_screen.dart (_savePlanChanges)
  Future<Map<String, dynamic>> updateTravelPlan(
    int tripId,
    Map<String, dynamic> planData,
  ) async {
    try {
      final response = await _client.put('/trips/$tripId/plan', body: planData);
      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': ApiClient.responseMessage(
            response,
            'Unable to save plan changes',
          ),
        };
      }
      return {'success': true};
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // GET /api/trips — ประวัติแผนเที่ยวที่ผู้ใช้เคยสร้าง (20 รายการล่าสุด)
  // ใช้โดย: profile_screen.dart (_loadTrips)
  Future<Map<String, dynamic>> listMyPlans() async {
    try {
      final response = await _client.get('/trips');
      if (response.statusCode != 200) {
        return {'success': false, 'message': 'Unable to load saved plans'};
      }
      final decoded = jsonDecode(response.body);
      return {'success': true, 'data': decoded is List ? decoded : const []};
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // DELETE /api/trips/:tripId — ลบประวัติแผนเที่ยว
  // ใช้โดย: profile_screen.dart (_deleteTrip)
  Future<Map<String, dynamic>> deletePlan(int tripId) async {
    try {
      final response = await _client.delete('/trips/$tripId');
      if (response.statusCode != 200) {
        return {'success': false, 'message': 'Unable to delete plan'};
      }
      return {'success': true};
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // GET {osrmBaseUrl}/route/v1/:profile/:from;:to — ขอเส้นทางถนนจริงจาก OSRM
  // ใช้กับเฉพาะ car/walking/bus (mode อื่นใช้เส้นตรงบนแผนที่แทน)
  // ใช้โดย: plan_screen.dart (_buildRoute), plan_navigation_screen.dart
  Future<List<List<double>>> getRoadRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String mode = 'driving',
  }) async {
    if (!const {'car', 'walking', 'bus', 'cycling', 'driving'}.contains(mode)) {
      return const [];
    }
    final profile = mode == 'walking'
        ? 'foot'
        : mode == 'cycling'
        ? 'bike'
        : 'driving';
    try {
      final uri = Uri.parse(
        '${AppConfig.osrmBaseUrl}/route/v1/$profile/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson',
      );
      final response = await _client.httpClient.get(uri);
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body);
      final coordinates =
          data['routes']?[0]?['geometry']?['coordinates'] as List?;
      return (coordinates ?? const [])
          .whereType<List>()
          .map(
            (point) => [
              (point[1] as num).toDouble(),
              (point[0] as num).toDouble(),
            ],
          )
          .toList();
    } catch (_) {
      // OSRM เป็นข้อมูลเสริม หน้าจอยังแสดงหมุดได้เมื่อหาเส้นทางไม่สำเร็จ
      return const [];
    }
  }

  // GET /api/mobile/plan-options — ตัวเลือก interests / transport modes
  // ที่ admin ปรับได้ ใช้แสดงในฟอร์มสร้างแผน
  // ใช้โดย: plan_screen.dart (_loadPlanOptions)
  Future<Map<String, dynamic>> getPlanOptions() async {
    try {
      final response = await _client.get('/mobile/plan-options');
      if (response.statusCode != 200) {
        return {'success': false, 'message': 'Unable to load plan options'};
      }
      final decoded = jsonDecode(response.body);
      return {'success': true, 'data': decoded['data']};
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }
}
