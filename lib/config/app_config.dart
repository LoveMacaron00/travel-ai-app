import 'package:flutter/foundation.dart';

/// ค่าที่ Flutter รับตอน compile ด้วย `--dart-define-from-file` เท่านั้น
///
/// ไฟล์นี้เก็บ URL และค่าที่เปิดเผยใน client ได้ ไม่เก็บ API key หรือ JWT secret
/// เพราะค่าที่ฝังในแอปสามารถถูกดึงออกจากไฟล์ APK/IPA ได้เสมอ
class AppConfig {
  const AppConfig._();

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const _configuredWebApiBaseUrl = String.fromEnvironment(
    'WEB_API_BASE_URL',
    defaultValue: '',
  );

  static const _configuredOsrmBaseUrl = String.fromEnvironment(
    'OSRM_BASE_URL',
    defaultValue: '',
  );

  static const _configuredMapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: '',
  );

  static const _configuredDefaultAvatarUrl = String.fromEnvironment(
    'DEFAULT_AVATAR_URL',
    defaultValue: '',
  );

  /// Web browser ติดต่อ API ผ่าน loopback ของเครื่องผู้พัฒนา ส่วน Android
  /// emulator ติดต่อ host ด้วย 10.0.2.2 ค่า WEB_API_BASE_URL จึงแยกจากกัน
  /// แต่ยัง fallback ไป API_BASE_URL เพื่อให้ build production เดิมใช้ได้
  static String get apiBaseUrl {
    final configuredApiUrl = _configuredApiBaseUrl.trim();
    if (kIsWeb) {
      final configuredWebUrl = _configuredWebApiBaseUrl.trim();
      if (configuredWebUrl.isNotEmpty) return configuredWebUrl;
      // .env รุ่นเดิมอาจมีเฉพาะ Android emulator URL ซึ่ง browser เข้าไม่ถึง
      if (configuredApiUrl.isNotEmpty &&
          Uri.tryParse(configuredApiUrl)?.host != '10.0.2.2') {
        return configuredApiUrl;
      }
      return 'http://localhost:5000/api';
    }
    return configuredApiUrl.isEmpty
        ? 'http://10.0.2.2:5000/api'
        : configuredApiUrl;
  }

  static String get osrmBaseUrl => _valueOrDefault(
    _configuredOsrmBaseUrl,
    'https://router.project-osrm.org',
  );

  static String get mapTileUrl => _valueOrDefault(
    _configuredMapTileUrl,
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static String get defaultAvatarUrl => _valueOrDefault(
    _configuredDefaultAvatarUrl,
    'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
  );

  static String _valueOrDefault(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
