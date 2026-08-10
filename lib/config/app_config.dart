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

  static String get apiBaseUrl =>
      _valueOrDefault(_configuredApiBaseUrl, 'http://localhost:5000/api');

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
