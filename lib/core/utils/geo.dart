import 'package:latlong2/latlong.dart';

/// Centralized geographic helpers.
/// Previously duplicated in:
/// - `home_screen.dart:76 _distanceKm`
/// - `all_destinations_screen.dart:77 _distanceKm`
/// - `map_screen.dart` / `plan/plan_view.dart:507 _distanceLabel`
/// - `location_service.dart:30 _smoothPosition`
/// - `travel_diary_automation_service.dart:127 Geolocator.distanceBetween`
/// Mixed APIs `latlong2.Distance` vs `geolocator.Geolocator.distanceBetween`.
/// This file unifies on `latlong2` (no platform channel) and keeps behavior identical.

const _earthDistance = Distance();

/// Returns distance in kilometers between two WGS84 points.
/// Returns null if any coordinate is not finite (mirrors original null-guard).
double? distanceKm({
  required double? fromLat,
  required double? fromLng,
  required double? toLat,
  required double? toLng,
}) {
  if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
    return null;
  }
  if (!fromLat.isFinite || !fromLng.isFinite || !toLat.isFinite || !toLng.isFinite) {
    return null;
  }
  return _earthDistance.as(
    LengthUnit.Kilometer,
    LatLng(fromLat, fromLng),
    LatLng(toLat, toLng),
  );
}

/// Formatted distance label previously duplicated in plan_view / map_view.
/// - null -> null (caller shows hide)
/// - <1 km -> "XXX m"
/// - >=1 km -> "X.X km"
String? formatDistanceKm(double? km) {
  if (km == null || !km.isFinite) return null;
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1)} km';
}

/// Safe parse for `latitude` / `longitude` fields that may be String/num/null
/// Duplicated pattern: `double.tryParse('${json[latitude]}')`
double? tryParseCoord(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
