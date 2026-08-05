import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myapp/config/app_config.dart';
import 'package:myapp/services/api_client.dart';

class TripService {
  const TripService({required ApiClient client}) : _client = client;

  final ApiClient _client;

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
}
