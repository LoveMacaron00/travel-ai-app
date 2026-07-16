# GoThai Mobile App

แอป Flutter สำหรับค้นหาสถานที่ วางแผนเที่ยว แชทกับผู้ช่วย และวิเคราะห์ภาพสถานที่/ป้ายภาษาไทย/อาหารไทย

ภาพรวมทั้งระบบและจุดเริ่มอ่าน source code อยู่ที่ [คู่มืออ่านโค้ดภาษาไทย](../doc/CODE_GUIDE_TH.md)

## ตั้งค่า Environment

Copy `.env.example` to `.env`, then run Flutter with the compile-time environment file:

```powershell
Copy-Item .env.example .env
flutter run --dart-define-from-file=.env
```

`API_BASE_URL` มีค่าเริ่มต้นเป็น host ของ Android emulator (`10.0.2.2`) หากรันบนมือถือจริงให้เปลี่ยนเป็น LAN IP หรือ URL ของ server ที่ deploy แล้ว

ไฟล์นี้รับเฉพาะค่าที่เปิดเผยใน mobile app ได้ ห้ามใส่ AI API key หรือ JWT secret เพราะค่า compile-time สามารถถูกดึงออกจาก APK/IPA ได้

Build commands must receive the same environment file:

```powershell
flutter build apk --dart-define-from-file=.env
```

## ตรวจสอบโค้ด

```powershell
dart format lib test
flutter analyze
flutter test
```
