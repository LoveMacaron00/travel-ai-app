import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/features/map/data/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TravelJourneyService extends ChangeNotifier {
  TravelJourneyService._() {
    _initFromPrefs();
  }

  static final TravelJourneyService instance = TravelJourneyService._();

  static const _prefRecordingKey = 'journey_is_recording';
  static const _prefStartTimeKey = 'journey_start_time';
  static const _prefPointsKey = 'journey_trail_points';
  static const _prefDistanceKey = 'journey_distance_meters';

  bool _isRecording = false;
  DateTime? _startTime;
  final List<LatLng> _trailPoints = [];
  double _totalDistanceMeters = 0.0;
  Timer? _timer;

  bool get isRecording => _isRecording;
  DateTime? get startTime => _startTime;
  List<LatLng> get trailPoints => List.unmodifiable(_trailPoints);
  double get totalDistanceMeters => _totalDistanceMeters;

  Duration get elapsedDuration {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  String get formattedDuration {
    final duration = elapsedDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDistance {
    if (_totalDistanceMeters >= 1000) {
      return '${(_totalDistanceMeters / 1000).toStringAsFixed(2)} กม.';
    }
    return '${_totalDistanceMeters.toStringAsFixed(0)} ม.';
  }

  Future<void> _initFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isRecording = prefs.getBool(_prefRecordingKey) ?? false;
      final startStr = prefs.getString(_prefStartTimeKey);
      if (startStr != null) {
        _startTime = DateTime.tryParse(startStr);
      }
      _totalDistanceMeters = prefs.getDouble(_prefDistanceKey) ?? 0.0;

      final pointsJson = prefs.getString(_prefPointsKey);
      if (pointsJson != null && pointsJson.isNotEmpty) {
        final decoded = jsonDecode(pointsJson);
        if (decoded is List) {
          _trailPoints.clear();
          for (final item in decoded) {
            if (item is List && item.length >= 2) {
              final lat = (item[0] as num).toDouble();
              final lng = (item[1] as num).toDouble();
              _trailPoints.add(LatLng(lat, lng));
            }
          }
        }
      }

      if (_isRecording) {
        _startListening();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefRecordingKey, _isRecording);
      if (_startTime != null) {
        await prefs.setString(_prefStartTimeKey, _startTime!.toIso8601String());
      } else {
        await prefs.remove(_prefStartTimeKey);
      }
      await prefs.setDouble(_prefDistanceKey, _totalDistanceMeters);
      final rawList = _trailPoints.map((p) => [p.latitude, p.longitude]).toList();
      await prefs.setString(_prefPointsKey, jsonEncode(rawList));
    } catch (_) {}
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    _isRecording = true;
    _startTime = DateTime.now();

    final current = LocationService.instance.currentPosition;
    if (current != null) {
      _trailPoints.add(current);
    }

    _startListening();
    await _saveToPrefs();
    notifyListeners();
  }

  void _startListening() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });

    LocationService.instance.removeListener(_onLocationChanged);
    LocationService.instance.addListener(_onLocationChanged);
    unawaited(LocationService.instance.startTracking());
  }

  void _onLocationChanged() {
    if (!_isRecording) return;
    final current = LocationService.instance.currentPosition;
    if (current == null) return;

    if (_trailPoints.isEmpty) {
      _trailPoints.add(current);
      notifyListeners();
      _saveToPrefs();
      return;
    }

    final last = _trailPoints.last;
    final dist = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      current.latitude,
      current.longitude,
    );

    // Only add point if moved more than 4 meters to prevent GPS jitter
    if (dist >= 4.0) {
      _totalDistanceMeters += dist;
      _trailPoints.add(current);
      notifyListeners();
      _saveToPrefs();
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    _timer?.cancel();
    _timer = null;
    LocationService.instance.removeListener(_onLocationChanged);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> clearTrail() async {
    _trailPoints.clear();
    _totalDistanceMeters = 0.0;
    _startTime = null;
    if (_isRecording) {
      _startTime = DateTime.now();
    }
    await _saveToPrefs();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    LocationService.instance.removeListener(_onLocationChanged);
    super.dispose();
  }
}
