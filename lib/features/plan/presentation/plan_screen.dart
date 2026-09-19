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
import 'package:myapp/core/utils/place_category.dart';
import 'package:myapp/core/widgets/place_category_chips.dart';

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

/// ขาขับหนึ่งช่วงสำหรับหาจุดพัก (index = ตำแหน่งที่จะแทรกใน stops ของวันนั้น)
class _EnrichLeg {
  const _EnrichLeg({
    required this.index,
    required this.from,
    required this.to,
    required this.mode,
  });

  final int index;
  final LatLng from;
  final LatLng to;
  final String mode;
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
  // true = สร้างแผนใหม่เสร็จแต่วันเริ่มทริปยังไม่ถึง (future trip)
  // โชว์จอ success "เริ่มต้นในวัน XX" แทนหน้าผลลัพธ์จนกว่าจะกดดูแผน
  bool _showCreatedSuccess = false;
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
          _showCreatedSuccess = false;
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
        startDate: '${trip['start_date'] ?? ''}',
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
      // ทริป local (จุดเริ่มอยู่จังหวัดเดียวกับปลายทาง) — ตัดที่พัก/คำเตือน + คิดรถเป็นน้ำมันก่อนโชว์
      plan = _applyPrivateCarRules(plan);
      _storeOriginalPlan(plan.toJson());
      setState(() {
        _plan = plan;
        _planNameController.text = plan.title;
        _selectedDayIndex = 0;
        _route = [];
        _showCreatedSuccess = false;
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

  // วันนี้แบบตัดเวลาออก — เทียบวันเดินทางแบบ date-only กัน timezone/เวลากวน
  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // วันเริ่มทริป (date-only) — ใช้ plan.startDate (server) เป็นหลัก,
  // fallback ช่วงวันที่ในฟอร์ม (ทริปใหม่ auto ที่ยังไม่มี start_date)
  // คืน null = ไม่ระบุวัน (auto เก่า) → ไม่ล็อกอะไรเลย
  DateTime? _effectiveStartDate(TravelPlan plan) {
    final stored = _parsePlanStartDate(plan.startDate);
    if (stored != null) {
      return DateTime(stored.year, stored.month, stored.day);
    }
    final form = _dates?.start;
    if (form != null) return DateTime(form.year, form.month, form.day);
    return null;
  }

  // ทริปอนาคต = วันนี้ยังก่อนวันเริ่มทริป → สร้างเสร็จโชว์จอ success แทน
  bool _isFutureTrip(TravelPlan plan) {
    final start = _effectiveStartDate(plan);
    if (start == null) return false;
    return _todayDate().isBefore(start);
  }

  // วันที่จริงของวันที่เลือกอยู่ = start + (day - 1) — null คือไม่ระบุวัน
  DateTime? _selectedDayDate(TravelPlan plan) {
    final start = _effectiveStartDate(plan);
    if (start == null) return null;
    final day = _selectedDayFor(plan);
    if (day == null) return null;
    return start.add(Duration(days: day.day - 1));
  }

  // นำทางได้เมื่อถึงวันของ day นั้นแล้ว (วันนี้ >= วันของ day) —
  // ทริปอนาคตทุกวันล็อกหมด, ทริปกำลังดำเนินปลดเฉพาะวันถึงแล้ว/ผ่านแล้ว
  bool _canNavigateNow(TravelPlan plan) {
    final dayDate = _selectedDayDate(plan);
    if (dayDate == null) return true;
    return !_todayDate().isBefore(dayDate);
  }

  // ข้อความอธิบายปุ่มนำทางที่ล็อก — มีวันที่บอกชัดเจน
  String _navigationLockedMessage(TravelPlan plan) {
    final dayDate = _selectedDayDate(plan);
    if (dayDate == null) return context.l10n.planSavedViewOnly;
    return context.l10n.navigationLocked(_date(dayDate));
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
  // ถ้ามีผลลัพธ์แผนอยู่แล้วและยังอยู่หน้า day 1 (มีขา GPS → สถานที่แรก) ให้วาดเส้นใหม่ด้วย
  // GPS เพิ่งมาแล้วพบว่าเป็นทริป local (ที่พัก/คำเตือนยังค้างอยู่) ให้ตัดออกทันที
  void _onSharedLocationChanged() {
    if (!mounted) return;
    final plan = _plan;
    final onFirstDay = plan != null &&
        plan.days.isNotEmpty &&
        (_selectedDayFor(plan)?.day == 1);
    setState(() {
      _position = _locationService.currentPosition;
      _locating = _locationService.isLoading;
      if (_locationService.error == null) _error = null;
    });
    final current = _plan;
    // กฎรถส่วนตัวคำนวณ deterministic รันซ้ำได้ — มีอะไรเปลี่ยนค่อย setState
    // (GPS/_places เพิ่งมาแล้วพบว่าเป็นทริป local ให้ตัดที่พัก/คำเตือน + คิดรถเป็นน้ำมันทันที)
    if (current != null) {
      final fixed = _applyPrivateCarRules(current);
      if (!identical(fixed, current)) {
        setState(() {
          _plan = fixed;
          _route = [];
        });
        unawaited(_buildRoute(fixed));
        return;
      }
    }
    if (plan != null && onFirstDay && _startPoint != null) {
      unawaited(_buildRoute(plan));
    }
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
    // _places เพิ่งมา (ตอนแรกยังเทียบจังหวัดไม่ได้) แล้วพบว่าเป็นทริป local
    // ให้ตัดที่พัก/คำเตือน + คิดรถเป็นน้ำมันทันที (ไม่มีอะไรเปลี่ยนไม่แตะ state)
    final current = _plan;
    if (current != null) {
      final fixed = _applyPrivateCarRules(current);
      if (!identical(fixed, current)) {
        setState(() {
          _plan = fixed;
          _route = [];
        });
        unawaited(_buildRoute(fixed));
      }
    }
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
    final plan = _plan;
    // ปักจุดเริ่มใหม่ระหว่างดูแผน day 1 → วาดขา GPS/จุดปัก → สถานที่แรกใหม่ทันที
    if (plan != null && _selectedDayFor(plan)?.day == 1) {
      unawaited(_buildRoute(plan));
    }
  }

  // ล้างจุดที่ปักเอง กลับไปใช้ GPS ปัจจุบัน
  void _clearCustomStart() {
    if (_customStartPoint == null) return;
    setState(() => _customStartPoint = null);
    final plan = _plan;
    // ล้างจุดปักระหว่างดูแผน day 1 → ขาแรกกลับไปเริ่มจาก GPS ปัจจุบันทันที
    if (plan != null && _selectedDayFor(plan)?.day == 1) {
      unawaited(_buildRoute(plan));
    }
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
  /// 'is_local_trip' = จุดเริ่มอยู่จังหวัดเดียวกับปลายทาง (ไปเช้าเย็นกลับ)
  /// — server ใช้ข้ามการแทรกที่พักค้างคืนได้, client ใช้ซ่อนที่พัก/ข้อควรรู้
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
      // start_date "YYYY-MM-DD" — server เก็บลง trips.start_date เพื่อให้แผนเก่าโชว์วันที่จริงได้
      if (_dates != null)
        'start_date':
            '${_dates!.start.year.toString().padLeft(4, '0')}-${_dates!.start.month.toString().padLeft(2, '0')}-${_dates!.start.day.toString().padLeft(2, '0')}',
      'budget': _budget.round(),
      'currency': 'THB',
      'interests': _interests.map((e) => e.toLowerCase()).toList(),
      'transport_modes': _modes.toList(),
      'start_latitude': start?.latitude,
      'start_longitude': start?.longitude,
      // ทริป local (จุดเริ่มอยู่จังหวัดเดียวกับปลายทาง) — บอก server ให้ข้ามที่พักค้างคืนได้
      'is_local_trip': _isLocalSelection(),
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
      var next = _ensureMustVisitStops(
        TravelPlan.fromJson(
          raw,
          tripId: tripId,
          title: '${trip['title'] ?? _planNameInput}',
          // ทริปใหม่: server เก็บ start_date จาก _input() แล้ว — ใช้ช่วงที่ผู้ใช้เลือกไว้ก่อน
          // (GET จะส่ง start_date มาด้วยสำหรับทริปเก่า ดู _loadExistingPlan)
          startDate: _dates == null
              ? ''
              : '${_dates!.start.year.toString().padLeft(4, '0')}-${_dates!.start.month.toString().padLeft(2, '0')}-${_dates!.start.day.toString().padLeft(2, '0')}',
        ),
      );
      // SSE warning event (ข้าง plan_data) — รวมเข้ากับ warnings ใน model
      // ให้แบนเนอร์หน้าผลลัพธ์แสดง แม้ plan_data เก่าจะไม่มี field นี้
      final streamed =
          ((result['warnings'] as List?) ?? const []).map((e) => '$e').toList();
      if (streamed.isNotEmpty) {
        next = next.copyWith(
          warnings: {...next.warnings, ...streamed}.toList(),
        );
      }
      // ทริป local (จุดเริ่มอยู่จังหวัดเดียวกับปลายทาง) — ตัดที่พัก/คำเตือน + คิดรถเป็นน้ำมัน
      // รถทุกทริปคิดน้ำมันอยู่แล้ว (cap รายวันเฉพาะ local) — เก็บ snapshot หลังปรับ reset จะได้ไม่เพี้ยน
      next = _applyPrivateCarRules(next);
      _storeOriginalPlan(next.toJson());
      // sync จำนวนวันที่ server resolve กลับเข้าฟอร์ม (auto หรือยังไม่เลือกวัน)
      // ให้ช่องวันที่/ตัวนับตรงกับแผนจริง — กดสร้างใหม่จะเริ่มจากจำนวนวันจริงของแผนนี้
      final resolvedDays = next.days.length;
      if ((_autoDays || _dates == null) && resolvedDays >= 1 && resolvedDays <= 7) {
        _days = resolvedDays;
      }
      setState(() {
        _plan = next;
        _planNameController.text = next.title;
        _selectedDayIndex = 0;
        _route = [];
        _generating = false;
        // วันเริ่มทริปไม่ใช่ = วันนี้ → ค้างจอ success "เริ่มต้นในวัน XX" ไว้ก่อน
        // (แผนบันทึกบน server แล้ว ดูได้อย่างเดียว นำทางได้เมื่อถึงวัน)
        _showCreatedSuccess = _isFutureTrip(next);
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
      startDate: plan.startDate,
      returnLeg: plan.returnLeg,
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

  // ทริป local = จุดเริ่มต้นอยู่จังหวัดเดียวกับจังหวัดปลายทาง (ไปเช้าเย็นกลับได้)
  // — ไม่ต้องมีที่พักค้างคืน (overnight) และไม่ต้องโชว์ "ข้อควรรู้ก่อนเดินทาง" (warnings)
  String _normalizeProvinceName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  // map ชื่อจังหวัด (ไทย/อังกฤษ) กลับเป็น value หลักใน DB ผ่าน _provinceOptions
  // กันเทียบพลาดตอนแอปเป็นภาษาอังกฤษ (PlaceMarker.province เป็น label อังกฤษ
  // แต่ _selectedProvince เป็น value ไทยเสมอ)
  String _canonicalProvince(String raw) {
    final norm = _normalizeProvinceName(raw);
    if (norm.isEmpty) return '';
    for (final opt in _provinceOptions) {
      if (_normalizeProvinceName(opt.value) == norm ||
          _normalizeProvinceName(opt.label) == norm) {
        return _normalizeProvinceName(opt.value);
      }
    }
    // alias กรุงเทพ (value หลักคือ กรุงเทพมหานคร)
    const bangkokAliases = {'กรุงเทพ', 'กรุงเทพมหานคร', 'bangkok'};
    if (bangkokAliases.contains(norm)) return 'กรุงเทพมหานคร';
    return norm;
  }

  // จังหวัดของจุดเริ่มต้น — ใช้สถานที่ใกล้สุดใน DB (threshold 100 กม.)
  // fallback เป็นจังหวัดของ stop ในแผนที่ใกล้จุดเริ่มสุด (50 กม.) กันตอน _places ยังโหลดไม่เสร็จ
  String _provinceOfStartPoint([TravelPlan? plan]) {
    final start = _startPoint;
    if (start == null) return '';
    var bestKm = double.infinity;
    var best = '';
    for (final p in _places) {
      if (p.province.isEmpty) continue;
      final km = const Distance().as(
        LengthUnit.Kilometer,
        start,
        LatLng(p.latitude, p.longitude),
      );
      if (km < bestKm) {
        bestKm = km;
        best = p.province;
      }
    }
    if (best.isNotEmpty && bestKm <= 100) return best;
    final current = plan ?? _plan;
    if (current != null) {
      var stopBestKm = double.infinity;
      var stopBest = '';
      for (final stop in current.allStops) {
        if (stop.isOvernight || stop.isRestStop) continue;
        final province = _provinceForStop(stop);
        if (province.isEmpty) continue;
        final km = const Distance().as(
          LengthUnit.Kilometer,
          start,
          LatLng(stop.latitude, stop.longitude),
        );
        if (km < stopBestKm) {
          stopBestKm = km;
          stopBest = province;
        }
      }
      if (stopBest.isNotEmpty && stopBestKm <= 50) return stopBest;
    }
    return bestKm <= 100 ? best : '';
  }

  // จังหวัดปลายทาง — ค่าที่เลือกในฟอร์มก่อน แผนเก่าใช้จังหวัดที่พบบ่อยสุดใน stops
  String _destinationProvince(TravelPlan plan) {
    if (_selectedProvince != null && _selectedProvince!.trim().isNotEmpty) {
      return _selectedProvince!.trim();
    }
    final counts = <String, int>{};
    final canonToRaw = <String, String>{};
    for (final stop in plan.allStops) {
      if (stop.isOvernight || stop.isRestStop) continue;
      final province = _provinceForStop(stop);
      if (province.isEmpty) continue;
      final canon = _canonicalProvince(province);
      if (canon.isEmpty) continue;
      counts[canon] = (counts[canon] ?? 0) + 1;
      canonToRaw.putIfAbsent(canon, () => province);
    }
    if (counts.isEmpty) return '';
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return canonToRaw[top.key] ?? '';
  }

  // true = จุดเริ่มต้นอยู่จังหวัดเดียวกับปลายทาง — เที่ยวแบบไปเช้าเย็นกลับได้
  bool _isLocalTrip(TravelPlan plan) {
    final startProvince = _canonicalProvince(_provinceOfStartPoint(plan));
    if (startProvince.isEmpty) return false;
    final destProvince = _canonicalProvince(_destinationProvince(plan));
    if (destProvince.isEmpty) return false;
    return startProvince == destProvince;
  }

  // true = ฟอร์มตอนนี้เลือกจังหวัดเดียวกับที่อยู่ (ใช้ตอน _input ส่ง flag ให้ server)
  bool _isLocalSelection() {
    final selected = _selectedProvince;
    if (selected == null || selected.trim().isEmpty) return false;
    final startProvince = _canonicalProvince(_provinceOfStartPoint());
    if (startProvince.isEmpty) return false;
    return startProvince == _canonicalProvince(selected);
  }

  // ตัดที่พักค้างคืน + คำเตือนออกสำหรับทริป local
  // ค่าโรงแรม (entryCost ของ overnight) หักจากหมวด accommodation ก่อน ส่วนที่เหลือหักจาก activities
  // กันหักซ้ำซ้อนกับ _withDeltaBudget ซึ่งนับ entryCost ทุก stop เป็น activities หมด
  TravelPlan _stripLocalTripExtras(TravelPlan plan) {
    final removed = plan.allStops.where((s) => s.isOvernight).toList();
    if (removed.isEmpty && plan.warnings.isEmpty) return plan;
    var removedTransport = 0.0;
    var removedFood = 0.0;
    var removedEntry = 0.0;
    for (final s in removed) {
      removedTransport += s.transportCost;
      removedFood += s.foodCost;
      removedEntry += s.entryCost;
    }
    final days = [
      for (final day in plan.days)
        TravelDay(
          day: day.day,
          theme: day.theme,
          stops: day.stops.where((s) => !s.isOvernight).toList(),
        ),
    ];
    double nonNegative(double v) => v < 0 ? 0 : v;
    final breakdown = Map<String, double>.from(plan.budgetBreakdown);
    double sumStops(
      double Function(TravelStop s) pick, {
      bool skipOvernightEntry = false,
    }) {
      var sum = 0.0;
      for (final day in plan.days) {
        for (final stop in day.stops) {
          if (skipOvernightEntry && stop.isOvernight) continue;
          sum += pick(stop);
        }
      }
      return sum;
    }

    breakdown['transport'] = nonNegative(
      (breakdown['transport'] ?? sumStops((s) => s.transportCost)) -
          removedTransport,
    );
    breakdown['food'] = nonNegative(
      (breakdown['food'] ?? sumStops((s) => s.foodCost)) - removedFood,
    );
    final oldAccommodation =
        breakdown['accommodation'] ??
        breakdown['hotel'] ??
        sumStops((s) => s.entryCost, skipOvernightEntry: false) -
            sumStops((s) => s.entryCost, skipOvernightEntry: true);
    final deductFromAccommodation = removedEntry.clamp(
      0,
      oldAccommodation,
    );
    final newAccommodation = nonNegative(
      oldAccommodation - deductFromAccommodation,
    );
    if (newAccommodation <= 0) {
      breakdown.remove('accommodation');
      breakdown.remove('hotel');
    } else {
      breakdown['accommodation'] = newAccommodation;
    }
    final remainder = nonNegative(removedEntry - deductFromAccommodation);
    if (remainder > 0) {
      breakdown['activities'] = nonNegative(
        (breakdown['activities'] ??
                sumStops((s) => s.entryCost, skipOvernightEntry: true)) -
            remainder,
      );
    }
    final newTotal = nonNegative(
      plan.totalEstimatedCost -
          removedTransport -
          removedFood -
          removedEntry,
    );
    return TravelPlan(
      tripId: plan.tripId,
      title: plan.title,
      summary: plan.summary,
      totalEstimatedCost: newTotal,
      budgetBreakdown: breakdown,
      days: days,
      tips: plan.tips,
      warnings: const [],
      startDate: plan.startDate,
      returnLeg: plan.returnLeg,
    );
  }

  // เกลี่ยค่าน้ำมันรถของวันให้รวมไม่เกินวันละ 300 บาทแบบสัดส่วน
  // คืน list ชุดใหม่ (เวลา/นาทีเดินทางคงเดิม เปลี่ยนแค่ราคาขา car)
  List<TravelStop> _capDayFuelCosts(List<TravelStop> stops) {
    final carIdx = <int>[];
    var sum = 0.0;
    for (var i = 0; i < stops.length; i++) {
      if (stops[i].transportMode.toLowerCase() == 'car') {
        carIdx.add(i);
        sum += stops[i].transportCost;
      }
    }
    if (carIdx.isEmpty || sum <= _localFuelCapPerDay) return stops;
    final factor = _localFuelCapPerDay / sum;
    final ordered = [...carIdx]
      ..sort(
        (a, b) => stops[b].transportCost.compareTo(stops[a].transportCost),
      );
    final capped = <int, double>{
      for (final i in carIdx) i: stops[i].transportCost,
    };
    var assigned = 0.0;
    for (var k = 0; k < ordered.length; k++) {
      final i = ordered[k];
      final value = k == ordered.length - 1
          ? (_localFuelCapPerDay - assigned).clamp(0, _localFuelCapPerDay).toDouble()
          : (stops[i].transportCost * factor).roundToDouble();
      capped[i] = value;
      assigned += value;
    }
    return [
      for (var i = 0; i < stops.length; i++)
        if (!capped.containsKey(i))
          stops[i]
        else
          stops[i].copyWith(
            transportCost: capped[i]!,
            segments: stops[i].segments.isEmpty ||
                    stops[i].segments.first.mode.toLowerCase() != 'car'
                ? stops[i].segments
                : [
                    TravelSegment(
                      mode: stops[i].segments.first.mode,
                      from: stops[i].segments.first.from,
                      to: stops[i].segments.first.to,
                      estimatedMinutes:
                          stops[i].segments.first.estimatedMinutes,
                      estimatedCost: capped[i]!,
                    ),
                    ...stops[i].segments.sublist(1),
                  ],
          ),
    ];
  }

  // รถยนต์ทุกคันคือรถส่วนตัว: คำนวณขารถยนต์ใหม่จากระยะจริงด้วยเรทน้ำมัน
  // (แผนเก่า/AI ใช้เรทแท็กซี่ 20 บาท/กม. รวมทุกขาแล้วยอดพุ่งเกินจริง)
  // capDaily = true เฉพาะทริป local (รวมไม่เกินวันละ 300) — ขับไกลจ่ายตามระยะจริง
  // คำนวณ deterministic จากพิกัดจึงรันซ้ำได้ — ไม่มีอะไรเปลี่ยนคืน plan เดิม
  TravelPlan _applyCarFuelModel(TravelPlan plan, {bool capDaily = false}) {
    final home = _startPoint;
    var saved = 0.0;
    var changed = false;
    LatLng? prev = home;
    final days = <TravelDay>[];
    for (final day in plan.days) {
      final stops = List<TravelStop>.from(day.stops);
      for (var i = 0; i < stops.length; i++) {
        final stop = stops[i];
        if (stop.transportMode.toLowerCase() != 'car') continue;
        final LatLng? from = i == 0
            ? prev
            : LatLng(stops[i - 1].latitude, stops[i - 1].longitude);
        if (from == null) continue;
        final km = const Distance().as(
          LengthUnit.Kilometer,
          from,
          LatLng(stop.latitude, stop.longitude),
        );
        final fuel = (km * _localFuelRatePerKm).roundToDouble();
        if ((fuel - stop.transportCost).abs() > 0.001) {
          saved += stop.transportCost - fuel;
          var segments = stop.segments;
          if (segments.isNotEmpty &&
              segments.first.mode.toLowerCase() == 'car') {
            final first = segments.first;
            segments = [
              TravelSegment(
                mode: first.mode,
                from: first.from,
                to: first.to,
                estimatedMinutes: first.estimatedMinutes,
                estimatedCost: fuel,
              ),
              ...segments.sublist(1),
            ];
          }
          stops[i] = stop.copyWith(
            transportCost: fuel,
            segments: segments,
          );
          changed = true;
        }
      }
      final capped = capDaily ? _capDayFuelCosts(stops) : stops;
      for (var i = 0; i < stops.length; i++) {
        if ((capped[i].transportCost - stops[i].transportCost).abs() > 0.001) {
          saved += stops[i].transportCost - capped[i].transportCost;
          changed = true;
        }
      }
      days.add(TravelDay(day: day.day, theme: day.theme, stops: capped));
      if (day.stops.isNotEmpty) {
        final last = day.stops.last;
        prev = LatLng(last.latitude, last.longitude);
      }
    }
    // ขากลับบ้านขับรถตัวเองกลับ — คิดน้ำมันด้วย
    var returnLeg = plan.returnLeg;
    if (returnLeg != null && returnLeg.mode.toLowerCase() == 'car') {
      final fuel =
          (returnLeg.distanceKm * _localFuelRatePerKm).roundToDouble();
      if ((fuel - returnLeg.estimatedCost).abs() > 0.001) {
        saved += returnLeg.estimatedCost - fuel;
        returnLeg = TravelReturnLeg(
          from: returnLeg.from,
          to: returnLeg.to,
          distanceKm: returnLeg.distanceKm,
          estimatedMinutes: returnLeg.estimatedMinutes,
          estimatedCost: fuel,
          mode: returnLeg.mode,
        );
        changed = true;
      }
    }
    if (!changed) return plan;
    double nonNegative(double v) => v < 0 ? 0 : v;
    var transportSum = 0.0;
    for (final d in plan.days) {
      for (final s in d.stops) {
        transportSum += s.transportCost;
      }
    }
    final breakdown = Map<String, double>.from(plan.budgetBreakdown);
    breakdown['transport'] = nonNegative(
      (breakdown['transport'] ?? transportSum) - saved,
    );
    return TravelPlan(
      tripId: plan.tripId,
      title: plan.title,
      summary: plan.summary,
      totalEstimatedCost: nonNegative(plan.totalEstimatedCost - saved),
      budgetBreakdown: breakdown,
      days: days,
      tips: plan.tips,
      warnings: plan.warnings,
      startDate: plan.startDate,
      returnLeg: returnLeg,
    );
  }

  // กฎรถส่วนตัวครบชุดทุกทริป: ทริป local ตัดที่พัก + คำเตือนก่อน แล้วปรับขารถเป็นค่าน้ำมัน
  // (cap รายวัน 300 เฉพาะทริป local — ขับไกลจ่ายตามระยะจริง)
  TravelPlan _applyPrivateCarRules(TravelPlan plan) {
    final isLocal = _isLocalTrip(plan);
    final stripped = isLocal ? _stripLocalTripExtras(plan) : plan;
    return _applyCarFuelModel(stripped, capDaily: isLocal);
  }

  // รถยนต์ทุกคันคือรถส่วนตัว: คิดแค่ค่าน้ำมัน ~3 บาท/กม. ไม่มีขั้นต่ำ ไม่มีเรทแท็กซี่
  // (mirror estimateLegCostKm/estimateFuelCostKm ฝั่ง server)
  static const _localFuelRatePerKm = 3.0;

  // ค่าน้ำมันรถรวมทั้งวันไม่เกิน 300 บาท (เฉพาะทริป local — เกินเกลี่ยแบบสัดส่วนใน _capDayFuelCosts)
  static const _localFuelCapPerDay = 300.0;

  // ประมาณค่าเดินทางตามระยะทาง × อัตราต่อกม. ของแต่ละพาหนะ (รถอื่นขั้นต่ำ 50฿)
  double _estimateTransportCost(LatLng from, LatLng to, String mode) {
    final lower = mode.toLowerCase();
    if (lower == 'walking') return 0;
    final km = const Distance().as(LengthUnit.Kilometer, from, to);
    if (lower == 'car') return (km * _localFuelRatePerKm).roundToDouble();
    final rate = switch (lower) {
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
  // จุดแวะพัก OSM เติม suffix กันชนกับ destinations ใน DB ที่ชื่อซ้ำกันพอดี
  String _stopIdentity(TravelStop stop) {
    final id = stop.destinationId.trim();
    if (id.isNotEmpty) {
      return stop.isRestStop ? 'rest:$id' : 'id:$id';
    }
    return 'place:${_placeKey(stop.place)}';
  }

  // สร้างขาเข้า departure→stop0 ให้จุดแรกของวันแรกจากจุดเริ่มต้นจริง (GPS/จุดปัก)
  // (server contract: start_time คือ DEPARTURE ไม่ใช่ arrival,
  // stops[0].segments[0] คือขา departure→stop0 เมื่อมี)
  // นาที/ค่าประมาณด้วยคณิตเดียวกับขา day-1 GPS ฝั่ง client
  // (haversine × 2 นาที/กม. + estimateTransportCost) — _buildRoute ขอ road route
  // แบบ async จึงใช้ในโซ่ sync นี้ไม่ได้
  TravelStop _departureLeg(LatLng start, TravelStop stop) {
    final to = LatLng(stop.latitude, stop.longitude);
    final km = const Distance().as(LengthUnit.Kilometer, start, to);
    final minutes = (km * 2).round().clamp(5, 720);
    final cost = _estimateTransportCost(start, to, stop.transportMode);
    return stop.copyWith(
      transportCost: cost,
      segments: [
        TravelSegment(
          mode: stop.transportMode,
          from: _customStartPoint != null
              ? context.l10n.startPointCustom
              : context.l10n.startPointGps,
          to: stop.place,
          estimatedMinutes: minutes,
          estimatedCost: cost,
        ),
      ],
    );
  }

  /// คำนวณค่าเดินทางใหม่เฉพาะขาที่เปลี่ยน (จุดก่อนหน้าเปลี่ยนจากการลบ/สลับ)
  /// ขาเดิมคงค่า AI ไว้ทั้งหมด กันยอดรวมร่วงทั้งก้อนทั้งที่จุดที่ลบค่าเดินทางเป็น 0
  /// จุดแรกของวัน: day start input คือ DEPARTURE — คงขาเข้าไว้ทั้ง minutes
  /// และ cost ห้าม zero (arrival0 = departure + leg ใน _rechainDay);
  /// ถ้าขาเข้าว่างและเป็นวันแรก ให้เติมขา departure→stop0 จากจุดเริ่มต้นจริง
  List<TravelStop> _recalculatedStopsPreservingCosts(
    List<TravelStop> oldStops,
    List<TravelStop> newStops, {
    bool isFirstDay = false,
  }) {
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
      // กลายเป็นจุดแรกของวัน (ไม่มีขาเข้า) — มีขาอยู่แล้ว (จาก server
      // หรือรอบก่อน) ให้คงไว้ทั้ง minutes/cost ห้าม zero;
      // ถ้าขาเข้าว่างและเป็นวันแรกที่มีจุดเริ่ม ให้เติมขา
      // departure→stop0; วันอื่นหรือไม่มีจุดเริ่มคงพฤติกรรมเดิม
      if (i == 0) {
        if (stop.segments.isNotEmpty) {
          updated.add(stop);
        } else {
          final start = _startPoint;
          if (isFirstDay && start != null) {
            updated.add(_departureLeg(start, stop));
          } else {
            updated.add(stop.copyWith(transportCost: 0, segments: const []));
          }
        }
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

  // ต่อโซ่ arrivalTime ใหม่ทั้งวันตามลำดับปัจจุบัน
  // day start input คือ DEPARTURE (ไม่ใช่ arrival): จุดแรกถ้ามีขาเข้า
  // (stops[0].segments[0], minutes > 0) ให้ arrival0 = departure + leg
  // โดยคง minutes/cost เดิม ห้าม zero; ไม่มีขาเข้าถือว่า arrival0 = departure
  // จุดถัดไป: arrival = prev leave + segments (พฤติกรรมเดิม)
  // กันเวลาค้างตามลำดับเก่าหลังลบ/สลับจุด — server จะคำนวณเวลาจริงซ้ำตอน PUT อีกที
  List<TravelStop> _rechainDay(List<TravelStop> stops) {
    if (stops.isEmpty) return stops;
    final chained = <TravelStop>[
      stops.first.copyWith(
        arrivalTime: _firstStopArrival(stops.first),
      ),
    ];
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

  // arrival ของจุดแรกของวัน: departure + ขาเข้าเมื่อมี
  // ไม่มีขาเข้าหรือ leg <= 0 → arrival = departure (เวลาเริ่มที่ผู้ใช้เลือก)
  String _firstStopArrival(TravelStop first) {
    final departure = _clockOf(_startTime);
    if (first.segments.isEmpty) return departure;
    final leg = first.segments.first.estimatedMinutes;
    if (leg <= 0) return departure;
    return _clockFromMinutes(_clockToMinutes(departure) + leg);
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
      startDate: plan.startDate,
      returnLeg: plan.returnLeg,
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
    // วันแรกเริ่มออกจากจุดเริ่มต้นจริง (GPS/จุดที่ปักเอง) — ขาแรกคือ GPS → สถานที่แรก
    // วันอื่นเริ่มจากที่พักค้างคืนซึ่งอยู่ใกล้จุดสุดท้ายของเมื่อวาน ใช้ลำดับ stops อย่างเดียว
    final includeStart = day?.day == 1 && _startPoint != null;
    if (day == null || day.stops.length < (includeStart ? 1 : 2)) {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _route = []);
      }
      return;
    }

    final legs = <_PlanRouteLeg>[];
    var from = includeStart
        ? _startPoint!
        : LatLng(day.stops.first.latitude, day.stops.first.longitude);
    for (final stop in (includeStart ? day.stops : day.stops.skip(1))) {
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

  // เพิ่มวันเปล่าต่อท้ายแผน (สูงสุด 7 วันตาม limit ฝั่ง server)
  // วันใหม่เริ่มว่าง — user เติมสถานที่ด้วยปุ่มเพิ่มสถานที่ของวันนั้น
  // เลขวันเรียงใหม่ 1..N ให้ตรงกับที่ server คาดหวัง แล้ว save กลับทันที
  void _addPlanDay() {
    final plan = _plan;
    if (plan == null || plan.tripId <= 0) return;
    if (plan.days.length >= 7) {
      _showPlanSnack(context.l10n.maxDaysReached);
      return;
    }
    final days = [
      for (final day in plan.days)
        TravelDay(
          day: day.day,
          theme: day.theme,
          stops: List<TravelStop>.from(day.stops),
        ),
      TravelDay(day: plan.days.length + 1, theme: '', stops: <TravelStop>[]),
    ];
    final updated = plan.copyWith(days: _renumberPlanDays(days));
    setState(() {
      _plan = updated;
      _selectedDayIndex = updated.days.length - 1;
      _route = [];
    });
    _showPlanSnack(context.l10n.dayAdded(updated.days.length));
    unawaited(_savePlanChanges(updated));
    unawaited(_buildRoute(updated));
  }

  // ลบวันที่เลือกอยู่หลัง user ยืนยัน — เหลือวันเดียวลบไม่ได้ (server ต้องการ ≥1 วัน)
  // สถานที่ในวันที่ลบจะหายไปด้วย (budget ปรับแบบ delta เหมือนลบจุดทีละจุด)
  Future<void> _confirmRemovePlanDay(TravelPlan plan) async {
    final index = _selectedDayIndex.clamp(0, plan.days.length - 1);
    if (plan.days.length <= 1) {
      _showPlanSnack(context.l10n.removeDayDisabled);
      return;
    }
    final day = plan.days[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.removeDay),
        content: Text(
          dialogContext.l10n.removeDayConfirmation(day.day, day.stops.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.removeDay),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final current = _plan;
    if (current == null) return;
    final safeIndex = _selectedDayIndex.clamp(0, current.days.length - 1);
    final days = [
      for (var i = 0; i < current.days.length; i++)
        if (i != safeIndex)
          TravelDay(
            day: current.days[i].day,
            theme: current.days[i].theme,
            stops: List<TravelStop>.from(current.days[i].stops),
          ),
    ];
    final updated = _withDeltaBudget(
      current,
      _renumberPlanDays(days),
    );
    setState(() {
      _plan = updated;
      _selectedDayIndex = _selectedDayIndex.clamp(0, updated.days.length - 1);
      _route = [];
    });
    _showPlanSnack(context.l10n.dayRemoved(day.day));
    unawaited(_savePlanChanges(updated));
    unawaited(_buildRoute(updated));
  }

  // เรียงเลขวันใหม่ 1..N หลังเพิ่ม/ลบวัน — กันเลขกระโดดที่ server ไม่คาดหวัง
  List<TravelDay> _renumberPlanDays(List<TravelDay> days) {
    final renumbered = <TravelDay>[];
    for (var i = 0; i < days.length; i++) {
      renumbered.add(
        TravelDay(day: i + 1, theme: days[i].theme, stops: days[i].stops),
      );
    }
    return renumbered;
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
      var newStop = rawNew.copyWith(
        transportCost: estimated,
        segments: newSegments.isEmpty ? rawNew.segments : newSegments,
      );
      // แปะเป็นที่แรกของวันแรกโดยตรง (วันว่าง) — ขาเข้าว่างให้เติมขา
      // departure→stop0 จากจุดเริ่มต้นจริงเหมือนกติกาวันแรกข้ออื่น
      // (arrival0 = departure + leg ไม่ใช่ departure เฉย ๆ)
      if (prev == null &&
          plan.days[selectedIndex].day == 1 &&
          newStop.segments.isEmpty) {
        final start = _startPoint;
        if (start != null) {
          final filled = _departureLeg(start, newStop);
          newStop = filled.copyWith(arrivalTime: _firstStopArrival(filled));
          estimated = newStop.transportCost;
        }
      }
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
        startDate: plan.startDate,
        returnLeg: plan.returnLeg,
      );
    } else {
      // ลบ/สลับลำดับ → ประมาณใหม่เฉพาะขาที่เปลี่ยน ที่เหลือคงค่า AI เดิม
      // จุดแรกของวันยึด departure semantics (arrival0 = departure + leg)
      recalculatedStops = _rechainDay(
        _recalculatedStopsPreservingCosts(
          oldStops,
          stops,
          isFirstDay: plan.days[selectedIndex].day == 1,
        ),
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

    // ทริป local: ค่าน้ำมันรวมของวันที่แก้ไม่เกินวันละ 300 (เกินเกลี่ยแบบสัดส่วน)
    // ขาใหม่คิดเรทน้ำมันมาแล้วจาก _estimateTransportCost เหลือแค่ cap ยอดรวม
    updatedPlan = _capLocalDayFuel(updatedPlan, selectedIndex);

    setState(() {
      _plan = updatedPlan;
      _route = [];
    });
    unawaited(_savePlanChanges(updatedPlan));
    unawaited(_buildRoute(updatedPlan));
    // เพิ่มสถานที่ไกล ๆ อาจต้องมีจุดพัก/ปั๊มเพิ่ม — ให้ระบบเติมให้เองถ้าขับยาว
    unawaited(_enrichDayRestStops(selectedIndex));
  }

  // ทริป local: cap ค่าน้ำมันของวันให้รวมไม่เกิน 300 — คืนแผนใหมเฉพาะเมื่อยอดเปลี่ยน
  TravelPlan _capLocalDayFuel(TravelPlan plan, int dayIndex) {
    if (!_isLocalTrip(plan)) return plan;
    if (dayIndex < 0 || dayIndex >= plan.days.length) return plan;
    final capped = _capDayFuelCosts(plan.days[dayIndex].stops);
    var diff = 0.0;
    for (var i = 0; i < capped.length; i++) {
      diff += capped[i].transportCost - plan.days[dayIndex].stops[i].transportCost;
    }
    if (diff.abs() <= 0.001) return plan;
    double nonNegative(double v) => v < 0 ? 0 : v;
    final cappedBreakdown = Map<String, double>.from(plan.budgetBreakdown);
    cappedBreakdown['transport'] = nonNegative(
      (cappedBreakdown['transport'] ?? 0) + diff,
    );
    return TravelPlan(
      tripId: plan.tripId,
      title: plan.title,
      summary: plan.summary,
      totalEstimatedCost: nonNegative(plan.totalEstimatedCost + diff),
      budgetBreakdown: cappedBreakdown,
      days: [
        for (var index = 0; index < plan.days.length; index++)
          TravelDay(
            day: plan.days[index].day,
            theme: plan.days[index].theme,
            stops: index == dayIndex
                ? capped
                : List<TravelStop>.from(plan.days[index].stops),
          ),
      ],
      tips: plan.tips,
      warnings: plan.warnings,
      startDate: plan.startDate,
      returnLeg: plan.returnLeg,
    );
  }

  // โควต้าจุดพัก/ปั๊มที่เติมให้เองตอนแก้แผน (mirror server MAX_REST_PER_DAY)
  static const _maxAutoRestPerDay = 2;

  // วันขับรถรวมตั้งแต่ 150 กม. เติมปั๊ม 1 จุด (mirror server LONG_DRIVE_FUEL_KM)
  static const _longDriveFuelKm = 150.0;

  // ค่าอาหารประมาณของจุดแวะตามประเภท (mirror server REST_FOOD_COST_BY_TYPE)
  double _restFoodCost(String type) => switch (type.toLowerCase()) {
    'cafe' => 120,
    'restaurant' => 180,
    'convenience' => 60,
    'parking' => 20,
    'toilets' => 10,
    _ => 0,
  };

  // สร้าง TravelStop จุดแวะพักจาก POI ที่ GET /mobile/rest-stops คืนมา
  // (โครงเดียวกับ buildRestStop ฝั่ง server — เวลา/ค่าเดินทางคำนวณใหม่ตอนแทรก)
  TravelStop _restStopFromPoi(
    Map<String, dynamic> poi,
    String mode,
    String attribution,
  ) {
    final type = '${poi['type'] ?? 'place'}'.toLowerCase();
    final label = '${poi['typeLabel'] ?? 'จุดแวะพัก'}';
    final brand = '${poi['brand'] ?? ''}'.trim();
    final rawName = '${poi['name'] ?? ''}'.trim();
    return TravelStop(
      destinationId: '${poi['id'] ?? ''}',
      place: rawName.isEmpty ? '$label (OSM)' : rawName,
      province: '',
      activity: 'แวะพัก$labelระหว่างทาง${brand.isEmpty ? '' : ' $brand'}'.trim(),
      latitude: (poi['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (poi['longitude'] as num?)?.toDouble() ?? 0,
      imageUrl: '',
      arrivalTime: _clockOf(_startTime),
      durationMinutes: 20,
      entryCost: 0,
      foodCost: _restFoodCost(type),
      transportMode: mode,
      transportCost: 0,
      tip: attribution.isEmpty
          ? 'จุดแวะพักระหว่างทาง ($label)'
          : 'จุดแวะพักระหว่างทาง ($label) — ข้อมูล $attribution',
      segments: const [],
      isRestStop: true,
      restType: type,
      stopType: 'rest',
    );
  }

  // เติมปั๊มน้ำมันให้วันที่เพิ่งแก้โดยอัตโนมัติเมื่อมีขาขับยาว (mirror enrich ฝั่ง server)
  // เอาแค่ปั๊มน้ำมัน — เพิ่มสถานที่ไกล ๆ แล้วมีจุดพักไหม: มี ถ้าขา car/bus ≥2 ชม.
  // (นาที = ระยะ × 2 แบบเดียวกับที่โชว์) หรือวันขับรวม ≥150 กม. (ปั๊ม 1 จุด)
  // ไม่เจอปั๊มในรัศมีข้ามขานั้นไป ไม่เติมคาเฟ่/ร้านสะดวกซื้อแทน
  // รันหลัง _replaceSelectedDayStops ทุกครั้ง ถ้าไม่เข้าเกณฑ์จบเงียบ ๆ ไม่แตะ state
  Future<void> _enrichDayRestStops(int dayIndex) async {
    final plan = _plan;
    if (plan == null || plan.tripId <= 0) return;
    if (dayIndex < 0 || dayIndex >= plan.days.length) return;
    final day = plan.days[dayIndex];

    // origin ของวัน (ขาแรก): วันที่ 1 = จุดเริ่มจริง, วันอื่น = จุดสุดท้ายวันก่อน
    LatLng? origin;
    if (day.day == 1) {
      origin = _startPoint;
    } else if (dayIndex > 0 && plan.days[dayIndex - 1].stops.isNotEmpty) {
      final last = plan.days[dayIndex - 1].stops.last;
      origin = LatLng(last.latitude, last.longitude);
    }

    bool eligibleMode(String mode) {
      final lower = mode.toLowerCase();
      return lower == 'car' || lower == 'bus';
    }

    // ขาในวันนี้รวมขาแรก — ข้ามขาที่ปลายเป็นจุดพักอยู่แล้ว
    final legs = <_EnrichLeg>[];
    final stops = day.stops;
    if (origin != null && stops.isNotEmpty) {
      final first = stops.first;
      if (!first.isRestStop &&
          !first.destinationId.startsWith('osm:') &&
          eligibleMode(first.transportMode)) {
        legs.add(
          _EnrichLeg(
            index: 0,
            from: origin,
            to: LatLng(first.latitude, first.longitude),
            mode: first.transportMode,
          ),
        );
      }
    }
    for (var i = 1; i < stops.length; i++) {
      final curr = stops[i];
      if (curr.isRestStop ||
          curr.destinationId.startsWith('osm:') ||
          !eligibleMode(curr.transportMode)) {
        continue;
      }
      final prev = stops[i - 1];
      legs.add(
        _EnrichLeg(
          index: i,
          from: LatLng(prev.latitude, prev.longitude),
          to: LatLng(curr.latitude, curr.longitude),
          mode: curr.transportMode,
        ),
      );
    }
    if (legs.isEmpty) return;

    double legKm(_EnrichLeg leg) =>
        const Distance().as(LengthUnit.Kilometer, leg.from, leg.to);
    // นาที files เดียวกับที่โชว์บนการ์ด (2 นาที/กม.)
    int legMinutes(_EnrichLeg leg) => (legKm(leg) * 2).round();

    final usedIds = <String>{
      for (final s in stops)
        if (s.destinationId.trim().isNotEmpty) s.destinationId.trim(),
    };
    var quota =
        _maxAutoRestPerDay -
        stops
            .where((s) => s.isRestStop || s.destinationId.startsWith('osm:'))
            .length;
    String attribution = '';
    // หา POI ใกล้จุดกลางขา — คืน null เมื่อไม่เจอ/ซ้ำ (ข้ามขานั้นไป)
    Future<Map<String, dynamic>?> pickPoi(
      LatLng mid, {
      required int radius,
      String? types,
    }) async {
      final res = await AppServices.trips.searchRestStops(
        latitude: mid.latitude,
        longitude: mid.longitude,
        radius: radius,
        types: types,
        limit: 3,
      );
      if (res.attribution.isNotEmpty) attribution = res.attribution;
      for (final poi in res.stops) {
        final id = '${poi['id'] ?? ''}'.trim();
        if (id.isEmpty || usedIds.contains(id)) continue;
        return poi;
      }
      return null;
    }

    // งานแทรกเก็บ index ดิบ (ตำแหน่งใน stops เดิม) — เรียงแล้วบวก offset ตอน splice
    final insertions = <({int index, TravelStop stop})>[];

    // 1) วันขับรวมไกลเติมปั๊มก่อน 1 จุดกลางขาที่ยาวสุด (เหมือน server ให้ปั๊มมาก่อน)
    final totalKm = legs.fold<double>(0, (sum, leg) => sum + legKm(leg));
    final hasFuel = stops.any(
      (s) =>
          s.restType.toLowerCase() == 'fuel' ||
          RegExp(r'ปั๊มน้ำมัน|เติมน้ำมัน').hasMatch('${s.place} ${s.activity}'),
    );
    if (!hasFuel && totalKm >= _longDriveFuelKm && quota > 0) {
      final longest = legs.reduce((a, b) => legKm(b) > legKm(a) ? b : a);
      final mid = LatLng(
        (longest.from.latitude + longest.to.latitude) / 2,
        (longest.from.longitude + longest.to.longitude) / 2,
      );
      final poi = await pickPoi(mid, radius: 8000, types: 'fuel');
      if (poi != null) {
        usedIds.add('${poi['id'] ?? ''}'.trim());
        insertions.add(
          (index: longest.index, stop: _restStopFromPoi(poi, longest.mode, attribution)),
        );
        quota--;
      }
    }

    // 2) ขาขับยาว ≥2 ชม. เติมปั๊ม (ขาละ floor(นาที/120) สูงสุด 2 รวมไม่เกินโควต้า)
    // เอาแค่ปั๊มน้ำมัน — ไม่เจอปั๊มข้ามขานี้ไป
    for (final leg in legs) {
      if (quota <= 0) break;
      final minutes = legMinutes(leg);
      if (minutes < 120) continue;
      var needed = minutes ~/ 120;
      if (needed > 2) needed = 2;
      if (needed > quota) needed = quota;
      for (var k = 1; k <= needed; k++) {
        if (quota <= 0) break;
        final frac = k / (needed + 1);
        final mid = LatLng(
          leg.from.latitude + (leg.to.latitude - leg.from.latitude) * frac,
          leg.from.longitude + (leg.to.longitude - leg.from.longitude) * frac,
        );
        final poi = await pickPoi(mid, radius: 5000, types: 'fuel');
        if (poi == null) continue;
        usedIds.add('${poi['id'] ?? ''}'.trim());
        insertions.add(
          (index: leg.index, stop: _restStopFromPoi(poi, leg.mode, attribution)),
        );
        quota--;
      }
    }
    if (insertions.isEmpty) return;

    // มีการแก้ซ้อนระหว่างรอ network → ยกเลิกกันชน (ทุกการแก้สร้าง TravelPlan ใหม่เสมอ)
    final current = _plan;
    if (current == null || !identical(current, plan)) return;
    if (dayIndex >= current.days.length) return;
    final freshDay = current.days[dayIndex];
    if (freshDay.stops.length != stops.length) return;

    insertions.sort((a, b) => a.index.compareTo(b.index));
    // index ดิบเรียงจากหน้าไปหลัง บวก offset งานแทรกก่อนหน้าไปด้วยทีละ 1
    final newStops = List<TravelStop>.from(freshDay.stops);
    var offset = 0;
    for (final ins in insertions) {
      newStops.insert(ins.index + offset, ins.stop);
      offset++;
    }
    final recalculated = _rechainDay(
      _recalculatedStopsPreservingCosts(
        freshDay.stops,
        newStops,
        isFirstDay: freshDay.day == 1,
      ),
    );
    final days = [
      for (var index = 0; index < current.days.length; index++)
        TravelDay(
          day: current.days[index].day,
          theme: current.days[index].theme,
          stops: index == dayIndex
              ? recalculated
              : List<TravelStop>.from(current.days[index].stops),
        ),
    ];
    var updated = _withDeltaBudget(current, days);
    updated = _capLocalDayFuel(updated, dayIndex);
    setState(() {
      _plan = updated;
      _route = [];
    });
    unawaited(_savePlanChanges(updated));
    unawaited(_buildRoute(updated));
  }

  /// บันทึกการแก้ไขสถานที่ (ลบ/เพิ่ม/สลับลำดับ) กลับลง server
  /// เพื่อให้เปิดแผนเดิมจาก Profile ได้ตรงกับที่ผู้ใช้แก้ไขล่าสุด
  ///
  /// จุด 6: server เดินโซ่เวลาใหม่แบบคงลำดับเดิม (chainAllDaysPreservingOrder)
  /// แล้วคืน warnings — ถ้าส่งเวลากลับมาจะ sync เข้า state ให้ตรงกันทันที
  /// ส่ง start_time เสริมด้วยเพื่อให้โซ่เวลาของวันเริ่มจากเวลาที่ผู้ใช้เลือกเหมือนตอนสร้าง
  Future<void> _savePlanChanges(TravelPlan plan) async {    if (plan.tripId <= 0) return;
    final result = await AppServices.trips.updateTravelPlan(
      plan.tripId,
      {...plan.toJson(), 'start_time': _clockOf(_startTime)},
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final warnings =
          ((result['warnings'] as List?) ?? const []).map((e) => '$e').toList();
      // ทริป local ไม่ต้องมี "ข้อควรรู้ก่อนเดินทาง" — ทิ้ง warnings ที่ server ส่งกลับมา
      if (_plan != null && _isLocalTrip(_plan!)) {
        if ((_plan?.warnings ?? const []).isNotEmpty) {
          setState(() {
            _plan = _plan?.copyWith(warnings: const []);
          });
        }
        return;
      }
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
        _plan = plan.copyWith(title: name);
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
      // reset ย้อนแค่ stops — วันที่เริ่มทริปของ session นี้ยังใช้ต่อได้
      startDate: plan.startDate,
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
      _showCreatedSuccess = false;
    });
  }

  @override
  Widget build(BuildContext context) => _buildScaffold(context);
}
