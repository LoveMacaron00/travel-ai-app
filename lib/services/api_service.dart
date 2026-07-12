import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000/api';
  static const String defaultAvatarUrl =
      'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';

  static String? token;
  static Map<String, dynamic>? currentUser;
  static List<dynamic>? _destinationCache;
  static DateTime? _destinationCacheTime;

  static Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('user_token');
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      try {
        currentUser = jsonDecode(userJson);
      } catch (_) {}
    }
  }

  static Future<void> saveSession(
    String userToken,
    Map<String, dynamic> user,
  ) async {
    token = userToken;
    currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_token', userToken);
    await prefs.setString('current_user', jsonEncode(user));
  }

  static Future<void> clearSession() async {
    token = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_token');
    await prefs.remove('current_user');
  }

  static Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: _getHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['token'] != null && data['user'] != null) {
          await saveSession(data['token'].toString(), data['user']);
        }
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: _getHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null && data['user'] != null) {
          await saveSession(data['token'].toString(), data['user']);
        }
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required String username,
    required List<String> interests,
    String? profileImageUrl,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'username': username,
        'interests': interests,
      };
      if (profileImageUrl != null) {
        body['profile_image_url'] = profileImageUrl;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          currentUser = data['user'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_user', jsonEncode(currentUser));
        }
        return {'success': true, 'data': data};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final origin = baseUrl.replaceAll('/api', '');
    return '$origin$path';
  }

  static Future<Map<String, dynamic>> uploadProfileImageFile(
    String filePath,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/users/profile/upload-image');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          currentUser = data['user'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_user', jsonEncode(currentUser));
        }
        return {'success': true, 'data': data};
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to upload image',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Failed to upload image: status ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error during image upload: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getDestinations({
    int? limit,
    bool forceRefresh = false,
  }) async {
    final cacheFresh =
        _destinationCache != null &&
        _destinationCacheTime != null &&
        DateTime.now().difference(_destinationCacheTime!) <
            const Duration(minutes: 10);
    if (!forceRefresh && cacheFresh) {
      final cached = limit == null
          ? List<dynamic>.from(_destinationCache!)
          : _destinationCache!.take(limit).toList();
      return {'success': true, 'data': cached, 'cached': true};
    }
    try {
      String url = '$baseUrl/mobile/destinations';
      if (limit != null) {
        url += '?limit=$limit';
      }
      final response = await http.get(Uri.parse(url), headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final destinations = data['data'] ?? [];
        if (limit == null) {
          _destinationCache = List<dynamic>.from(destinations);
          _destinationCacheTime = DateTime.now();
        }
        return {'success': true, 'data': destinations};
      }

      String message = 'Failed to load  destinations';
      try {
        final error = jsonDecode(response.body);
        message = error['message'] ?? message;
      } catch (_) {}

      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getDestinationDetails(
    int destinationId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mobile/destinations/$destinationId'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'Unable to load place details'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createTravelPlan(
    Map<String, dynamic> input,
  ) async {
    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/trips'))
        ..headers.addAll(_getHeaders())
        ..body = jsonEncode(input);
      final response = await request.send();
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        String message =
            'The AI travel planner is temporarily unavailable. Please try again.';
        try {
          final data = jsonDecode(body);
          if (data is Map && data['message'] != null) {
            message = '${data['message']}';
          }
        } catch (_) {}
        return {'success': false, 'message': message};
      }
      int? tripId;
      String? error;
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) {
          continue;
        }
        try {
          final event = jsonDecode(line.substring(6));
          if (event['type'] == 'done') {
            tripId = int.tryParse('${event['tripId']}');
          }
          if (event['type'] == 'error') {
            error = '${event['message']}';
          }
        } catch (_) {}
      }
      if (tripId == null) {
        return {'success': false, 'message': error ?? 'Plan generation failed'};
      }
      return getTravelPlan(tripId);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTravelPlan(int tripId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/$tripId'),
        headers: _getHeaders(),
      );
      if (response.statusCode != 200) {
        return {'success': false, 'message': 'Unable to load plan'};
      }
      return {'success': true, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<List<double>>> getRoadRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String mode = 'driving',
  }) async {
    final profile = mode == 'walking'
        ? 'foot'
        : mode == 'cycling'
        ? 'bike'
        : 'driving';
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/$profile/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body);
      final coords = data['routes']?[0]?['geometry']?['coordinates'] as List?;
      return (coords ?? const [])
          .whereType<List>()
          .map((p) => [(p[1] as num).toDouble(), (p[0] as num).toDouble()])
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<String, dynamic>> askTravelAssistant({
    required String message,
    String? province,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mobile/chat'),
        headers: _getHeaders(),
        body: jsonEncode({
          'message': message,
          if (province != null && province.isNotEmpty) 'province': province,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }

      String errorMessage = 'Failed to ask travel assistant';
      try {
        final error = jsonDecode(response.body);
        errorMessage = error['message'] ?? errorMessage;
      } catch (_) {}

      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getOrCreateChatSession() async {
    try {
      var response = await http.get(
        Uri.parse('$baseUrl/chat/sessions/latest'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 404) {
        response = await http.post(
          Uri.parse('$baseUrl/chat/sessions'),
          headers: _getHeaders(),
          body: jsonEncode({}),
        );
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'Unable to open chat history'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getChatMessages(int sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/sessions/$sessionId/messages'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': 'Unable to load chat history'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required int sessionId,
    required String message,
  }) async {
    try {
      final request =
          http.Request(
              'POST',
              Uri.parse('$baseUrl/chat/sessions/$sessionId/messages'),
            )
            ..headers.addAll(_getHeaders())
            ..body = jsonEncode({'message': message});
      final response = await request.send();
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
        } catch (_) {}
      }
      if (error != null) return {'success': false, 'message': error};
      return {
        'success': true,
        'data': {'answer': answer.toString(), 'sources': sources},
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
