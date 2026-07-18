import 'dart:async';

import 'package:myapp/services/api_client.dart';

typedef AuthenticationChecker = bool Function();

/// ส่ง heartbeat ขณะผู้ใช้เปิดแอปอยู่ เพื่อให้ Dashboard คำนวณผู้ใช้งานจริง
///
/// การติดตามนี้ไม่เก็บตำแหน่งหรือเนื้อหาที่ผู้ใช้กรอก เก็บเวลาใช้งานและ id
/// ของสถานที่เมื่อเปิดรายละเอียดเท่านั้น หาก API ล่มจะไม่ขัดการใช้งานหลัก
class ActivityService {
  ActivityService({
    required ApiClient client,
    required AuthenticationChecker isAuthenticated,
    this.heartbeatInterval = const Duration(minutes: 1),
  }) : _client = client,
       _isAuthenticated = isAuthenticated;

  final ApiClient _client;
  final AuthenticationChecker _isAuthenticated;
  final Duration heartbeatInterval;

  Timer? _timer;
  int? _sessionId;
  bool _tracking = false;
  Future<void>? _heartbeatRequest;
  int _generation = 0;

  Future<void> resume() async {
    if (!_isAuthenticated()) return;

    if (!_tracking) {
      _tracking = true;
      _generation += 1;
      _timer = Timer.periodic(
        heartbeatInterval,
        (_) => unawaited(_sendHeartbeat(_generation)),
      );
    }
    await _sendHeartbeat(_generation);
  }

  Future<void> pause() async {
    if (!_tracking && _sessionId == null) return;

    _tracking = false;
    _generation += 1;
    _timer?.cancel();
    _timer = null;

    final sessionId = _sessionId;
    _sessionId = null;
    if (!_isAuthenticated() || sessionId == null) return;

    try {
      await _client.post('/activity/end', body: {'sessionId': sessionId});
    } catch (_) {
      // การปิด app อาจยกเลิก network ได้ตามปกติ; server จะถือว่าหยุด active
      // อัตโนมัติเมื่อ heartbeat ล่าสุดเกินช่วงเวลาที่กำหนด
    }
  }

  /// บันทึกหลังโหลดหน้ารายละเอียดสำเร็จ โดย server เป็นผู้กัน view ซ้ำ
  /// ต่อสถานที่ใน activity session เดียว
  Future<bool> recordDestinationView(int destinationId) async {
    if (destinationId <= 0 || !_isAuthenticated()) return false;
    if (!_tracking || _sessionId == null) await resume();
    final sessionId = _sessionId;
    if (sessionId == null) return false;

    try {
      final response = await _client.post(
        '/mobile/destinations/$destinationId/view',
        body: {'sessionId': sessionId},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendHeartbeat(int generation) {
    if (!_tracking || !_isAuthenticated()) return Future.value();
    final pending = _heartbeatRequest;
    if (pending != null) return pending;

    final request = _performHeartbeat(generation);
    _heartbeatRequest = request;
    return request.whenComplete(() {
      if (identical(_heartbeatRequest, request)) _heartbeatRequest = null;
    });
  }

  Future<void> _performHeartbeat(int generation) async {
    try {
      final response = await _client.post(
        '/activity/heartbeat',
        body: {if (_sessionId != null) 'sessionId': _sessionId},
      );
      final data = ApiClient.decodeMap(response.body);
      final rawSessionId = data?['sessionId'];
      final sessionId = rawSessionId is int
          ? rawSessionId
          : int.tryParse('$rawSessionId');

      // ไม่รับ response เก่าที่กลับมาหลังแอปเข้า background แล้ว
      if (_tracking && generation == _generation && sessionId != null) {
        _sessionId = sessionId;
      }
    } catch (_) {
      // Analytics ต้องไม่ทำให้หน้าหลักแสดง error เมื่อ network ไม่พร้อม
    }
  }
}
