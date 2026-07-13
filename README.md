# GoThai mobile app

## Environment

Copy `.env.example` to `.env`, then run Flutter with the compile-time environment file:

```powershell
Copy-Item .env.example .env
flutter run --dart-define-from-file=.env
```

`API_BASE_URL` defaults to the Android emulator host (`10.0.2.2`). Set it to the
LAN IP or deployed API URL when running on a physical device or in production.

Build commands must receive the same environment file:

```powershell
flutter build apk --dart-define-from-file=.env
```
