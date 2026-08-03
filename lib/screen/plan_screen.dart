import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/model/place_marker.dart';
import 'package:myapp/model/travel_plan.dart';
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

/// สร้างและแสดงแผนเที่ยวจาก AI ก่อนส่งจุดแวะไปยังหน้าจอนำทาง
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
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
  String? _error;
  TravelPlan? _plan;
  List<PlaceMarker> _places = [];
  List<ProvinceOption> _provinceOptions = [];
  String? _selectedProvince;
  final Set<String> _interests = {};
  final Set<String> _modes = {'car'};
  final List<PlaceMarker> _mustVisit = [];
  final Set<String> _excluded = {};
  List<LatLng> _route = [];
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
    if (_position == null) _getLocation();
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
          province: '${j['provinceValue'] ?? j['province'] ?? ''}',
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
        _mustVisit.clear();
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
      final next = TravelPlan.fromJson(
        raw,
        tripId: int.tryParse('${trip['id']}') ?? 0,
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

  Future<void> _buildRoute(TravelPlan plan) async {
    final requestId = ++_routeRequestId;
    final day = _selectedDayFor(plan);
    if (day == null || day.stops.length < 2) {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _route = []);
      }
      return;
    }

    final points = <LatLng>[];
    var from = LatLng(day.stops.first.latitude, day.stops.first.longitude);
    points.add(from);
    for (final stop in day.stops.skip(1)) {
      final raw = await AppServices.trips.getRoadRoute(
        fromLat: from.latitude,
        fromLng: from.longitude,
        toLat: stop.latitude,
        toLng: stop.longitude,
        mode: stop.transportMode,
      );
      if (requestId != _routeRequestId) return;
      if (raw.isEmpty) {
        points.addAll([from, LatLng(stop.latitude, stop.longitude)]);
      } else {
        points.addAll(raw.map((p) => LatLng(p[0], p[1])));
      }
      from = LatLng(stop.latitude, stop.longitude);
    }
    if (mounted && requestId == _routeRequestId) {
      setState(() => _route = points);
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

  Future<void> _removeStop(TravelStop stop) async {
    _excluded.add(stop.place);
    _mustVisit.removeWhere((p) => p.title == stop.place);
    await _generate();
  }

  void _reset() {
    _routeRequestId++;
    setState(() {
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
