import 'package:http/http.dart' as http;
import 'package:myapp/services/api_client.dart';
import 'package:myapp/services/session_store.dart';

class AuthService {
  const AuthService({
    required ApiClient client,
    required SessionState session,
    required SessionStore store,
  }) : _client = client,
       _session = session,
       _store = store;

  final ApiClient _client;
  final SessionState _session;
  final SessionStore _store;

  String? get token => _session.token;
  Map<String, dynamic>? get currentUser => _session.currentUser;

  Future<void> initSession() async {
    final stored = await _store.load();
    _session.token = stored.token;
    _session.currentUser = stored.user;
  }

  Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    _session.token = token;
    _session.currentUser = user;
    await _store.save(token, user);
  }

  Future<void> clearSession() async {
    _session.token = null;
    _session.currentUser = null;
    await _store.clear();
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) => _authenticate('/users/register', email: email, password: password);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _authenticate('/users/login', email: email, password: password);

  Future<Map<String, dynamic>> _authenticate(
    String path, {
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        path,
        body: {'email': email, 'password': password},
      );
      final data = ApiClient.decodeMap(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data != null) {
        final token = data['token']?.toString();
        final rawUser = data['user'];
        if (token != null && rawUser is Map) {
          await _saveSession(token, Map<String, dynamic>.from(rawUser));
        }
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': ApiClient.responseMessage(response, 'Authentication failed'),
      };
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String username,
    required List<String> interests,
    String? profileImageUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'username': username,
        'interests': interests,
        if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      };
      final response = await _client.put('/users/profile', body: body);
      final data = ApiClient.decodeMap(response.body);
      if (response.statusCode == 200 && data != null) {
        await _saveUserFromResponse(data);
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': ApiClient.responseMessage(
          response,
          'Failed to update profile',
        ),
      };
    } catch (error) {
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  Future<Map<String, dynamic>> uploadProfileImage(String filePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _client.uri('/users/profile/upload-image'),
      )..files.add(await http.MultipartFile.fromPath('image', filePath));
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      final data = ApiClient.decodeMap(response.body);
      if (response.statusCode == 200 && data != null) {
        await _saveUserFromResponse(data);
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': ApiClient.responseMessage(
          response,
          'Failed to upload image: status ${response.statusCode}',
        ),
      };
    } catch (error) {
      return {
        'success': false,
        'message': 'Network error during image upload: $error',
      };
    }
  }

  Future<void> _saveUserFromResponse(Map<String, dynamic> data) async {
    final rawUser = data['user'];
    if (rawUser is! Map) return;
    final user = Map<String, dynamic>.from(rawUser);
    _session.currentUser = user;
    await _store.saveUser(user);
  }
}
