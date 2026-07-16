/// ค่าที่ Flutter รับตอน compile ด้วย `--dart-define-from-file` เท่านั้น
///
/// ไฟล์นี้เก็บ URL และค่าที่เปิดเผยใน client ได้ ไม่เก็บ API key หรือ JWT secret
/// เพราะค่าที่ฝังในแอปสามารถถูกดึงออกจากไฟล์ APK/IPA ได้เสมอ
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  static const osrmBaseUrl = String.fromEnvironment(
    'OSRM_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const mapTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const defaultAvatarUrl = String.fromEnvironment(
    'DEFAULT_AVATAR_URL',
    defaultValue:
        'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
  );
}
