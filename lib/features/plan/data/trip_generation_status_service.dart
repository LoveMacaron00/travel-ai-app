import 'dart:async';

import 'package:flutter/foundation.dart';

enum TripGenerationStatus { idle, generating, success, error }

/// Global singleton ที่ PlanScreen อัปเดตเมื่อกดสร้างทริป
/// และ MainNavigationScreen ฟังเพื่อแสดง tap bar ด้านล่างตลอด
/// แม้ผู้ใช้สลับไปหน้าอื่น — เมื่อเสร็จจะเปลี่ยนเป็นสีเขียวแล้วหายเอง
class TripGenerationStatusService extends ChangeNotifier {
  TripGenerationStatus _status = TripGenerationStatus.idle;
  String? _message;
  int? _tripId;
  Timer? _hideTimer;

  TripGenerationStatus get status => _status;
  String? get message => _message;
  int? get tripId => _tripId;

  bool get isActive => _status != TripGenerationStatus.idle;
  bool get isGenerating => _status == TripGenerationStatus.generating;
  bool get isSuccess => _status == TripGenerationStatus.success;
  bool get isError => _status == TripGenerationStatus.error;

  void startGenerating() {
    _hideTimer?.cancel();
    _status = TripGenerationStatus.generating;
    _message = null;
    _tripId = null;
    notifyListeners();
  }

  void completeSuccess(int tripId) {
    _hideTimer?.cancel();
    _status = TripGenerationStatus.success;
    _tripId = tripId;
    _message = null;
    notifyListeners();
    // เขียวค้าง 4 วินาทีแล้วหายเองตาม spec
    _hideTimer = Timer(const Duration(seconds: 4), () {
      _status = TripGenerationStatus.idle;
      notifyListeners();
    });
  }

  void completeError(String message) {
    _hideTimer?.cancel();
    _status = TripGenerationStatus.error;
    _message = message;
    _tripId = null;
    notifyListeners();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      _status = TripGenerationStatus.idle;
      notifyListeners();
    });
  }

  void dismiss() {
    _hideTimer?.cancel();
    _status = TripGenerationStatus.idle;
    _message = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}
