import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/model/place_marker.dart';
import 'package:myapp/model/travel_plan.dart';
import 'package:myapp/screen/plan_navigation_screen.dart';
import 'package:myapp/services/api_service.dart';
import 'package:myapp/services/location_service.dart';

const _gold = Color(0xffe9ad0c);
const _ink = Color(0xff292620);
const _canvas = Color(0xfff7f2e8);

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final LocationService _locationService = LocationService.instance;
  final _map = MapController();
  DateTimeRange? _dates;
  double _budget = 30000;
  int _days = 3;
  LatLng? _position;
  bool _locating = false;
  bool _generating = false;
  String? _error;
  TravelPlan? _plan;
  List<PlaceMarker> _places = [];
  final Set<String> _interests = {'Culture'};
  final Set<String> _modes = {'car'};
  final List<PlaceMarker> _mustVisit = [];
  final Set<String> _excluded = {};
  List<LatLng> _route = [];

  static const _interestOptions = [
    'Food',
    'Culture',
    'Beach',
    'Nature',
    'Shopping',
    'Nightlife',
  ];
  static const _modeOptions = <String, IconData>{
    'car': Icons.directions_car,
    'walking': Icons.directions_walk,
  };

  @override
  void initState() {
    super.initState();
    _position = _locationService.currentPosition;
    _locationService.addListener(_onSharedLocationChanged);
    _loadPlaces();
    if (_position == null) _getLocation();
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
    final result = await ApiService.getDestinations();
    if (result['success'] != true || !mounted) return;
    setState(
      () => _places = (result['data'] as List).map((item) {
        final j = Map<String, dynamic>.from(item as Map);
        return PlaceMarker(
          id: '${j['id']}',
          title: '${j['name'] ?? j['city']}',
          description: '${j['description'] ?? ''}',
          latitude: double.tryParse('${j['latitude']}') ?? 0,
          longitude: double.tryParse('${j['longitude']}') ?? 0,
          imageUrl: ApiService.getFullImageUrl('${j['image'] ?? ''}'),
          category: '${j['category'] ?? 'other'}',
        );
      }).toList(),
    );
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
    if (_position == null) {
      await _getLocation();
      if (_position == null) return;
    }
    setState(() {
      _generating = true;
      _error = null;
    });
    final result = await ApiService.createTravelPlan(_input());
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
        _generating = false;
      });
      await _buildRoute(next);
    } else {
      setState(() {
        _generating = false;
        _error = '${result['message'] ?? 'Could not create a plan.'}';
      });
    }
  }

  Future<void> _buildRoute(TravelPlan plan) async {
    if (_position == null || plan.allStops.isEmpty) return;
    final points = <LatLng>[];
    var from = _position!;
    for (final stop in plan.allStops) {
      final raw = await ApiService.getRoadRoute(
        fromLat: from.latitude,
        fromLng: from.longitude,
        toLat: stop.latitude,
        toLng: stop.longitude,
        mode: stop.transportMode,
      );
      if (raw.isEmpty) {
        points.addAll([from, LatLng(stop.latitude, stop.longitude)]);
      } else {
        points.addAll(raw.map((p) => LatLng(p[0], p[1])));
      }
      from = LatLng(stop.latitude, stop.longitude);
    }
    if (mounted) setState(() => _route = points);
  }

  Future<void> _removeStop(TravelStop stop) async {
    _excluded.add(stop.place);
    _mustVisit.removeWhere((p) => p.title == stop.place);
    await _generate();
  }

  void _reset() => setState(() {
    _plan = null;
    _route = [];
    _excluded.clear();
    _error = null;
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _plan == null ? _buildForm() : _buildResult(_plan!),
      ),
    ),
  );

  Widget _header(String eyebrow, String title, {VoidCallback? back}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    child: Row(
      children: [
        if (back != null) _roundIcon(Icons.arrow_back, back),
        if (back != null) const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: back == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xff8c7b60),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _reset,
          child: const Text(
            'Reset',
            style: TextStyle(color: _gold, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _buildForm() => SingleChildScrollView(
    key: const ValueKey('form'),
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      children: [
        _header('AI PLAN TRAVEL', 'Build your trip'),
        _hero(),
        _section(
          number: 1,
          title: 'Set the basics',
          subtitle: 'Your location is the starting point.',
          child: Column(
            children: [
              _locationTile(),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDates,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: _inputDecoration(
                    'Travel dates',
                    Icons.calendar_today_outlined,
                  ),
                  child: Text(
                    _dates == null
                        ? 'Choose dates'
                        : '${_date(_dates!.start)} – ${_date(_dates!.end)}  ·  $_days days',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimated budget',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '฿${_money(_budget)}',
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _budget,
                min: 3000,
                max: 150000,
                divisions: 49,
                activeColor: _gold,
                onChanged: (v) => setState(() => _budget = v),
              ),
            ],
          ),
        ),
        _section(
          number: 2,
          title: 'What do you enjoy?',
          subtitle: 'AI will choose places that fit your budget.',
          child: _chips(_interestOptions, _interests),
        ),
        _section(
          number: 3,
          title: 'How can you travel?',
          subtitle: 'Long trips are split into road and transport segments.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _modeOptions.entries
                .map(
                  (e) => FilterChip(
                    avatar: Icon(e.value, size: 17),
                    label: Text(_modeLabel(e.key)),
                    selected: _modes.contains(e.key),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _modes.add(e.key);
                      } else if (_modes.length > 1) {
                        _modes.remove(e.key);
                      }
                    }),
                  ),
                )
                .toList(),
          ),
        ),
        _section(
          number: 4,
          title: 'Must-visit places',
          subtitle: 'Optional — AI will include your selections.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_mustVisit.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _mustVisit
                      .map(
                        (p) => InputChip(
                          label: Text(p.title),
                          onDeleted: () => setState(() => _mustVisit.remove(p)),
                        ),
                      )
                      .toList(),
                ),
              OutlinedButton.icon(
                onPressed: _showPlacePicker,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add a place'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _generating ? 'Designing your trip…' : 'Create my travel plan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _hero() {
    final image = _places
        .where((p) => p.imageUrl.isNotEmpty)
        .firstOrNull
        ?.imageUrl;
    return Container(
      height: 210,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: _ink,
        image: image == null
            ? null
            : DecorationImage(
                image: NetworkImage(image),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: .36),
                  BlendMode.darken,
                ),
              ),
      ),
      padding: const EdgeInsets.all(22),
      alignment: Alignment.bottomLeft,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THAILAND · NEAR YOU',
            style: TextStyle(
              color: Color(0xffffd65a),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Let AI find the right\nplaces for your budget.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(TravelPlan plan) => CustomScrollView(
    key: const ValueKey('result'),
    slivers: [
      SliverToBoxAdapter(
        child: _header('AI GENERATED PLAN', 'Your route', back: _reset),
      ),
      SliverToBoxAdapter(child: _planMap(plan)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              _stat('${plan.allStops.length}', 'places'),
              _stat('${plan.days.length}', 'days'),
              _stat('฿${_money(plan.totalEstimatedCost)}', 'estimated'),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recommended itinerary',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                plan.summary,
                style: const TextStyle(color: Colors.black54, height: 1.45),
              ),
            ],
          ),
        ),
      ),
      ...plan.days.expand(
        (day) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'DAY ${day.day}  ·  ${day.theme.toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xff9a6b00),
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: day.stops.length,
            itemBuilder: (_, i) => _stopTile(day.stops[i], i + 1),
          ),
        ],
      ),
      SliverToBoxAdapter(child: _costSummary(plan)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: OutlinedButton.icon(
            onPressed: _showPlacePicker,
            icon: const Icon(Icons.add),
            label: const Text('Add another place'),
          ),
        ),
      ),
    ],
  );

  Widget _planMap(TravelPlan plan) => Container(
    height: 250,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
    child: FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter:
            _position ??
            (plan.allStops.isEmpty
                ? const LatLng(13.7563, 100.5018)
                : LatLng(
                    plan.allStops.first.latitude,
                    plan.allStops.first.longitude,
                  )),
        initialZoom: 11,
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.mapTileUrl,
          userAgentPackageName: 'com.example.myapp',
        ),
        if (_route.isNotEmpty)
          PolylineLayer(
            polylines: [Polyline(points: _route, color: _gold, strokeWidth: 5)],
          ),
        MarkerLayer(
          markers: [
            if (_position != null)
              Marker(
                point: _position!,
                width: 36,
                height: 36,
                child: const Icon(Icons.my_location, color: Colors.blue),
              ),
            ...plan.allStops.indexed.map(
              (e) => Marker(
                point: LatLng(e.$2.latitude, e.$2.longitude),
                width: 132,
                height: 88,
                child: _buildPlanStopMarker(e.$2, e.$1 + 1),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _stopTile(TravelStop stop, int number) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showStopDetails(stop, number),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 5, 16, 7),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xffeadcc2)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: _gold,
                  foregroundColor: Colors.white,
                  child: Text('$number'),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: stop.imageUrl.isEmpty
                      ? Container(
                          width: 76,
                          height: 76,
                          color: const Color(0xffeee7da),
                          child: const Icon(Icons.landscape),
                        )
                      : Image.network(
                          ApiService.getFullImageUrl(stop.imageUrl),
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 76,
                            height: 76,
                            color: const Color(0xffeee7da),
                            child: const Icon(Icons.landscape),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.place,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${stop.arrivalTime} · ${stop.durationMinutes} min',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        stop.activity,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'remove') _removeStop(stop);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from plan'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stop.segments.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: stop.segments
                      .map(
                        (segment) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xfffff3cc),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_modeLabel(segment.mode)} · ${segment.estimatedMinutes} min · ฿${_money(segment.estimatedCost)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff7a5800),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Row(
              children: [
                _price(Icons.confirmation_number_outlined, stop.entryCost),
                const SizedBox(width: 8),
                _price(
                  _modeOptions[stop.transportMode] ?? Icons.route,
                  stop.transportCost,
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanNavigationScreen(destination: stop),
                    ),
                  ),
                  icon: const Icon(Icons.navigation, size: 17),
                  label: const Text('Navigate'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _showStopDetails(TravelStop stop, int number) {
    final destinationId = int.tryParse(stop.destinationId);
    final detailFuture = destinationId == null
        ? null
        : ApiService.getDestinationDetails(destinationId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .78,
        maxChildSize: .94,
        minChildSize: .5,
        builder: (context, controller) => FutureBuilder<Map<String, dynamic>>(
          future: detailFuture,
          builder: (context, snapshot) {
            final detail = snapshot.data?['success'] == true
                ? Map<String, dynamic>.from(snapshot.data!['data'])
                : <String, dynamic>{};
            final gallery = _detailImages(detail, stop.imageUrl);
            final description = _plainText(
              '${detail['description'] ?? stop.tip}',
            );
            final admissionDetails = _admissionDetails(detail);
            return Container(
              decoration: const BoxDecoration(
                color: _canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 220,
                    child: gallery.isEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              color: const Color(0xffeee7da),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.landscape, size: 50),
                          )
                        : PageView.builder(
                            itemCount: gallery.length,
                            itemBuilder: (_, index) => ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                gallery[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xffeee7da),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '$number. ${stop.place}',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stop.arrivalTime} · ${stop.durationMinutes} min · ${_modeLabel(stop.transportMode)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stop.activity,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Estimated cost for this stop',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _detailCostRow(
                    Icons.confirmation_number_outlined,
                    'Admission',
                    stop.entryCost,
                  ),
                  if (admissionDetails.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff4d2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Admission details from TAT',
                            style: TextStyle(
                              color: Color(0xff876100),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          ...admissionDetails.map(
                            (detail) => Text(
                              detail,
                              style: const TextStyle(
                                color: Color(0xff684d0a),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _detailCostRow(
                    Icons.restaurant_outlined,
                    'Food',
                    stop.foodCost,
                  ),
                  _detailCostRow(
                    _modeOptions[stop.transportMode] ?? Icons.route,
                    'Transport',
                    stop.transportCost,
                  ),
                  const Divider(height: 28),
                  _detailCostRow(
                    Icons.account_balance_wallet_outlined,
                    'Stop total',
                    stop.entryCost + stop.foodCost + stop.transportCost,
                    emphasis: true,
                  ),
                  if (stop.segments.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'Journey details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...stop.segments.map(
                      (segment) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xffffe9a6),
                          foregroundColor: const Color(0xff856000),
                          child: Icon(
                            _modeOptions[segment.mode] ?? Icons.route,
                          ),
                        ),
                        title: Text(
                          '${_modeLabel(segment.mode)} · ${segment.estimatedMinutes} min',
                        ),
                        subtitle: Text(
                          [
                            segment.from,
                            segment.to,
                          ].where((v) => v.isNotEmpty).join(' → '),
                        ),
                        trailing: Text(
                          '฿${_money(segment.estimatedCost)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _gold),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlanNavigationScreen(destination: stop),
                        ),
                      ),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate to this place'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<String> _detailImages(Map<String, dynamic> detail, String fallback) {
    final urls = <String>[
      if (fallback.isNotEmpty) ApiService.getFullImageUrl(fallback),
    ];
    if (detail['image_url'] != null) {
      urls.add(ApiService.getFullImageUrl('${detail['image_url']}'));
    }
    if (detail['images'] is List) {
      for (final image in detail['images'] as List) {
        if (image is Map && image['image_url'] != null) {
          urls.add(ApiService.getFullImageUrl('${image['image_url']}'));
        }
      }
    }
    return urls.where((url) => url.isNotEmpty).toSet().toList();
  }

  List<String> _admissionDetails(Map<String, dynamic> detail) {
    final savedFee = detail['admission_fee'];
    if (savedFee is Map) {
      return _formatAdmissionFee(savedFee);
    }
    final raw = detail['tat_raw'];
    if (raw is! Map) return const [];
    final information = raw['information'];
    final fee = information is Map && information['fee'] is Map
        ? information['fee'] as Map
        : raw['fee'] is Map
        ? raw['fee'] as Map
        : null;
    if (fee == null) return const [];
    return _formatAdmissionFee(fee);
  }

  List<String> _formatAdmissionFee(Map fee) {
    final lines = <String>[];
    if (fee['thaiAdult'] != null) {
      lines.add(
        'Adult: ฿${_money(double.tryParse('${fee['thaiAdult']}') ?? 0)}',
      );
    }
    if (fee['thaiChild'] != null) {
      lines.add(
        'Child: ฿${_money(double.tryParse('${fee['thaiChild']}') ?? 0)}',
      );
    }
    if (fee['foreignerAdult'] != null) {
      lines.add(
        'Foreigner adult: ฿${_money(double.tryParse('${fee['foreignerAdult']}') ?? 0)}',
      );
    }
    if (fee['foreignerChild'] != null) {
      lines.add(
        'Foreigner child: ฿${_money(double.tryParse('${fee['foreignerChild']}') ?? 0)}',
      );
    }
    final detailText = _plainText('${fee['detail'] ?? ''}');
    if (detailText.isNotEmpty) lines.add(detailText);
    return lines;
  }

  Widget _detailCostRow(
    IconData icon,
    String label,
    double cost, {
    bool emphasis = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 18, color: emphasis ? _gold : Colors.black45),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: emphasis ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          '฿${_money(cost)}',
          style: TextStyle(
            fontWeight: emphasis ? FontWeight.w900 : FontWeight.w700,
            color: emphasis ? _gold : _ink,
          ),
        ),
      ],
    ),
  );

  String _plainText(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Widget _buildPlanStopMarker(TravelStop stop, int number) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _gold, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.attractions, color: _gold, size: 24),
              Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 128),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _gold),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '$number. ${stop.place}',
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

  Widget _costSummary(TravelPlan plan) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffeadcc2)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Estimated trip cost',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '฿${_money(plan.totalEstimatedCost)}',
              style: const TextStyle(
                color: _gold,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const Divider(height: 26),
        ...plan.budgetBreakdown.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  _title(e.key),
                  style: const TextStyle(color: Colors.black54),
                ),
                const Spacer(),
                Text(
                  '฿${_money(e.value)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Estimates may change with availability, season, and traffic.',
          style: TextStyle(color: Colors.black38, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _section({
    required int number,
    required String title,
    required String subtitle,
    required Widget child,
  }) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffeadcc2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _gold,
              foregroundColor: Colors.white,
              child: Text('$number'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _locationTile() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xfffff6d7),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        const Icon(Icons.my_location, color: _gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current GPS location',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                _position == null
                    ? (_locating
                          ? 'Finding your location…'
                          : 'Location unavailable')
                    : '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(onPressed: _getLocation, icon: const Icon(Icons.refresh)),
      ],
    ),
  );

  Widget _chips(List<String> options, Set<String> selected) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options
        .map(
          (v) => FilterChip(
            label: Text(v),
            selected: selected.contains(v),
            selectedColor: const Color(0xffffe7a0),
            checkmarkColor: const Color(0xff986b00),
            onSelected: (on) => setState(() {
              if (on) {
                selected.add(v);
              } else {
                selected.remove(v);
              }
            }),
          ),
        )
        .toList(),
  );

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dates,
    );
    if (picked != null) {
      setState(() {
        _dates = picked;
        _days = picked.duration.inDays + 1;
      });
    }
  }

  void _showPlacePicker() {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          final filtered = _places
              .where(
                (p) =>
                    query.isEmpty ||
                    p.title.toLowerCase().contains(query.toLowerCase()),
              )
              .take(30)
              .toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .78,
            maxChildSize: .92,
            builder: (_, controller) => Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text(
                    'Add a place',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (v) => setSheet(() => query = v),
                    decoration: _inputDecoration(
                      'Search places in Thailand',
                      Icons.search,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: p.imageUrl.isEmpty
                              ? const SizedBox(
                                  width: 52,
                                  child: Icon(Icons.place),
                                )
                              : Image.network(
                                  p.imageUrl,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        title: Text(
                          p.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          p.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.add_circle, color: _gold),
                        onTap: () async {
                          if (!_mustVisit.any((x) => x.id == p.id)) {
                            _mustVisit.add(p);
                          }
                          Navigator.pop(sheetContext);
                          if (_plan != null) {
                            await _generate();
                          } else if (mounted) {
                            setState(() {});
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _gold),
        filled: true,
        fillColor: const Color(0xfffbf8f1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xffe6dbc8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xffe6dbc8)),
        ),
      );
  Widget _roundIcon(IconData icon, VoidCallback onTap) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: IconButton(onPressed: onTap, icon: Icon(icon)),
  );
  Widget _stat(String value, String label) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.black45, fontSize: 11),
          ),
        ],
      ),
    ),
  );
  Widget _price(IconData icon, double value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xfff4f0e8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15, color: Colors.black45),
        const SizedBox(width: 5),
        Text('฿${_money(value)}', style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _money(num n) => n.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  String _modeLabel(String v) => '${v[0].toUpperCase()}${v.substring(1)}';
  String _title(String v) => v
      .split(RegExp(r'[_ ]'))
      .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
      .join(' ');
}
