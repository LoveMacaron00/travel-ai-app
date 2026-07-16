import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionState {
  String? token;
  Map<String, dynamic>? currentUser;
}

class StoredSession {
  const StoredSession({this.token, this.user});

  final String? token;
  final Map<String, dynamic>? user;
}

abstract interface class SessionStore {
  Future<StoredSession> load();
  Future<void> save(String token, Map<String, dynamic> user);
  Future<void> saveUser(Map<String, dynamic> user);
  Future<void> clear();
}

/// Persistence adapter ของ session แยกจาก AuthService เพื่อให้แทนด้วย fake ได้ใน test
class SharedPreferencesSessionStore implements SessionStore {
  static const _tokenKey = 'user_token';
  static const _userKey = 'current_user';

  @override
  Future<StoredSession> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    Map<String, dynamic>? user;
    if (userJson != null) {
      try {
        final decoded = jsonDecode(userJson);
        if (decoded is Map) user = Map<String, dynamic>.from(decoded);
      } on FormatException {
        // ลบ session ที่เสียหายเพื่อไม่ให้ parse ซ้ำทุกครั้งที่เปิดแอป
        await prefs.remove(_userKey);
      }
    }
    return StoredSession(token: token, user: user);
  }

  @override
  Future<void> save(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  @override
  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
