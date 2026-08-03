# GoThai Mobile App

แอป Flutter สำหรับค้นหาสถานที่ วางแผนเที่ยว แชทกับผู้ช่วย และวิเคราะห์ภาพสถานที่/ป้ายภาษาไทย/อาหารไทย

ภาพรวมทั้งระบบและจุดเริ่มอ่าน source code อยู่ที่ [คู่มืออ่านโค้ดภาษาไทย](../doc/CODE_GUIDE_TH.md)

## ตั้งค่า Environment

Copy `.env.example` to `.env`, then run Flutter with the compile-time environment file:

```powershell
Copy-Item .env.example .env
flutter run --dart-define-from-file=.env
```

`API_BASE_URL` ใช้กับ Android emulator (`10.0.2.2`) และ native platform ส่วน
`WEB_API_BASE_URL` ใช้กับ Chrome (`localhost`) ทำให้ใช้ `.env` ชุดเดียวพัฒนาได้ทั้งสองแบบ
หากรันบนมือถือจริงให้เปลี่ยน `API_BASE_URL` เป็น LAN IP หรือ URL ของ server ที่ deploy แล้ว

รันบน Chrome ด้วยพอร์ตคงที่ที่เตรียมไว้ใน CORS ของ API:

```powershell
flutter run -d chrome --web-port 7357 --dart-define-from-file=.env
```

Geolocation บนเว็บใช้ได้ผ่าน `localhost` หรือ HTTPS เท่านั้น เมื่อ deploy เว็บผ่าน
HTTPS ต้องตั้ง `WEB_API_BASE_URL` เป็น HTTPS ด้วย มิฉะนั้น Chrome จะบล็อก mixed content

ไฟล์นี้รับเฉพาะค่าที่เปิดเผยใน mobile app ได้ ห้ามใส่ AI API key หรือ JWT secret เพราะค่า compile-time สามารถถูกดึงออกจาก APK/IPA ได้

Build commands must receive the same environment file:

```powershell
flutter build apk --dart-define-from-file=.env
flutter build web --dart-define-from-file=.env
```

## ตรวจสอบโค้ด

```powershell
dart format lib test
flutter analyze
flutter test
```
