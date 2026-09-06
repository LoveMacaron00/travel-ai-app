import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// แหล่งข้อมูลตำแหน่งกลางของแอป ใช้ instance เดียวร่วมกันระหว่าง Home, Map
/// และ Image Scan เพื่อลดการขอ permission และการอ่าน GPS ซ้ำโดยไม่จำเป็น
class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  LatLng? _currentPosition;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<Position>? _positionSubscription;

  LatLng? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // เกลี่ยตำแหน่งด้วยค่าเฉลี่ยถ่วงน้ำหนัก (exponential smoothing) เพื่อลดอาการ
  // ระยะทางบนหน้าจอเด้ง/ไม่ตรงกันระหว่างหน้า จากความคลาดเคลื่อนรายครั้งของ GPS
  // fix แรกใช้ค่าดิบทันที หลังจากนั้นผสมกับค่าเดิม 50/50 ต่อการอัปเดตแต่ละครั้ง
  LatLng _smoothPosition(LatLng raw) {
    final current = _currentPosition;
    if (current == null) return raw;
    const alpha = 0.5;
    return LatLng(
      current.latitude + (raw.latitude - current.latitude) * alpha,
      current.longitude + (raw.longitude - current.longitude) * alpha,
    );
  }

  Future<LatLng?> refresh({bool openSettingsWhenDenied = false}) async {
    if (_isLoading) return _currentPosition;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        // Android บางรุ่นต้องรอให้ location provider กลับมาเชื่อมต่อ
        // หลังปิด permission dialog ก่อนจึงจะอ่านตำแหน่งได้
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (openSettingsWhenDenied &&
            permission == LocationPermission.deniedForever &&
            !kIsWeb) {
          await Geolocator.openAppSettings();
        }
        throw Exception('Location permission denied');
      }

      // geolocator_web ไม่รองรับ getLastKnownPosition และจะ throw ทันที
      if (!kIsWeb) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          // แสดงค่าล่าสุดให้ UI ใช้ก่อนได้ แล้วค่อยแทนที่ด้วยพิกัดสดด้านล่าง
          _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
          notifyListeners();
        }
      }

      Position? position;
      Object? lastError;
      for (var attempt = 0; attempt < 2 && position == null; attempt++) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            ),
          );
        } catch (e) {
          lastError = e;
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 700));
          }
        }
      }
      if (position == null) {
        if (_currentPosition != null) return _currentPosition;
        throw Exception('Unable to get current location: $lastError');
      }
      _currentPosition = _smoothPosition(LatLng(position.latitude, position.longitude));
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startTracking() async {
    if (_positionSubscription != null || kIsWeb) return;
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 60,
          ),
        ).listen(
          (position) {
            _currentPosition = _smoothPosition(
              LatLng(position.latitude, position.longitude),
            );
            _error = null;
            notifyListeners();
          },
          onError: (Object error) {
            _error = '$error';
            notifyListeners();
          },
        );
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
