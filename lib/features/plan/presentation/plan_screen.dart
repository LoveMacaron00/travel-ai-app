import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/features/plan/domain/place_marker.dart';
import 'package:myapp/features/plan/domain/travel_plan.dart';
import 'package:myapp/features/destinations/presentation/destination_detail_screen.dart';
import 'package:myapp/features/plan/presentation/plan_navigation_screen.dart';
import 'package:myapp/core/di/app_services.dart';
import 'package:myapp/features/map/data/location_service.dart';
import 'package:myapp/core/utils/destination_display.dart';
import 'package:myapp/core/widgets/media_image.dart';
import 'package:myapp/features/plan/widgets/plan_day_selector.dart';
import 'package:myapp/features/plan/widgets/province_selector.dart';
import 'package:myapp/features/map/presentation/map_picker_screen.dart';

part 'plan_view.dart';
part 'plan_details.dart';
part 'plan_components.dart';

const _gold = Color(0xffe9ad0c);
const _ink = Color(0xff292620);
const _canvas = Color(0xfff7f2e8);

/// ขาเส้นทางหนึ่งช่วงบนแผนที่ (จุดแวะ → จุดแวะถัดไป)
/// แยกตาม mode เพื่อวาดสี/เส้นทึบ-เส้นประต่างกัน
class _PlanRouteLeg {
  const _PlanRouteLeg({required this.mode, required this.points});

  final String mode;
  final List<LatLng> points;
}

/// สร้างและแสดงแผนเที่ยวจาก AI ก่อนส่งจุดแวะไปยังหน้าจอนำทาง
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, this.initialTripId, this.onBackFromSavedView});

  /// เปิดด้วยแผนที่บันทึกไว้แล้ว (โหลดจาก GET /trips/:id)
  final int? initialTripId;

  /// ใช้เมื่อเปิดจาก Profile (tab) แล้วกดย้อนกลับ ต้องการกลับไปหน้า Profile แทนการโชว์ฟอร์มเปล่า
  final VoidCallback? onBackFromSavedView;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

/// ตัวเลือกความสนใจ/พาหนะ 1 ชิ้น ที่ได้จาก DB (key ใช้ส่ง API, label/icon ใช้แสดงผล)
class _PreferenceOptionItem {
  const _PreferenceOptionItem({
    required this.key,
    required this.label,
    this.iconUrl,
  });

  final String key;
  final String label;
  final String? iconUrl;
}

class _PlanScreenState extends State<PlanScreen> {
  // จำกัดจำนวนสถานที่ที่ผู้ใช้บังคับให้ไป เพื่อไม่ให้ AI วางแผนวันนั้นแน่นเกิน
  static const _maxMustVisitPlaces = 5;

  // ชื่อแผนยาวสุด 120 ตัวอักษร — ตรงกับ CHECK ฝั่ง backend (PATCH /trips/:id)
  static const _maxPlanNameLength = 120;

  final LocationService _locationService = LocationService.instance;
  final _map = MapController();
  final _planMapKey = GlobalKey();
  final _planNameController = TextEditingController();
  DateTimeRange? _dates;
  double _budget = 30000;
  int _days = 3;
  // จุด 2: เวลาเริ่มเดินทาง + โหมดให้ AI ประเมินจำนวนวัน
  // _startTime เริ่ม 09:00 ตรงกับ DEFAULT_DAY_START_MINUTES ฝั่ง server
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  bool _autoDays = false;
  LatLng? _position;
  // จุดเริ่มต้นที่ผู้ใช้ปักเองบนแผนที่ (null = ใช้ GPS ปัจจุบัน)
  // มีผลกับ: _input() start_lat/lng, การเตือนระยะทาง, การเรียง place picker, หมุด/แผนที่หน้าผลลัพธ์
  LatLng? _customStartPoint;
  bool _locating = false;
  bool _loadingProvinces = false;
  bool _generating = false;
  bool _loadingExistingPlan = false;
  String? _error;
  TravelPlan? _plan;
  List<PlaceMarker> _places = [];
  List<ProvinceOption> _provinceOptions = [];
  List<_PreferenceOptionItem> _dynamicInterests = [];
  List<_PreferenceOptionItem> _dynamicModes = [];
  bool _loadingPlanOptions = true;
  String? _selectedProvince;
  final Set<String> _interests = {};
  final Set<String> _modes = {'car'};
  final List<PlaceMarker> _mustVisit = [];
  final Set<String> _excluded = {};
  List<_PlanRouteLeg> _route = [];
  int _selectedDayIndex = 0;
  int _routeRequestId = 0;
  bool _resettingPlan = false;
  Map<String, dynamic>? _originalPlanJson;
  late String _loadedLanguage;

  // จุดเริ่มต้นจริงที่ใช้ทั้งฟอร์ม — ปักเองมาก่อน GPS เสมอ
  // (GPS แค่ fallback ตอนยังไม่ปัก — ปักแล้ว device ขยับก็ไม่หลุด)
  LatLng? get _startPoint => _customStartPoint ?? _position;

  // extension view เรียกผ่าน wrapper นี้แทน protected State.setState โดยตรง
  void _updateState(VoidCallback update) => setState(update);

  // รายการ options (key/label/icon_url) มาจาก DB ผ่าน GET /mobile/plan-options ทั้งหมด
  // icon วาดด้วยรูปจาก icon_url, fallback เป็น Icons.route ตัวเดียว (ไม่มี map ราย mode)

  @override
  // โหลดข้อมูลครั้งแรกแบบขนาน: โปรไฟล์, สถานที่, จังหวัด, options จาก DB
  // พิกัด GPS ถ้ายังไม่มีจะขอใหม่ และถ้าเปิดแผนเก่า (initialTripId) โหลดแผนทันที
  void initState() {
    super.initState();
    _loadedLanguage = AppServices.locale.languageCode;
    _loadProfileInterests();
    _position = _locationService.currentPosition;
    _locationService.addListener(_onSharedLocationChanged);
    _loadPlaces();
    _loadProvinces();
    _loadPlanOptions();
    if (_position == null) _getLocation();
    if (widget.initialTripId != null) {
      _loadExistingPlan(widget.initialTripId!);
    }
  }

  @override
  // กรณีแปลง widget ใหม่โดยเปลี่ยน initialTripId (เช่นกดเปิดแผนอื่นจาก Profile)
  // — tripId ใหม่: โหลดแผนใหม่ / เป็น null: ล้าง plan กลับไปหน้าฟอร์ม
  void didUpdateWidget(covariant PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTripId != oldWidget.initialTripId) {
      if (widget.initialTripId != null) {
        _loadExistingPlan(widget.initialTripId!);
      } else {
        _routeRequestId++;
        _originalPlanJson = null;
        setState(() {
          _plan = null;
          _route = [];
          _selectedDayIndex = 0;
          _loadingExistingPlan = false;
          _error = null;
        });
      }
    }
  }

  // เก็บ snapshot แผนแรกที่ AI สร้างไว้ใน memory สำหรับปุ่ม reset
  // deep copy ผ่าน json เพื่อกัน reference ของแผนที่กำลังแก้ไขไปทับของเดิม
  void _storeOriginalPlan(Map<String, dynamic> raw) {
    try {
      _originalPlanJson = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(raw)) as Map,
      );
    } on FormatException {
      _originalPlanJson = null;
    }
  }

  /// โหลดแผนที่บันทึกไว้จาก server (GET /trips/:id) มาแสดงทันที
  /// ไม่ผ่านฟอร์ม — ใช้เมื่อเปิดจาก Profile
  Future<void> _loadExistingPlan(int tripId) async {
    setState(() {
      _loadingExistingPlan = true;
      _error = null;
    });

    final result = await AppServices.trips.getTravelPlan(tripId);
    if (!mounted) return;

    if (result['success'] == true) {
      final trip = Map<String, dynamic>.from(result['data']);
      final raw = Map<String, dynamic>.from(trip['plan_data'] as Map? ?? {});
      var plan = TravelPlan.fromJson(
        raw,
        tripId: tripId,
        title: '${trip['title'] ?? ''}',
      );
      // trips.days คือจำนวนวันที่ resolve แล้ว (auto_days คำนวณมากี่วันก็เก็บเท่านั้น)
      // sync กลับเข้าฟอร์มให้ตรง — กดสร้างแผนใหม่จะเริ่มจากจำนวนวันจริงของแผนนี้
      final storedDays = int.tryParse('${trip['days'] ?? ''}');
      if (storedDays != null && storedDays >= 1 && storedDays <= 7) {
        _days = storedDays;
      }
      // start_time ที่เก็บไว้ ("HH:MM") — sync เข้า TimePicker ของฟอร์มด้วย
      final storedStart = _parseStoredClock('${trip['start_time'] ?? ''}');
      if (storedStart != null) _startTime = storedStart;

      // เปิดแผนเก่า: เก็บ snapshot ตอนเปิดไว้ — reset จะย้อนการแก้ของ session นี้
      // (trip เก่าไม่มี snapshot แผนแรกใน memory/server แล้วเพราะทุกการแก้ save ทับ)
      _storeOriginalPlan(raw);
      setState(() {
        _plan = plan;
        _planNameController.text = plan.title;
        _selectedDayIndex = 0;
        _route = [];
        _loadingExistingPlan = false;
      });
      await _buildRoute(plan);
    } else {
      setState(() {
        _loadingExistingPlan = false;
        _error = '${result['message'] ?? context.l10n.couldNotCreatePlan}';
      });
    }
  }

  // "HH:MM" จาก trips.start_time → TimeOfDay — ใช้ไม่ได้คืน null (คงค่าเดิมในฟอร์ม)
  TimeOfDay? _parseStoredClock(String clock) {
    final parts = clock.split(':');
    final hour = int.tryParse(parts.firstOrNull ?? '');
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '');
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// โหลดตัวเลือกความสนใจ/พาหนะจาก DB — ไม่มี hardcode fallback
  /// และตรวจว่า default 'car' ยังถูกต้องตาม options ที่ admin เปิดไว้
  Future<void> _loadPlanOptions() async {
    final res = await AppServices.trips.getPlanOptions();
    if (!mounted) return;
    if (res['success'] != true || res['data'] is! Map) {
      setState(() => _loadingPlanOptions = false);
      return;
    }

    final data = Map<String, dynamic>.from(res['data'] as Map);
    final rawInterests = (data['interests'] as List? ?? []);
    final rawModes = (data['transportModes'] as List? ?? []);

    setState(() {
      _loadingPlanOptions = false;
      if (rawInterests.isNotEmpty) {
        _dynamicInterests = rawInterests
            .whereType<Map>()
            .map(
              (m) => _PreferenceOptionItem(
                key: '${m['key'] ?? ''}',
                label: '${m['label'] ?? m['key'] ?? ''}',
                iconUrl: m['icon_url'] != null ? '${m['icon_url']}' : null,
              ),
            )
            .where((item) => item.key.isNotEmpty)
            .toList();
      }
      if (rawModes.isNotEmpty) {
        _dynamicModes = rawModes
            .whereType<Map>()
            .map(
              (m) => _PreferenceOptionItem(
                key: '${m['key'] ?? ''}',
                label: '${m['label'] ?? m['key'] ?? ''}',
                iconUrl: m['icon_url'] != null ? '${m['icon_url']}' : null,
              ),
            )
            .where((item) => item.key.isNotEmpty)
            .toList();
      }
      // กัน default 'car' หลุดเมื่อ admin ปิด/เปลี่ยนตัวเลือกใน DB
      if (_dynamicModes.isNotEmpty) {
        final validKeys = _dynamicModes.map((e) => e.key.toLowerCase()).toSet();
        _modes.removeWhere((m) => !validKeys.contains(m.toLowerCase()));
        if (_modes.isEmpty) _modes.add(_dynamicModes.first.key);
      }
    });
  }

  /// ดึง interests ที่ผู้ใช้เคยเลือกในโปรไฟล์มาติ๊กไว้ล่วงหน้าในฟอร์ม
  void _loadProfileInterests() {
    final rawInterests = AppServices.auth.currentUser?['interests'];
    if (rawInterests is! List) return;

    // เก็บค่า profile แบบ case-insensitive ตรงๆ ไม่ต้องกรองผ่าน static list
    // UI (_interestChips) จะ match กับ _dynamicInterests จาก DB เองหลังโหลดเสร็จ
    final profileInterests = rawInterests
        .map((interest) => interest.toString().trim())
        .where((interest) => interest.isNotEmpty)
        .toSet();
    _interests.addAll(profileInterests);
  }

  @override
  // ถ้าภาษาของแอปเปลี่ยนกลางคัน ให้โหลดข้อมูลที่ผูกกับภาษาใหม่ทั้งหมด
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (language != _loadedLanguage) {
      _loadedLanguage = language;
      _loadPlaces();
      _loadProvinces();
      _loadPlanOptions();
    }
  }

  @override
  void dispose() {
    _locationService.removeListener(_onSharedLocationChanged);
    _planNameController.dispose();
    _map.dispose();
    super.dispose();
  }

  // ตำแหน่ง GPS เปลี่ยน (มาจาก service กลาง) — sync พิกัดที่แสดงบนฟอร์ม
  void _onSharedLocationChanged() {
    if (!mounted) return;
    setState(() {
      _position = _locationService.currentPosition;
      _locating = _locationService.isLoading;
      if (_locationService.error == null) _error = null;
    });
  }

  /// โหลดรายการสถานที่ทั้งหมดจาก server มาเก็บเป็น PlaceMarker
  /// ใช้ใน place picker และหาจังหวัดย้อนให้ stop ที่ไม่มีข้อมูล
  /// ถ้าระหว่างรอ response ภาษาเปลี่ยน จะทิ้งผลลัพธ์เก่า (กันข้อมูลภาษาเก่าค้าง)
  Future<void> _loadPlaces() async {
    final requestedLanguage = AppServices.locale.languageCode;
    final result = await AppServices.destinations.getDestinations();
    if (result['success'] != true ||
        !mounted ||
        requestedLanguage != AppServices.locale.languageCode) {
      return;
    }
    setState(
      () => _places = (result['data'] as List).map((item) {
        final j = Map<String, dynamic>.from(item as Map);
        return PlaceMarker(
          id: '${j['id']}',
          title: '${j['name'] ?? j['city']}',
          description: '${j['description'] ?? ''}',
          latitude: double.tryParse('${j['latitude']}') ?? 0,
          longitude: double.tryParse('${j['longitude']}') ?? 0,
          imageUrl: AppServices.media.fullUrl('${j['image'] ?? ''}'),
          category: '${j['category'] ?? 'other'}',
          province: '${j['province'] ?? ''}',
        );
      }).toList(),
    );
  }

  /// โหลดรายชื่อจังหวัดสำหรับ dropdown — ถ้าจังหวัดที่เคยเลือกไว้ไม่อยู่ใน
  /// รายการใหม่ (เช่นภาษาเปลี่ยน) ให้เคลียร์ค่าที่เลือก
  Future<void> _loadProvinces() async {
    final requestedLanguage = AppServices.locale.languageCode;
    if (mounted) setState(() => _loadingProvinces = true);

    final result = await AppServices.destinations.getProvinces();
    if (!mounted || requestedLanguage != AppServices.locale.languageCode) {
      return;
    }

    if (result['success'] != true) {
      setState(() {
        _loadingProvinces = false;
        _error = '${result['message'] ?? context.l10n.couldNotLoadProvinces}';
      });
      return;
    }

    final options = (result['data'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ProvinceOption.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.value.isNotEmpty)
        .toList();
    setState(() {
      _provinceOptions = options;
      if (!options.any((item) => item.value == _selectedProvince)) {
        _selectedProvince = null;
      }
      _loadingProvinces = false;
    });
  }

  /// ขอตำแหน่ง GPS ใหม่ — ถ้าถูกปฏิเสธ permission จะเปิดหน้าตั้งค่าให้ผู้ใช้เอง
  Future<void> _getLocation() async {
    final position = await _locationService.refresh(
      openSettingsWhenDenied: true,
    );
    if (!mounted) return;
    setState(() {
      _position = position ?? _locationService.currentPosition;
      _error = position == null ? _locationService.error : null;
    });
  }

  // เลือกจุดเริ่มต้นเองบนแผนที่ (diary _pickLocation pattern) — ใช้ State context
  // ที่ stable ของ PlanScreen แทน context ของ bottom sheet ข้างใน
  Future<void> _pickCustomStart() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: _startPoint),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _customStartPoint = result);
  }

  // ล้างจุดที่ปักเอง กลับไปใช้ GPS ปัจจุบัน
  void _clearCustomStart() {
    if (_customStartPoint == null) return;
    setState(() => _customStartPoint = null);
    _showPlanSnack(context.l10n.startPointCleared);
  }

  // ชื่อแผนที่ผู้ใช้กรอกในฟอร์ม — trim แล้วตัดให้ไม่เกิน limit ก่อนส่ง
  String get _planNameInput {
    final name = _planNameController.text.trim();
    if (name.isEmpty) return '';
    return name.length > _maxPlanNameLength
        ? name.substring(0, _maxPlanNameLength)
        : name;
  }

  /// รวมทุก input บนฟอร์มเป็น JSON body สำหรับยิงสร้างแผน
  ///
  /// จำนวนวันมีแหล่งเดียวคือช่วงวันที่ (_dates → _days อัตโนมัติ)
  /// 'auto_days: true' = ไม่ส่ง days ให้ server ประเมินเองจากสถานที่/ระยะทาง
  /// 'start_time' เป็น "HH:MM" — ส่งเสมอ (เวลาเลือกในฟอร์ม) เพื่อให้ AI
  /// กระจาย arrivalTime ตั้งแต่วันแรก และเป็น anchor เวลาเริ่มของทุกวัน
  /// start_lat/lng ใช้จุดที่ปักเองก่อน (_customStartPoint) — GPS เป็นแค่ fallback
  Map<String, dynamic> _input() {
    final start = _startPoint;
    final days = _dates == null
        ? null // ยังไม่เลือกวัน = ให้ server ประเมิน (เหมือน auto) กันค้าง 3 วันมั่ว ๆ
        : (_dates!.duration.inDays + 1).clamp(1, 7);
    return {
      if (_planNameInput.isNotEmpty) 'title': _planNameInput,
      'destination': _selectedProvince,
      'province': _selectedProvince,
      if (!_autoDays && days != null) 'days': days,
      'auto_days': _autoDays,
      'start_time': _clockOf(_startTime),
      'budget': _budget.round(),
      'currency': 'THB',
      'interests': _interests.map((e) => e.toLowerCase()).toList(),
      'transport_modes': _modes.toList(),
      'start_latitude': start?.latitude,
      'start_longitude': start?.longitude,
      'must_visit': _mustVisit
          .map(
            (p) => {
              'id': p.id,
              'name': p.title,
              'latitude': p.latitude,
              'longitude': p.longitude,
            },
          )
          .toList(),
      'excluded_places': _excluded.toList(),
      if (_dates != null) 'start_date': _dates!.start.toIso8601String(),
    };
  }

  /// กดปุ่มสร้างแผน — ยิงให้ AI สร้างแผนจาก _input() แล้วแปลง plan_data
  /// เป็น TravelPlan, เติม must-visit ที่หายไป, สลับไปหน้าผลลัพธ์ และวาดเส้นทาง
  /// โหมด manual ต้องเลือกช่วงวันที่ก่อน — ยังไม่เลือกถือว่าให้ AI ประเมินไม่ได้
  /// ต้องเลือกเอง (กันส่ง days ค้าง 3 วันมั่ว ๆ แทนช่วงที่ผู้ใช้ตั้งใจ)
  Future<void> _generate() async {
    if (!_autoDays && _dates == null) {
      _showPlanSnack(context.l10n.chooseDates);
      return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    AppServices.tripGenerationStatus.startGenerating();
    final result = await AppServices.trips.createTravelPlan(_input());
    if (!mounted) return;
    if (result['success'] == true) {
      final trip = Map<String, dynamic>.from(result['data']);
      final raw = Map<String, dynamic>.from(trip['plan_data'] as Map? ?? {});
      final tripId = int.tryParse('${trip['id']}') ?? 0;
      _storeOriginalPlan(raw);
      var next = _ensureMustVisitStops(
        TravelPlan.fromJson(
          raw,
          tripId: tripId,
          title: '${trip['title'] ?? _planNameInput}',
        ),
      );
      // sync จำนวนวันที่ server resolve กลับเข้าฟอร์ม (auto หรือยังไม่เลือกวัน)
      // ให้ช่องวันที่/ตัวนับตรงกับแผนจริง — กดสร้างใหม่จะเริ่มจากจำนวนวันจริงของแผนนี้
      final resolvedDays = next.days.length;
      if ((_autoDays || _dates == null) && resolvedDays >= 1 && resolvedDays <= 7) {
        _days = resolvedDays;
      }
      // SSE warning event (ข้าง plan_data) — รวมเข้ากับ warnings ใน model
      // ให้แบนเนอร์หน้าผลลัพธ์แสดง แม้ plan_data เก่าจะไม่มี field นี้
      final streamed =
          ((result['warnings'] as List?) ?? const []).map((e) => '$e').toList();
      if (streamed.isNotEmpty) {
        next = next.copyWith(
          warnings: {...next.warnings, ...streamed}.toList(),
        );
      }
      setState(() {
        _plan = next;
        _planNameController.text = next.title;
        _selectedDayIndex = 0;
        _route = [];
        _generating = false;
      });
      AppServices.tripGenerationStatus.completeSuccess(tripId);
      await _buildRoute(next);
    } else {
      final msg = '${result['message'] ?? context.l10n.couldNotCreatePlan}';
      setState(() {
        _generating = false;
        _error = msg;
      });
      AppServices.tripGenerationStatus.completeError(msg);
    }
  }

  /// การันตีว่าสถานที่ที่ผู้ใช้บังคับเลือก (must-visit) ถูกใส่ในแผนทุกที่
  /// ถ้า AI ไม่ได้ใส่ จะแทรกต่อท้ายวันที่มีจุดแวะน้อยที่สุด
  TravelPlan _ensureMustVisitStops(TravelPlan plan) {
    if (_mustVisit.isEmpty) return plan;

    final days = plan.days
        .map(
          (day) => TravelDay(
            day: day.day,
            theme: day.theme,
            stops: List<TravelStop>.from(day.stops),
          ),
        )
        .toList();

    for (final place in _mustVisit) {
      if (_planContainsPlace(days, place)) continue;
      final day = _targetDayForMustVisit(days);
      day.stops.add(_mustVisitStop(place, day.stops));
    }

    return TravelPlan(
      tripId: plan.tripId,
      title: plan.title,
      summary: plan.summary,
      totalEstimatedCost: plan.totalEstimatedCost,
      budgetBreakdown: plan.budgetBreakdown,
      days: days,
      tips: plan.tips,
      warnings: plan.warnings,
    );
  }

  // เช็คว่าแผนมีสถานที่นี้อยู่แล้วไหม — เทียบทั้ง id และชื่อ (กัน AI เขียนชื่อเพี้ยน)
  bool _planContainsPlace(List<TravelDay> days, PlaceMarker place) {
    final id = place.id.trim();
    final title = _placeKey(place.title);
    for (final stop in days.expand((day) => day.stops)) {
      if (id.isNotEmpty && stop.destinationId.trim() == id) return true;
      if (title.isNotEmpty && _placeKey(stop.place) == title) return true;
    }
    return false;
  }

  // วันที่ควรแทรก must-visit — เลือกวันที่มีจุดแวะน้อยที่สุด (ถ้าไม่มีวันเลยสร้างวันใหม่)
  TravelDay _targetDayForMustVisit(List<TravelDay> days) {
    if (days.isEmpty) {
      final day = TravelDay(
        day: 1,
        theme: context.l10n.mustVisitPlaces,
        stops: <TravelStop>[],
      );
      days.add(day);
      return day;
    }

    return days.reduce(
      (leastBusy, day) =>
          day.stops.length < leastBusy.stops.length ? day : leastBusy,
    );
  }

  // สร้าง TravelStop จาก PlaceMarker ที่ผู้ใช้เลือก — ใช้ทั้งตอน AI ลืมใส่
  // และตอนผู้ใช้กดเพิ่มที่เองหลังสร้างแผนแล้ว (ค่าใช้จ่ายปล่อยเป็น 0 ให้ AI/ระบบคิด)
  // arrivalTime ต่อโซ่จากจุดก่อนหน้าใน existingStops — เวลาจริง server
  // จะเดินโซ่ใหม่แบบคงลำดับตอน PUT แล้ว UI ใช้อันนั้นเป็นหลัก
  TravelStop _mustVisitStop(PlaceMarker place, List<TravelStop> existingStops) {
    final activity = stripHtmlText(place.description).trim();
    return TravelStop(
      destinationId: place.id,
      place: place.title,
      province: place.province,
      activity: activity.isEmpty ? 'แวะชม ${place.title}' : activity,
      latitude: place.latitude,
      longitude: place.longitude,
      imageUrl: place.imageUrl,
      arrivalTime: _chainArrivalAfter(
        existingStops,
        LatLng(place.latitude, place.longitude),
      ),
      durationMinutes: 90,
      entryCost: 0,
      foodCost: 0,
      transportMode: _modes.firstOrNull ?? 'car',
      transportCost: 0,
      tip:
          'สถานที่นี้ถูกเพิ่มเพราะคุณเลือกไว้โดยตรง โปรดตรวจสอบเวลาเปิด-ปิดและวิธีเดินทางจริงก่อนออกเดินทาง',
      segments: const [],
    );
  }

  // หาจังหวัดของ stop จาก 3 ชั้น: ข้อมูลในตัว stop → id → ชื่อที่ normalize แล้ว
  String _provinceForStop(TravelStop stop) {
    if (stop.province.trim().isNotEmpty) return stop.province.trim();
    final byId = _places.where((p) => p.id == stop.destinationId).firstOrNull;
    if (byId != null && byId.province.isNotEmpty) return byId.province;
    final key = _placeKey(stop.place);
    if (key.isNotEmpty) {
      for (final p in _places) {
        if (_placeKey(p.title) == key && p.province.isNotEmpty) {
          return p.province;
        }
      }
    }
    return '';
  }

  // ประมาณค่าเดินทางตามระยะทาง × อัตราต่อกม. ของแต่ละพาหนะ (ขั้นต่ำ 50฿)
  double _estimateTransportCost(LatLng from, LatLng to, String mode) {
    final lower = mode.toLowerCase();
    if (lower == 'walking') return 0;
    final km = const Distance().as(LengthUnit.Kilometer, from, to);
    // อัตราให้ใกล้เคียง AI เดิม (รูปตัวอย่าง car 10นาที≈100฿, 15นาที≈150฿) เพื่อเพิ่มแล้วไม่ลด
    final rate = switch (lower) {
      'car' => 20.0,
      'bus' => 7.0,
      'train' => 12.0,
      'ferry' => 25.0,
      'flight' => 35.0,
      _ => 15.0,
    };
    if (km < 0.5) return 50;
    final cost = km * rate;
    return (cost < 50 ? 50 : cost).roundToDouble();
  }

  // identity ของ stop สำหรับเทียบตอนลบ/สลับ — ใช้ id ถ้ามี ไม่มีค่อยใช้ชื่อที่ normalize
  String _stopIdentity(TravelStop stop) {
    final id = stop.destinationId.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'place:${_placeKey(stop.place)}';
  }

  /// คำนวณค่าเดินทางใหม่เฉพาะขาที่เปลี่ยน (จุดก่อนหน้าเปลี่ยนจากการลบ/สลับ)
  /// ขาเดิมคงค่า AI ไว้ทั้งหมด กันยอดรวมร่วงทั้งก้อนทั้งที่จุดที่ลบค่าเดินทางเป็น 0
  List<TravelStop> _recalculatedStopsPreservingCosts(
    List<TravelStop> oldStops,
    List<TravelStop> newStops,
  ) {
    if (newStops.isEmpty) return newStops;
    // จุดก่อนหน้าของแต่ละ stop ใน list เดิม
    final oldPrevByStop = <String, String?>{};
    for (var i = 0; i < oldStops.length; i++) {
      oldPrevByStop[_stopIdentity(oldStops[i])] = i == 0
          ? null
          : _stopIdentity(oldStops[i - 1]);
    }
    final oldByStop = {for (final s in oldStops) _stopIdentity(s): s};

    final updated = <TravelStop>[];
    for (var i = 0; i < newStops.length; i++) {
      final stop = newStops[i];
      final key = _stopIdentity(stop);
      final old = oldByStop[key];
      final newPrevKey = i == 0 ? null : _stopIdentity(newStops[i - 1]);

      // ขาเดิม (จุดก่อนหน้าเดิม + จุดเดิม) → คงค่า AI ไว้
      if (old != null && oldPrevByStop[key] == newPrevKey) {
        updated.add(
          stop.copyWith(
            transportCost: old.transportCost,
            segments: old.segments,
          ),
        );
        continue;
      }
      // กลายเป็นจุดแรกของวัน (ไม่มีขาเข้า) → ไม่มีค่าเดินทาง
      if (i == 0) {
        updated.add(stop.copyWith(transportCost: 0, segments: const []));
        continue;
      }
      // ขาใหม่ (จุดก่อนหน้าเปลี่ยน) → ประมาณเฉพาะขานี้ขาเดียว
      final prev = updated[i - 1];
      final from = LatLng(prev.latitude, prev.longitude);
      final to = LatLng(stop.latitude, stop.longitude);
      final estimated = _estimateTransportCost(from, to, stop.transportMode);
      final segment = TravelSegment(
        mode: stop.transportMode,
        from: prev.place,
        to: stop.place,
        estimatedMinutes: stop.segments.isNotEmpty
            ? stop.segments.first.estimatedMinutes
            : (const Distance().as(LengthUnit.Kilometer, from, to) * 2).round(),
        estimatedCost: estimated,
      );
      updated.add(stop.copyWith(transportCost: estimated, segments: [segment]));
    }
    return updated;
  }

  // ต่อโซ่ arrivalTime ใหม่ทั้งวันตามลำดับปัจจุบัน — จุดแรกยึดเวลาเดิมไว้
  // (ออก = ถึง + เที่ยว, ถึงถัดไป = ออก + เดินทางจาก segments)
  // กันเวลาค้างตามลำดับเก่าหลังลบ/สลับจุด — server จะคำนวณเวลาจริงซ้ำตอน PUT อีกที
  List<TravelStop> _rechainDay(List<TravelStop> stops) {
    if (stops.length < 2) return stops;
    final chained = <TravelStop>[stops.first];
    for (var i = 1; i < stops.length; i++) {
      final prev = chained[i - 1];
      final leg =
          stops[i].segments.isNotEmpty
              ? stops[i].segments.first.estimatedMinutes
              : (const Distance().as(
                        LengthUnit.Kilometer,
                        LatLng(prev.latitude, prev.longitude),
                        LatLng(stops[i].latitude, stops[i].longitude),
                      ) *
                      2)
                  .round()
                  .clamp(5, 720);
      chained.add(
        stops[i].copyWith(
          arrivalTime: _clockFromMinutes(
            _clockToMinutes(prev.arrivalTime) + prev.durationMinutes + leg,
          ),
        ),
      );
    }
    return chained;
  }

  /// ปรับงบแบบ delta จากของเดิม (ไม่คำนวณใหม่จากศูนย์ เพราะ total ของ AI
  /// อาจไม่เท่ากับผลรวม breakdown พอดี) ลบจุดออกยอดลดแค่ค่าของจุดนั้น
  /// + ส่วนต่างของขาที่เปลี่ยนเท่านั้น
  TravelPlan _withDeltaBudget(TravelPlan plan, List<TravelDay> newDays) {
    double oldTransport = 0, oldFood = 0, oldActivities = 0;
    for (final day in plan.days) {
      for (final stop in day.stops) {
        oldTransport += stop.transportCost;
        oldFood += stop.foodCost;
        oldActivities += stop.entryCost;
      }
    }
    double newTransport = 0, newFood = 0, newActivities = 0;
    for (final day in newDays) {
      for (final stop in day.stops) {
        newTransport += stop.transportCost;
        newFood += stop.foodCost;
        newActivities += stop.entryCost;
      }
    }
    double nonNegative(double v) => v < 0 ? 0 : v;
    final newBreakdown = Map<String, double>.from(plan.budgetBreakdown);
    newBreakdown['transport'] = nonNegative(
      (newBreakdown['transport'] ?? oldTransport) +
          (newTransport - oldTransport),
    );
    newBreakdown['food'] = nonNegative(
      (newBreakdown['food'] ?? oldFood) + (newFood - oldFood),
    );
    newBreakdown['activities'] = nonNegative(
      (newBreakdown['activities'] ?? oldActivities) +
          (newActivities - oldActivities),
    );
    final newTotal = nonNegative(
      plan.totalEstimatedCost +
          (newTransport - oldTransport) +
          (newFood - oldFood) +
          (newActivities - oldActivities),
    );
    return TravelPlan(
      tripId: plan.tripId,
      title: plan.title,
      summary: plan.summary,
      totalEstimatedCost: newTotal,
      budgetBreakdown: newBreakdown,
      days: newDays,
      tips: plan.tips,
      warnings: plan.warnings,
    );
  }

  // ช่วงเวลาถึงของจุดแวะที่แทรกเอง — ต่อโซ่จาก list จุดก่อนหน้าที่ให้มา
  // (ออก = ถึง + เที่ยว, ถึงใหม่ = ออก + เดินทาง) แทน slot ตายตัวแบบเดิม
  // server จะคำนวณเวลาจริงซ้ำแบบคงลำดับตอน PUT แล้ว UI ใช้อันนั้นเป็นหลัก
  String _chainArrivalAfter(List<TravelStop> stops, LatLng to) {
    if (stops.isEmpty) return _clockOf(_startTime);
    final prev = stops.last;
    final cursor = _clockToMinutes(prev.arrivalTime) + prev.durationMinutes;
    final from = LatLng(prev.latitude, prev.longitude);
    final km = const Distance().as(LengthUnit.Kilometer, from, to);
    // heuristic เดียวกับ estimatedMinutes ตอน append (2 นาที/กม.) กันเวลากระโดด
    final travel = (km * 2).round().clamp(5, 720);
    return _clockFromMinutes(cursor + travel);
  }

  // TimeOfDay → "HH:MM" สำหรับส่ง start_time ให้ server
  String _clockOf(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  // "HH:MM" → นาทีตั้งแต่เที่ยงคืน — แปลงไม่ได้ถือว่าเป็นเวลาเริ่มที่ผู้ใช้เลือก
  int _clockToMinutes(String clock) {
    final parts = clock.split(':');
    final hour = int.tryParse(parts.firstOrNull ?? '');
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '');
    if (hour == null || minute == null) {
      return _startTime.hour * 60 + _startTime.minute;
    }
    return (hour.clamp(0, 23)) * 60 + minute.clamp(0, 59);
  }

  // นาทีตั้งแต่เที่ยงคืน → "HH:MM" (วนรอบ 24 ชม. กันทริปข้ามวัน)
  String _clockFromMinutes(int totalMinutes) {
    final wrapped = totalMinutes % 1440;
    final hour = wrapped ~/ 60;
    final minute = wrapped % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  // จุด 4: เตือนทันทีเมื่อเลือกสถานที่ไกล (place-first ก่อนกดสร้างแผน)
  // ใช้ Haversine + ความเร็วคร่าว ๆ ต่อพาหนะหลักที่เลือก — เตือนเมื่อขาเดียว
  // กินเวลากว่าครึ่งหนึ่งของกรอบวัน (~5 ชม.) หรือไกลเกิน ~200 กม.
  String? _feasibilityWarning() {
    final start = _startPoint;
    if (start == null || _mustVisit.isEmpty) return null;
    final from = start;
    double farthestKm = 0;
    for (final place in _mustVisit) {
      final km = const Distance().as(
        LengthUnit.Kilometer,
        from,
        LatLng(place.latitude, place.longitude),
      );
      if (km > farthestKm) farthestKm = km;
    }
    if (farthestKm <= 0) return null;
    final mode = _modes.firstOrNull ?? 'car';
    final hours = _roughTravelHours(farthestKm, mode);
    if (hours <= 5 && farthestKm <= 200) return null;
    if (_autoDays) {
      // โหมดอัตโนมัติจัดวันเพิ่มให้อยู่แล้ว — เตือนเฉพาะกรณีไกลมากจริง ๆ
      if (hours <= 8) return null;
      return context.l10n.farPlaceWarning(
        farthestKm.round(),
        hours.toStringAsFixed(1),
        _modeLabel(mode),
      );
    }
    // โหมดกำหนดวันเอง — เทียบวันคร่าว ๆ จากระยะ (ทุก ~200 กม. ควรมีวันเพิ่ม)
    final roughRecommended = (farthestKm / 200).ceil().clamp(1, 7);
    if (_days >= roughRecommended) {
      return context.l10n.farPlaceWarning(
        farthestKm.round(),
        hours.toStringAsFixed(1),
        _modeLabel(mode),
      );
    }
    return context.l10n.tightDaysWarning(
      _days,
      roughRecommended,
      farthestKm.round(),
    );
  }

  // ประมาณชั่วโมงเดินทางขาเดียวจากระยะทาง — heuristic ฝั่ง client สำหรับเตือนล่วงหน้า
  // เวลาจริง server คำนวณด้วย planScheduler (ความเร็ว + overhead + พัก) ตอนสร้างแผน
  double _roughTravelHours(double km, String mode) {
    final speed = switch (mode.toLowerCase()) {
      'walking' => 5.0,
      'bus' => 40.0,
      'train' => 70.0,
      'ferry' => 28.0,
      'flight' => 550.0,
      _ => 50.0,
    };
    final overhead = switch (mode.toLowerCase()) {
      'bus' => 10 / 60,
      'train' => 0.5,
      'ferry' => 0.5,
      'flight' => 2.0,
      _ => 0.0,
    };
    return km / speed + overhead;
  }

  // normalize ชื่อสถานที่เพื่อใช้เทียบ (ตัด space, ลowercase ทั้งหมด)
  String _placeKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// สร้างเส้นทางบนแผนที่ของวันที่เลือก — วนคู่จุดแวะตามลำดับ
  /// car/walking/bus ขอเส้นทางตามถนนจริงจาก backend ส่วน mode อื่นวาดตรงจุดถึงจุด
  /// ใช้ _routeRequestId เป็นหมายเลขรุ่น — ถ้าผู้ใช้สลับวันเร็ว ๆ ผลลัพธ์รุ่นเก่าจะถูกทิ้ง
  Future<void> _buildRoute(TravelPlan plan) async {
    final requestId = ++_routeRequestId;
    final day = _selectedDayFor(plan);
    if (day == null || day.stops.length < 2) {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _route = []);
      }
      return;
    }

    final legs = <_PlanRouteLeg>[];
    var from = LatLng(day.stops.first.latitude, day.stops.first.longitude);
    for (final stop in day.stops.skip(1)) {
      final to = LatLng(stop.latitude, stop.longitude);
      final mode = stop.transportMode.toLowerCase();
      final usesRoadRoute = mode == 'car' || mode == 'walking' || mode == 'bus';
      final raw = usesRoadRoute
          ? await AppServices.trips.getRoadRoute(
              fromLat: from.latitude,
              fromLng: from.longitude,
              toLat: to.latitude,
              toLng: to.longitude,
              mode: mode,
            )
          : const <List<double>>[];
      if (requestId != _routeRequestId) return;
      legs.add(
        _PlanRouteLeg(
          mode: mode,
          points: raw.isEmpty
              ? [from, to]
              : raw.map((p) => LatLng(p[0], p[1])).toList(),
        ),
      );
      from = to;
    }
    if (mounted && requestId == _routeRequestId) {
      setState(() => _route = legs);
    }
  }

  TravelDay? _selectedDayFor(TravelPlan plan) {    if (plan.days.isEmpty) return null;
    final index = _selectedDayIndex.clamp(0, plan.days.length - 1);
    return plan.days[index];
  }

  // กดสลับวัน — เคลียร์เส้นทางเดิม วาดใหม่, scroll ให้แผนที่เข้าจอ
  // และเลื่อนกล้องไปจุดแวะแรกของวันนั้น (รอ post-frame เพราะ map อาจยังไม่ถูก build)
  void _selectDay(int index) {
    final plan = _plan;
    if (plan == null || index < 0 || index >= plan.days.length) return;
    final firstStop = plan.days[index].stops.firstOrNull;
    setState(() {
      _selectedDayIndex = index;
      _route = [];
    });
    unawaited(_buildRoute(plan));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapContext = _planMapKey.currentContext;
      if (!mounted || mapContext == null) return;
      Scrollable.ensureVisible(
        mapContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
      if (firstStop != null) {
        _map.move(LatLng(firstStop.latitude, firstStop.longitude), 15);
      }
    });
  }

  // ลากสลับลำดับจุดแวะในวันที่เลือก (มาจาก SliverReorderableList)
  // เวลาของแต่ละจุดจะต่อโซ่ใหม่ให้ตรงลำดับใหม่ทันที — ไม่ต้องรอ server
  void _reorderStops(int oldIndex, int newIndex) {
    final plan = _plan;
    if (plan == null) return;
    final day = _selectedDayFor(plan);
    if (day == null) return;

    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final stops = List<TravelStop>.from(day.stops);
    final stop = stops.removeAt(oldIndex);
    stops.insert(newIndex, stop);
    _replaceSelectedDayStops(_rechainDay(stops));
  }

  // แจ้งเตือนสั้น ๆ ผ่าน SnackBar — ใช้ State.context (Scaffold) เสมอ
  // เพื่อให้เรียกหลัง Navigator.pop(sheet) ได้โดยไม่พัง
  void _showPlanSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ลบจุดแวะ — จดชื่อใส่ _excluded เพื่อไม่ให้ AI เอากลับมาในรอบสร้างถัดไป
  // และถอดออกจาก must-visit ด้วย (ป้องกัน _ensureMustVisitStops เติมกลับมาทันที)
  void _removeStop(int stopIndex) {
    final plan = _plan;
    if (plan == null) return;
    final day = _selectedDayFor(plan);
    if (day == null || stopIndex < 0 || stopIndex >= day.stops.length) return;

    final removed = day.stops[stopIndex];
    _excluded.add(removed.place);
    _mustVisit.removeWhere(
      (place) =>
          place.id == removed.destinationId || place.title == removed.place,
    );
    final stops = List<TravelStop>.from(day.stops)..removeAt(stopIndex);
    _replaceSelectedDayStops(stops);
    _showPlanSnack(context.l10n.placeRemoved(removed.place));
  }

  // เช็คว่าสถานที่นี้อยู่ในวันที่เลือกแล้วหรือยัง — เทียบทั้ง id และชื่อ
  // (กัน AI เขียนชื่อเพี้ยน / destinationId ว่าง)
  bool _isDuplicateInSelectedDay(PlaceMarker place) {
    final plan = _plan;
    if (plan == null) return false;
    final day = _selectedDayFor(plan);
    if (day == null) return false;
    final id = place.id.trim();
    final title = _placeKey(place.title);
    for (final stop in day.stops) {
      if (id.isNotEmpty && stop.destinationId.trim() == id) return true;
      if (title.isNotEmpty && _placeKey(stop.place) == title) return true;
    }
    return false;
  }

  // เพิ่มสถานที่เข้าวันที่เลือกหลังสร้างแผนแล้ว — คืน true ถ้าเพิ่มสำเร็จ,
  // false ถ้าซ้ำ (ให้ caller แสดง SnackBar เอง)
  bool _addStopToSelectedDay(PlaceMarker place) {
    final plan = _plan;
    if (plan == null) return false;
    final day = _selectedDayFor(plan);
    if (day == null || _isDuplicateInSelectedDay(place)) {
      return false;
    }

    _replaceSelectedDayStops([
      ...day.stops,
      _mustVisitStop(place, day.stops),
    ]);
    return true;
  }

  /// จุดรวมของทุกการแก้ไข (เพิ่ม/ลบ/สลับ) — คำนวณ stops + งบใหม่ตามกติกา
  /// ของแต่ละกรณี แล้วทั้งบันทึกกลับ server และวาดเส้นทางใหม่
  void _replaceSelectedDayStops(List<TravelStop> stops) {
    final plan = _plan;
    if (plan == null) return;

    final selectedIndex = _selectedDayIndex.clamp(0, plan.days.length - 1);
    final oldDay = plan.days[selectedIndex];
    final oldStops = oldDay.stops;

    // กรณีเพิ่มที่เดียวต่อท้าย → คิดเพิ่มแบบบวกเพิ่ม ไม่คำนวณใหม่ทั้งหมดเพื่อไม่ให้ยอดลด
    final isAppendOne =
        stops.length == oldStops.length + 1 &&
        List.generate(
          oldStops.length,
          (i) => stops[i].destinationId == oldStops[i].destinationId,
        ).every((e) => e);
    List<TravelStop> recalculatedStops;
    TravelPlan updatedPlan;

    if (isAppendOne) {
      final prev = oldStops.isNotEmpty ? oldStops.last : null;
      final rawNew = stops.last;
      double estimated = 0;
      List<TravelSegment> newSegments = const [];
      if (prev != null) {
        final from = LatLng(prev.latitude, prev.longitude);
        final to = LatLng(rawNew.latitude, rawNew.longitude);
        estimated = _estimateTransportCost(from, to, rawNew.transportMode);
        newSegments = [
          TravelSegment(
            mode: rawNew.transportMode,
            from: prev.place,
            to: rawNew.place,
            estimatedMinutes: rawNew.segments.isNotEmpty
                ? rawNew.segments.first.estimatedMinutes
                : (const Distance().as(LengthUnit.Kilometer, from, to) * 2)
                      .round(),
            estimatedCost: estimated,
          ),
        ];
      }
      final newStop = rawNew.copyWith(
        transportCost: estimated,
        segments: newSegments.isEmpty ? rawNew.segments : newSegments,
      );
      recalculatedStops = [...oldStops, newStop];

      final days = [
        for (var index = 0; index < plan.days.length; index++)
          TravelDay(
            day: plan.days[index].day,
            theme: plan.days[index].theme,
            stops: index == selectedIndex
                ? recalculatedStops
                : List<TravelStop>.from(plan.days[index].stops),
          ),
      ];
      // บวกเพิ่มเท่านั้น ยอดรวมต้องเพิ่ม ไม่ลด
      final newBreakdown = Map<String, double>.from(plan.budgetBreakdown);
      newBreakdown['transport'] = (newBreakdown['transport'] ?? 0) + estimated;
      newBreakdown['food'] = (newBreakdown['food'] ?? 0) + newStop.foodCost;
      newBreakdown['activities'] =
          (newBreakdown['activities'] ?? 0) + newStop.entryCost;
      final newTotal =
          plan.totalEstimatedCost +
          estimated +
          newStop.foodCost +
          newStop.entryCost;
      updatedPlan = TravelPlan(
        tripId: plan.tripId,
        title: plan.title,
        summary: plan.summary,
        totalEstimatedCost: newTotal,
        budgetBreakdown: newBreakdown,
        days: days,
        tips: plan.tips,
        warnings: plan.warnings,
      );
    } else {
      // ลบ/สลับลำดับ → ประมาณใหม่เฉพาะขาที่เปลี่ยน ที่เหลือคงค่า AI เดิม
      // แล้วต่อโซ่เวลาใหม่ทั้งวันให้ตรงลำดับปัจจุบัน (จุดแรกยึดเวลาเดิมไว้)
      recalculatedStops = _rechainDay(
        _recalculatedStopsPreservingCosts(oldStops, stops),
      );
      final days = [
        for (var index = 0; index < plan.days.length; index++)
          TravelDay(
            day: plan.days[index].day,
            theme: plan.days[index].theme,
            stops: index == selectedIndex
                ? recalculatedStops
                : List<TravelStop>.from(plan.days[index].stops),
          ),
      ];
      updatedPlan = _withDeltaBudget(plan, days);
    }

    setState(() {
      _plan = updatedPlan;
      _route = [];
    });
    unawaited(_savePlanChanges(updatedPlan));
    unawaited(_buildRoute(updatedPlan));
  }

  /// บันทึกการแก้ไขสถานที่ (ลบ/เพิ่ม/สลับลำดับ) กลับลง server
  /// เพื่อให้เปิดแผนเดิมจาก Profile ได้ตรงกับที่ผู้ใช้แก้ไขล่าสุด
  ///
  /// จุด 6: server เดินโซ่เวลาใหม่แบบคงลำดับเดิม (chainAllDaysPreservingOrder)
  /// แล้วคืน warnings — ถ้าส่งเวลากลับมาจะ sync เข้า state ให้ตรงกันทันที
  /// ส่ง start_time เสริมด้วยเพื่อให้โซ่เวลาของวันเริ่มจากเวลาที่ผู้ใช้เลือกเหมือนตอนสร้าง
  Future<void> _savePlanChanges(TravelPlan plan) async {
    if (plan.tripId <= 0) return;
    final result = await AppServices.trips.updateTravelPlan(
      plan.tripId,
      {...plan.toJson(), 'start_time': _clockOf(_startTime)},
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final warnings =
          ((result['warnings'] as List?) ?? const []).map((e) => '$e').toList();
      if (warnings.isNotEmpty &&
          !_sameStringList(warnings, _plan?.warnings ?? const [])) {
        setState(() {
          _plan = _plan?.copyWith(warnings: warnings);
        });
        _showPlanSnack(warnings.first);
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result['message'] ?? 'บันทึกแผนไม่สำเร็จ'}')),
    );
  }

  // เทียบ list คำเตือนแบบไม่สนลำดับ — กัน SnackBar เด้งซ้ำทั้งที่ warnings เท่าเดิม
  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final rest = List<String>.from(b);
    for (final item in a) {
      if (!rest.remove(item)) return false;
    }
    return true;
  }

  // เปลี่ยนชื่อแผนเที่ยวจากหัวข้อหน้าผลลัพธ์ — PATCH /trips/:id
  // ชื่อว่างเปล่าใช้ fallback destination/province แทน จึง block ไม่ให้บันทึกชื่อว่าง
  Future<void> _renameCurrentPlan(String title) async {
    final plan = _plan;
    final name = title.trim();
    if (plan == null || plan.tripId <= 0 || name.isEmpty) {
      if (name.isEmpty && mounted) {
        _showPlanSnack(context.l10n.planNameEmpty);
      }
      return;
    }
    final result = await AppServices.trips.renamePlan(plan.tripId, name);
    if (!mounted) return;
    if (result['success'] == true) {
      _planNameController.text = name;
      setState(() {
        _plan = TravelPlan(
          tripId: plan.tripId,
          title: name,
          summary: plan.summary,
          totalEstimatedCost: plan.totalEstimatedCost,
          budgetBreakdown: plan.budgetBreakdown,
          days: plan.days,
          tips: plan.tips,
          warnings: plan.warnings,
        );
      });
      _showPlanSnack(context.l10n.planRenamed);
    } else {
      _showPlanSnack('${result['message'] ?? context.l10n.couldNotCreatePlan}');
    }
  }

  /// รีเซ็ตแผนกลับเป็นค่าเริ่มต้นที่ AI สร้าง — ยกเลิกทุกการเพิ่ม/ลบ/สลับลำดับ
  /// ทั้งบนหน้าจอ (state) และ server (PUT /plan) โดยคงชื่อแผนที่ผู้ใช้ตั้งไว้
  /// reset ได้เฉพาะการแก้ใน session นี้ (ย้อนไปถึง snapshot ตอนเปิดแผน)
  /// การแก้เก่าที่ save ทับไปก่อนหน้านี้แล้วจะย้อนไม่ได้ — backend เก็บแค่ฉบับล่าสุด
  Future<void> _resetPlanToOriginal() async {
    final plan = _plan;
    if (plan == null || plan.tripId <= 0 || _resettingPlan) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.resetPlan),
        content: Text(dialogContext.l10n.resetPlanConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.resetPlan),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    // snapshot ตอนเปิดแผนควรมีเสมอ — ถ้าไม่มีให้โหลดจาก server แทนกันพัง
    // (หมายเหตุ: server เก็บแค่ฉบับล่าสุด จึงย้อนได้ถึงตอนเปิดแผนใน session นี้เท่านั้น)
    setState(() => _resettingPlan = true);
    Map<String, dynamic>? raw = _originalPlanJson;
    if (raw == null) {
      final result = await AppServices.trips.getTravelPlan(plan.tripId);
      if (!mounted) return;
      if (result['success'] == true) {
        final trip = Map<String, dynamic>.from(result['data']);
        raw = Map<String, dynamic>.from(trip['plan_data'] as Map? ?? {});
      } else {
        setState(() => _resettingPlan = false);
        _showPlanSnack('${result['message'] ?? context.l10n.couldNotCreatePlan}');
        return;
      }
    }

    final restored = TravelPlan.fromJson(
      raw,
      tripId: plan.tripId,
      title: plan.title,
    );
    final saveResult = await AppServices.trips.updateTravelPlan(
      plan.tripId,
      {...restored.toJson(), 'start_time': _clockOf(_startTime)},
    );
    if (!mounted) return;
    if (saveResult['success'] != true) {
      setState(() => _resettingPlan = false);
      _showPlanSnack(
        '${saveResult['message'] ?? context.l10n.couldNotCreatePlan}',
      );
      return;
    }

    setState(() {
      _plan = restored;
      _selectedDayIndex = 0;
      _route = [];
      _excluded.clear();
      _resettingPlan = false;
    });
    _showPlanSnack(context.l10n.planReset);
    await _buildRoute(restored);
  }

  // ปุ่มย้อนกลับจากหน้าผลลัพธ์ — แยก 3 กรณี:
  // เปิดจาก Profile → เด้ง callback กลับหน้าเดิม / กดออกจากแผนเก่า → pop หน้าจอ / สร้างเอง → กลับฟอร์ม (ล้าง plan)
  void _backToForm() {
    if (widget.initialTripId != null && widget.onBackFromSavedView != null) {
      widget.onBackFromSavedView!.call();
      return;
    }
    if (_plan != null &&
        widget.initialTripId != null &&
        Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    if (_plan == null) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      return;
    }
    _routeRequestId++;
    _originalPlanJson = null;
    setState(() {
      _plan = null;
      _route = [];
      _selectedDayIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) => _buildScaffold(context);
}
