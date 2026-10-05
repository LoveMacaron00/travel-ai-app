import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/features/diary/domain/travel_diary_entry.dart';
import 'package:myapp/features/destinations/data/destination_service.dart';
import 'package:myapp/features/map/data/location_service.dart';
import 'package:myapp/features/diary/data/travel_diary_service.dart';
import 'package:myapp/core/utils/destination_display.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelDiaryAutomationService {
  TravelDiaryAutomationService({
    required DestinationService destinations,
    required TravelDiaryService diary,
    required Map<String, dynamic>? Function() currentUser,
  }) : _destinationsService = destinations,
       _diary = diary,
       _currentUser = currentUser;

  final DestinationService _destinationsService;
  final TravelDiaryService _diary;
  final Map<String, dynamic>? Function() _currentUser;
  final LocationService _location = LocationService.instance;

  List<_DiaryDestination> _destinations = [];
  String? _activeUserKey;
  bool _started = false;
  bool _evaluating = false;
  DateTime? _lastEvaluation;
  Timer? _heartbeat;
  Future<void>? _startFuture;

  static const _prefKey = 'auto_diary_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  Future<void> toggle(bool enabled) async {
    await setEnabled(enabled);
    if (enabled) {
      await start();
    } else {
      stop();
    }
  }

  Future<void> start() async {
    final user = _currentUser();
    if (user == null) return;
    if (!await isEnabled()) {
      stop();
      return;
    }
    final userKey = '${user['id'] ?? user['email'] ?? ''}';
    if (_started && _activeUserKey == userKey) {
      await _startFuture;
      return;
    }

    stop();
    _activeUserKey = userKey;
    _started = true;
    _location.addListener(_onLocationChanged);
    _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(_evaluatePosition(force: true));
    });
    final initialization = _initialize();
    _startFuture = initialization;
    await initialization;
  }

  Future<void> _initialize() async {
    await _loadDestinations();
    await _evaluatePosition(force: true);
  }

  void stop() {
    if (_started) _location.removeListener(_onLocationChanged);
    _heartbeat?.cancel();
    _heartbeat = null;
    _startFuture = null;
    _started = false;
    _activeUserKey = null;
    _lastEvaluation = null;
  }

  void _onLocationChanged() {
    unawaited(_evaluatePosition());
  }

  Future<void> _evaluatePosition({bool force = false}) async {
    if (!_started || _evaluating || _location.currentPosition == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastEvaluation != null &&
        now.difference(_lastEvaluation!) < const Duration(minutes: 1)) {
      return;
    }
    _evaluating = true;
    _lastEvaluation = now;
    try {
      if (_destinations.isEmpty) await _loadDestinations();
      final nearest = _nearestDestination(_location.currentPosition!);
      if (nearest == null || nearest.distanceMeters > 350) return;
      final entries = await _diary.load();
      TravelDiaryEntry? currentVisit;
      for (final entry in entries) {
        if (entry.destinationId != nearest.id) continue;
        final lastSeen = entry.lastSeenAt ?? entry.date;
        if (now.difference(lastSeen) < const Duration(minutes: 90)) {
          currentVisit = entry;
          break;
        }
      }

      if (currentVisit == null) {
        await _diary.upsert(
          TravelDiaryEntry(
            id: 'gps_${nearest.id}_${now.microsecondsSinceEpoch}',
            date: now,
            lastSeenAt: now,
            title: nearest.title,
            note: '',
            province: nearest.province,
            insight: nearest.insight,
            latitude: _location.currentPosition!.latitude,
            longitude: _location.currentPosition!.longitude,
            destinationId: nearest.id,
            source: 'gps',
          ),
        );
      } else {
        await _diary.upsert(
          currentVisit.copyWith(
            lastSeenAt: now,
            latitude: _location.currentPosition!.latitude,
            longitude: _location.currentPosition!.longitude,
          ),
        );
      }
    } finally {
      _evaluating = false;
    }
  }

  Future<void> _loadDestinations() async {
    final result = await _destinationsService.getDestinations();
    if (result['success'] != true || result['data'] is! List) return;
    _destinations = (result['data'] as List)
        .whereType<Map>()
        .map(
          (raw) => _DiaryDestination.fromJson(Map<String, dynamic>.from(raw)),
        )
        .where((destination) => destination.hasCoordinates)
        .toList();
  }

  _DiaryDestination? _nearestDestination(LatLng position) {
    _DiaryDestination? nearest;
    for (final destination in _destinations) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        destination.latitude,
        destination.longitude,
      );
      if (nearest == null || distance < nearest.distanceMeters) {
        nearest = destination.withDistance(distance);
      }
    }
    return nearest;
  }
}

class _DiaryDestination {
  const _DiaryDestination({
    required this.id,
    required this.title,
    required this.province,
    required this.insight,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.distanceMeters = double.infinity,
  });

  factory _DiaryDestination.fromJson(Map<String, dynamic> json) {
    final rawLocation = json['location'];
    final location = rawLocation is Map
        ? Map<String, dynamic>.from(rawLocation)
        : const <String, dynamic>{};
    return _DiaryDestination(
      id: int.tryParse('${json['id'] ?? ''}') ?? -1,
      title: '${json['name'] ?? json['city'] ?? ''}'.trim(),
      province:
          '${json['provinceValue'] ?? location['province'] ?? json['province'] ?? ''}'
              .trim(),
      insight: stripHtmlText('${json['description'] ?? ''}'),
      imageUrl: '${json['image'] ?? json['image_url'] ?? ''}'.trim(),
      latitude:
          double.tryParse('${json['latitude'] ?? location['latitude']}') ??
          double.nan,
      longitude:
          double.tryParse('${json['longitude'] ?? location['longitude']}') ??
          double.nan,
    );
  }

  final int id;
  final String title;
  final String province;
  final String insight;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  bool get hasCoordinates =>
      id >= 0 && title.isNotEmpty && latitude.isFinite && longitude.isFinite;

  _DiaryDestination withDistance(double distance) => _DiaryDestination(
    id: id,
    title: title,
    province: province,
    insight: insight,
    imageUrl: imageUrl,
    latitude: latitude,
    longitude: longitude,
    distanceMeters: distance,
  );
}
