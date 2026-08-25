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

class _PlanRouteLeg {
  const _PlanRouteLeg({required this.mode, required this.points});

  final String mode;
  final List<LatLng> points;
}

/// สร้างและแสดงแผนเที่ยวจาก AI ก่อนส่งจุดแวะไปยังหน้าจอนำทาง
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, this.initialTripId});

  /// เปิดด้วยแผนที่บันทึกไว้แล้ว (โหลดจาก GET /trips/:id)
  final int? initialTripId;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

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

  static const _interestOptions = [
    'Food',
    'Cafe',
    'Nature',
    'Beach',
    'Temple',
    'Adventure',
    'Shopping',
    'Nightlife',
    'Culture',
  ];
  static const _modeOptions = <String, IconData>{
    'car': Icons.directions_car,
    'walking': Icons.directions_walk,
    'bus': Icons.directions_bus,
    'train': Icons.train,
    'ferry': Icons.directions_boat,
    'flight': Icons.flight,
  };

  @override
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

  Future<void> _loadPlanOptions() async {
    final res = await AppServices.trips.getPlanOptions();
    if (!mounted || res['success'] != true || res['data'] is! Map) return;

    final data = Map<String, dynamic>.from(res['data'] as Map);
    final rawInterests = (data['interests'] as List? ?? []);
    final rawModes = (data['transportModes'] as List? ?? []);

    setState(() {
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
    });
  }

  void _loadProfileInterests() {
    final rawInterests = AppServices.auth.currentUser?['interests'];
    if (rawInterests is! List) return;

    final profileInterests = rawInterests
        .map((interest) => interest.toString().trim().toLowerCase())
        .where((interest) => interest.isNotEmpty)
        .toSet();
    _interests.addAll(
      _interestOptions.where(
        (option) => profileInterests.contains(option.toLowerCase()),
      ),
    );
  }

  @override
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
    super.dispose();
  }

  void _onSharedLocationChanged() {
    if (!mounted) return;
    setState(() {
      _position = _locationService.currentPosition;
      _locating = _locationService.isLoading;
      if (_locationService.error == null) _error = null;
    });
  }

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

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    final result = await AppServices.trips.createTravelPlan(_input());
    if (!mounted) return;
    if (result['success'] == true) {
      final trip = Map<String, dynamic>.from(result['data']);
      final raw = Map<String, dynamic>.from(trip['plan_data'] as Map? ?? {});
      final next = _ensureMustVisitStops(
        TravelPlan.fromJson(raw, tripId: int.tryParse('${trip['id']}') ?? 0),
      );
      setState(() {
        _plan = next;
        _selectedDayIndex = 0;
        _route = [];
        _generating = false;
      });
      await _buildRoute(next);
    } else {
      setState(() {
        _generating = false;
        _error = '${result['message'] ?? context.l10n.couldNotCreatePlan}';
      });
    }
  }

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

  bool _planContainsPlace(List<TravelDay> days, PlaceMarker place) {
    final id = place.id.trim();
    final title = _placeKey(place.title);
    for (final stop in days.expand((day) => day.stops)) {
      if (id.isNotEmpty && stop.destinationId.trim() == id) return true;
      if (title.isNotEmpty && _placeKey(stop.place) == title) return true;
    }
    return false;
  }

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
    final days = [
      for (var index = 0; index < plan.days.length; index++)
        TravelDay(
          day: plan.days[index].day,
          theme: plan.days[index].theme,
          stops: index == selectedIndex
              ? stops
              : List<TravelStop>.from(plan.days[index].stops),
        ),
    ];
    final updatedPlan = TravelPlan(
      tripId: plan.tripId,
      summary: plan.summary,
      totalEstimatedCost: plan.totalEstimatedCost,
      budgetBreakdown: plan.budgetBreakdown,
      days: days,
      tips: plan.tips,
    );
    setState(() {
      _plan = updatedPlan;
      _route = [];
    });
    unawaited(_buildRoute(updatedPlan));
  }

  void _reset() {
    if (widget.initialTripId != null && Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    
    _routeRequestId++;
    setState(() {
      _dates = null;
      _budget = 30000;
      _days = 3;
      _selectedProvince = null;
      _interests.clear();
      _modes
        ..clear()
        ..add('car');
      _mustVisit.clear();
      _plan = null;
      _selectedDayIndex = 0;
      _route = [];
      _excluded.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => _buildScaffold(context);
}
