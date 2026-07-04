import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000/api';
  static const String defaultAvatarUrl = 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';

  static String? token;
  static Map<String, dynamic>? currentUser;

  static Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };
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

  static Future<void> saveSession(String userToken, Map<String, dynamic> user) async {
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
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['token'] != null && data['user'] != null) {
          await saveSession(data['token'].toString(), data['user']);
        }
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
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
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null && data['user'] != null) {
          await saveSession(data['token'].toString(), data['user']);
        }
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required String username,
    required List<String> interests,
    required bool isPrivateLocation,
    String? profileImageUrl,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'username': username,
        'interests': interests,
        'is_private_location': isPrivateLocation,
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
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
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

  static Future<Map<String, dynamic>> uploadProfileImageFile(String filePath) async {
    try {
      final uri = Uri.parse('$baseUrl/users/profile/upload-image');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          filePath,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          currentUser = data['user'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_user', jsonEncode(currentUser));
        }
        return {
          'success': true,
          'data': data,
        };
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

  static Future<Map<String, dynamic>> getPopularDestinations({
    int? limit,
  }) async {
    try {
      String url = '$baseUrl/mobile/popular-destinations';
      if (limit != null) {
        url += '?limit=$limit';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? [],
        };
      }

      String message = 'Failed to load popular destinations';
      try {
        final error = jsonDecode(response.body);
        message = error['message'] ?? message;
      } catch (_) {}

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
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
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      }

      String errorMessage = 'Failed to ask travel assistant';
      try {
        final error = jsonDecode(response.body);
        errorMessage = error['message'] ?? errorMessage;
      } catch (_) {}

      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}
