import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/model/place_marker.dart';
import 'package:myapp/model/travel_plan.dart';
import 'package:myapp/screen/destination_detail_screen.dart';
import 'package:myapp/screen/plan_navigation_screen.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/services/location_service.dart';
import 'package:myapp/utils/destination_display.dart';
import 'package:myapp/widgets/media_image.dart';
import 'package:myapp/widgets/plan_day_selector.dart';
import 'package:myapp/widgets/province_selector.dart';

part 'plan/plan_view.dart';
part 'plan/plan_details.dart';
part 'plan/plan_components.dart';

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

  final LocationService _locationService = LocationService.instance;
  final _map = MapController();
  final _planMapKey = GlobalKey();
  DateTimeRange? _dates;
  double _budget = 30000;
  int _days = 3;
  LatLng? _position;
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
  late String _loadedLanguage;

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
      final plan = TravelPlan.fromJson(raw, tripId: tripId);

      setState(() {
        _plan = plan;
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

  /// รวมทุก input บนฟอร์มเป็น JSON body สำหรับยิงสร้างแผน
  Map<String, dynamic> _input() => {
    'destination': _selectedProvince,
    'province': _selectedProvince,
    'days': _days,
    'budget': _budget.round(),
    'currency': 'THB',
    'interests': _interests.map((e) => e.toLowerCase()).toList(),
    'transport_modes': _modes.toList(),
    'start_latitude': _position?.latitude,
    'start_longitude': _position?.longitude,
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

  /// กดปุ่มสร้างแผน — ยิงให้ AI สร้างแผนจาก _input() แล้วแปลง plan_data
  /// เป็น TravelPlan, เติม must-visit ที่หายไป, สลับไปหน้าผลลัพธ์ และวาดเส้นทาง
  Future<void> _generate() async {
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
      final next = _ensureMustVisitStops(
        TravelPlan.fromJson(raw, tripId: tripId),
      );
      setState(() {
        _plan = next;
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
      day.stops.add(_mustVisitStop(place, day.stops.length));
    }

    return TravelPlan(
      tripId: plan.tripId,
      summary: plan.summary,
      totalEstimatedCost: plan.totalEstimatedCost,
      budgetBreakdown: plan.budgetBreakdown,
      days: days,
      tips: plan.tips,
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

  TravelStop _mustVisitStop(PlaceMarker place, int stopIndex) {
    final activity = stripHtmlText(place.description).trim();
    return TravelStop(
      destinationId: place.id,
      place: place.title,
      province: place.province,
      activity: activity.isEmpty ? 'แวะชม ${place.title}' : activity,
      latitude: place.latitude,
      longitude: place.longitude,
      imageUrl: place.imageUrl,
      arrivalTime: _arrivalTimeForStopIndex(stopIndex),
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
      summary: plan.summary,
      totalEstimatedCost: newTotal,
      budgetBreakdown: newBreakdown,
      days: newDays,
      tips: plan.tips,
    );
  }

  String _arrivalTimeForStopIndex(int stopIndex) {
    const slots = ['09:00', '11:00', '13:30', '15:30', '17:00'];
    final index = stopIndex.clamp(0, slots.length - 1).toInt();
    return slots[index];
  }

  String _placeKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

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

  TravelDay? _selectedDayFor(TravelPlan plan) {
    if (plan.days.isEmpty) return null;
    final index = _selectedDayIndex.clamp(0, plan.days.length - 1);
    return plan.days[index];
  }

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
    _replaceSelectedDayStops(stops);
  }

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
  }

  void _addStopToSelectedDay(PlaceMarker place) {
    final plan = _plan;
    if (plan == null) return;
    final day = _selectedDayFor(plan);
    if (day == null ||
        day.stops.any((stop) => stop.destinationId == place.id)) {
      return;
    }

    _replaceSelectedDayStops([
      ...day.stops,
      _mustVisitStop(place, day.stops.length),
    ]);
  }

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
        summary: plan.summary,
        totalEstimatedCost: newTotal,
        budgetBreakdown: newBreakdown,
        days: days,
        tips: plan.tips,
      );
    } else {
      // ลบ/สลับลำดับ → ประมาณใหม่เฉพาะขาที่เปลี่ยน ที่เหลือคงค่า AI เดิม
      recalculatedStops = _recalculatedStopsPreservingCosts(oldStops, stops);
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
  Future<void> _savePlanChanges(TravelPlan plan) async {
    if (plan.tripId <= 0) return;
    final result = await AppServices.trips.updateTravelPlan(
      plan.tripId,
      plan.toJson(),
    );
    if (!mounted || result['success'] == true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result['message'] ?? 'บันทึกแผนไม่สำเร็จ'}')),
    );
  }

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
    setState(() {
      _plan = null;
      _route = [];
      _selectedDayIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) => _buildScaffold(context);
}
