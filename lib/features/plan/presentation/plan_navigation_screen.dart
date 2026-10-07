import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/features/diary/domain/travel_diary_entry.dart';
import 'package:myapp/features/plan/domain/travel_plan.dart';
import 'package:myapp/core/di/app_services.dart';
import 'package:myapp/core/widgets/rest_stop_icon.dart';
import 'package:myapp/core/widgets/route_style.dart';

class PlanNavigationScreen extends StatefulWidget {
  final TravelStop destination;

  /// เรียกครั้งเดียวเมื่อ GPS ถึงที่หมายครั้งแรก — ให้หน้าแผนมาร์กสถานะเช็คอิน
  final VoidCallback? onArrived;

  const PlanNavigationScreen({
    super.key,
    required this.destination,
    this.onArrived,
  });
  @override
  State<PlanNavigationScreen> createState() => _PlanNavigationScreenState();
}

class _PlanNavigationScreenState extends State<PlanNavigationScreen> {
  final MapController _map = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _position;
  List<LatLng> _route = [];
  double _remainingKm = 0;
  bool _loading = true;

  /// รัศมีถือว่าถึงที่หมาย (กม.) — ตรงกับความคลาดเคลื่อน GPS + พิกัดทางเข้า
  static const _arrivalRadiusKm = 0.15;

  bool _arrived = false;
  bool _arrivalRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message(l10n.turnOnLocationServices);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _message(l10n.locationPermissionRequired);
        return;
      }
      final first = await Geolocator.getCurrentPosition();
      await _updatePosition(first, refreshRoute: true);
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 15,
            ),
          ).listen(
            (position) => _updatePosition(position),
            onError: (_) => _message(l10n.locationPermissionRequired),
          );
    } catch (_) {
      _message(l10n.locationPermissionRequired);
    }
  }

  Future<void> _updatePosition(Position p, {bool refreshRoute = false}) async {
    final next = LatLng(p.latitude, p.longitude);
    final km =
        Geolocator.distanceBetween(
          p.latitude,
          p.longitude,
          widget.destination.latitude,
          widget.destination.longitude,
        ) /
        1000;
    if (!mounted) return;
    setState(() {
      _position = next;
      _remainingKm = km;
      _loading = false;
      // เข้ารัศมีที่หมายครั้งแรก — มาร์กถึง + บันทึกเช็คอิน (ครั้งเดียวต่อรอบนำทาง)
      if (!_arrived && km <= _arrivalRadiusKm) _arrived = true;
    });
    if (_arrived && !_arrivalRecorded) {
      _arrivalRecorded = true;
      widget.onArrived?.call();
      unawaited(_recordArrivalCheckIn(p));
    }
    _map.move(next, 16);
    if (refreshRoute || _route.isEmpty) {
      final mode = widget.destination.transportMode.toLowerCase();
      final roadRoute = usesRoadRoute(mode);
      final raw = roadRoute
          ? await AppServices.trips.getRoadRoute(
              fromLat: p.latitude,
              fromLng: p.longitude,
              toLat: widget.destination.latitude,
              toLng: widget.destination.longitude,
              mode: mode,
            )
          : const <List<double>>[];
      if (mounted) {
        setState(
          () => _route = raw.isEmpty
              ? [
                  next,
                  LatLng(
                    widget.destination.latitude,
                    widget.destination.longitude,
                  ),
                ]
              : raw.map((e) => LatLng(e[0], e[1])).toList(),
        );
        if (!roadRoute) {
          _map.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(_route),
              padding: const EdgeInsets.all(56),
            ),
          );
        }
      }
    }
  }

  /// บันทึกเช็คอินตอนถึงที่หมาย — กติกาเดียวกับ auto-diary:
  /// มี entry ของที่เดียวกันใน 90 นาทีหลัง → อัปเดต lastSeen แทนสร้างซ้ำ
  Future<void> _recordArrivalCheckIn(Position p) async {
    try {
      final now = DateTime.now();
      final stop = widget.destination;
      final stopDestId = int.tryParse(stop.destinationId);
      final entries = await AppServices.diary.load();
      TravelDiaryEntry? recent;
      for (final entry in entries) {
        final samePlace =
            (stopDestId != null && entry.destinationId == stopDestId) ||
            (entry.title.trim().isNotEmpty &&
                entry.title.trim().toLowerCase() ==
                    stop.place.trim().toLowerCase());
        if (!samePlace) continue;
        final lastSeen = entry.lastSeenAt ?? entry.date;
        if (now.difference(lastSeen) < const Duration(minutes: 90)) {
          recent = entry;
          break;
        }
      }
      if (recent != null) {
        await AppServices.diary.upsert(
          recent.copyWith(
            lastSeenAt: now,
            latitude: p.latitude,
            longitude: p.longitude,
          ),
        );
      } else {
        await AppServices.diary.upsert(
          TravelDiaryEntry(
            id: 'gps_nav_${now.microsecondsSinceEpoch}',
            date: now,
            lastSeenAt: now,
            title: stop.place,
            note: '',
            province: stop.province,
            latitude: p.latitude,
            longitude: p.longitude,
            destinationId: stopDestId,
            source: 'gps',
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.checkInSuccess)));
      }
    } catch (_) {
      // บันทึกเช็คอินพังเงียบ — สถานะถึงที่หมายบนจอยังโชว์ปกติ
    }
  }

  void _message(String text) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(
      widget.destination.latitude,
      widget.destination.longitude,
    );
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: destination, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: AppConfig.mapTileUrl,
                userAgentPackageName: 'com.example.myapp',
              ),
              if (_route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      strokeWidth: 6,
                      color: routeLineColor(
                        widget.destination.transportMode,
                        fallback: const Color(0xffe8ad10),
                      ),
                      pattern: usesRoadRoute(widget.destination.transportMode)
                          ? const StrokePattern.solid()
                          : StrokePattern.dashed(segments: const [12, 8]),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: destination,
                    width: 130,
                    height: 88,
                    child: _buildDestinationMarker(),
                  ),
                  if (_position != null)
                    Marker(
                      point: _position!,
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: .18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.navigation, color: Colors.blue),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: _arrived ? const Color(0xff1e7a4c) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 12),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_arrived) ...[
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _arrived
                              ? context.l10n.arrivedAtDestination
                              : context.l10n.kilometersLeft(
                                  _remainingKm.toStringAsFixed(1),
                                ),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _arrived ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xff25231f),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.navigation_rounded,
                    color: Color(0xffffc21c),
                    size: 34,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.navigateTo,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          widget.destination.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // ถึงที่หมายแล้ว — โชว์สถานะเช็คอินใต้ชื่อสถานที่
                        if (_arrived) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xff4caf50),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.l10n.checkedIn,
                                style: const TextStyle(
                                  color: Color(0xff81c784),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xffffc21c),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    elevation: 3,
    child: IconButton(onPressed: onTap, icon: Icon(icon)),
  );

  Widget _buildDestinationMarker() {
    // สี/ไอคอนตามประเภทจุดให้ตรงกับหน้าผลลัพธ์ — ปั๊ม/จุดพักไม่ควรโชว์เป็นหมุดสถานที่ท่องเที่ยว
    // ทอง=ที่เที่ยว / ม่วง=ที่พักค้างคืน / ฟ้า=จุดพักรายทาง (รวมปั๊มน้ำมัน)
    final stop = widget.destination;
    final typeColor = stop.isOvernight
        ? const Color(0xff7b2cbf)
        : stop.isRestStop
        ? const Color(0xff2d7dd2)
        : const Color(0xffe9ad0c);
    final icon = stop.isOvernight
        ? Icons.hotel
        : stop.isRestStop
        ? restStopIcon(stop.restType)
        : Icons.attractions;
    final labelBg = stop.isOvernight
        ? const Color(0xfff1e8fb)
        : stop.isRestStop
        ? const Color(0xffe8f1fb)
        : Colors.white;
    final labelTextColor = stop.isOvernight
        ? const Color(0xff5a1f8f)
        : stop.isRestStop
        ? const Color(0xff1f5f9f)
        : Colors.black87;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: typeColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: typeColor, size: 24),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 126),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: typeColor),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.destination.place,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: labelTextColor,
            ),
          ),
        ),
      ],
    );
  }
}
