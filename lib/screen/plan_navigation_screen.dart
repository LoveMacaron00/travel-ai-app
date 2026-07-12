import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/model/travel_plan.dart';
import 'package:myapp/services/api_service.dart';

class PlanNavigationScreen extends StatefulWidget {
  final TravelStop destination;
  const PlanNavigationScreen({super.key, required this.destination});
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

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _message('Turn on location services to navigate.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _message('Location permission is required for navigation.');
      return;
    }
    final first = await Geolocator.getCurrentPosition();
    await _updatePosition(first, refreshRoute: true);
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((p) => _updatePosition(p));
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
    });
    _map.move(next, 16);
    if (refreshRoute || _route.isEmpty) {
      final raw = await ApiService.getRoadRoute(
        fromLat: p.latitude,
        fromLng: p.longitude,
        toLat: widget.destination.latitude,
        toLng: widget.destination.longitude,
        mode: widget.destination.transportMode,
      );
      if (mounted) {
        setState(() => _route = raw.map((e) => LatLng(e[0], e[1])).toList());
      }
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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.myapp',
              ),
              if (_route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      strokeWidth: 6,
                      color: const Color(0xffe8ad10),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 12),
                      ],
                    ),
                    child: Text(
                      '${_remainingKm.toStringAsFixed(1)} km left',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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
                        const Text(
                          'Navigate to',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xffe9ad0c), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.attractions,
            color: Color(0xffe9ad0c),
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 126),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xffe9ad0c)),
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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
