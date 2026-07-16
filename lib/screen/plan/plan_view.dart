part of '../plan_screen.dart';

// Form, result list และ map preview ของแผน
extension _PlanMainView on _PlanScreenState {
  Widget _buildScaffold(BuildContext context) => Scaffold(
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
                onChanged: (v) => _updateState(() => _budget = v),
              ),
            ],
          ),
        ),
        _section(
          number: 2,
          title: 'What do you enjoy?',
          subtitle: 'AI will choose places that fit your budget.',
          child: _chips(_PlanScreenState._interestOptions, _interests),
        ),
        _section(
          number: 3,
          title: 'How can you travel?',
          subtitle: 'Long trips are split into road and transport segments.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _PlanScreenState._modeOptions.entries
                .map(
                  (e) => FilterChip(
                    avatar: Icon(e.value, size: 17),
                    label: Text(_modeLabel(e.key)),
                    selected: _modes.contains(e.key),
                    onSelected: (v) => _updateState(() {
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
                          onDeleted: () =>
                              _updateState(() => _mustVisit.remove(p)),
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
                image: mediaImageProvider(image),
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
                          AppServices.media.fullUrl(stop.imageUrl),
                          headers: AppServices.media.headersFor(
                            AppServices.media.fullUrl(stop.imageUrl),
                          ),
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
                  _PlanScreenState._modeOptions[stop.transportMode] ??
                      Icons.route,
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
}
