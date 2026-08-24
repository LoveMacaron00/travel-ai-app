import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/model/travel_diary_entry.dart';
import 'package:myapp/screen/travel_diary_screen.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/services/travel_diary_service.dart';
import 'package:myapp/widgets/media_image.dart';

const _footprintGold = Color(0xfff4b400);
const _footprintCanvas = Color(0xfff8f9fa);

class TravelFootprintScreen extends StatefulWidget {
  const TravelFootprintScreen({super.key});

  @override
  State<TravelFootprintScreen> createState() => _TravelFootprintScreenState();
}

class _TravelFootprintScreenState extends State<TravelFootprintScreen> {
  late final TravelDiaryService _diary;
  List<TravelDiaryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _diary = AppServices.diary;
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    await AppServices.diaryAutomation.start();
    final entries = await _diary.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  List<String> get _visitedProvinces {
    final provinces = <String, String>{};
    for (final entry in _entries) {
      final province = entry.province.trim();
      if (province.isNotEmpty) {
        provinces.putIfAbsent(province.toLowerCase(), () => province);
      }
    }
    final values = provinces.values.toList()..sort();
    return values;
  }

  List<TravelDiaryEntry> get _locatedEntries =>
      _entries.where((entry) => entry.hasLocation).toList();

  Future<void> _openDiary() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TravelDiaryScreen()),
    );
    await _loadEntries();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _footprintCanvas,
    appBar: AppBar(
      backgroundColor: _footprintCanvas,
      surfaceTintColor: Colors.transparent,
      title: Text(
        context.l10n.travelFootprint,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      centerTitle: true,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _footprintGold))
        : RefreshIndicator(
            color: _footprintGold,
            onRefresh: _loadEntries,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                _summaryCard(),
                const SizedBox(height: 16),
                _mapCard(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      color: _footprintGold,
                      size: 21,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.visitedProvinces,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_visitedProvinces.isEmpty)
                  _emptyProvinces()
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _visitedProvinces
                        .map(
                          (province) => Chip(
                            avatar: const Icon(
                              Icons.check_circle,
                              color: Color(0xffa67400),
                              size: 18,
                            ),
                            label: Text(province),
                            backgroundColor: const Color(0xffffe7a0),
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Icon(Icons.timeline, color: _footprintGold, size: 21),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.timeline,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _footprintGold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_entries.isEmpty)
                  _emptyProvinces()
                else
                  ..._entries.map(_timelineCard),
              ],
            ),
          ),
   );

  String? get _homeProvinceKey {
    final counts = <String, int>{};
    for (final entry in _entries) {
      final key = entry.province.trim().toLowerCase();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _timelineTitle(TravelDiaryEntry entry) {
    final title = entry.title.trim();
    if (title.isNotEmpty) return title;
    final province = entry.province.trim();
    if (province.isNotEmpty) return province;
    return entry.note.trim().isEmpty ? '—' : entry.note.trim();
  }

  String _visitedLabel(TravelDiaryEntry entry) {
    if (entry.province.trim().toLowerCase() == _homeProvinceKey) {
      return context.l10n.homeBase;
    }
    final elapsed = DateTime.now().difference(entry.date);
    if (elapsed.inHours < 1) return context.l10n.visitedToday;
    if (elapsed.inHours < 24) {
      return context.l10n.visitedHoursAgo(elapsed.inHours);
    }
    if (elapsed.inDays < 30) return context.l10n.visitedDaysAgo(elapsed.inDays);
    final months = elapsed.inDays ~/ 30;
    return context.l10n.visitedMonthsAgo(months < 1 ? 1 : months);
  }

  Widget _timelineThumb(TravelDiaryEntry entry) {
    final url = entry.imageUrls.isNotEmpty ? entry.imageUrls.first : '';
    Widget fallback() => Container(
      width: 72,
      height: 72,
      color: const Color(0xfffff2cc),
      child: const Icon(Icons.place_outlined, color: _footprintGold),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: url.isEmpty
            ? fallback()
            : mediaNetworkImage(
                url,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback(),
              ),
      ),
    );
  }

  Widget _timelineCard(TravelDiaryEntry entry) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openDiary,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffeadfca)),
          ),
          child: Row(
            children: [
              _timelineThumb(entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _timelineTitle(entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _visitedLabel(entry),
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xffffcf3f), Color(0xfff4b400)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.public, size: 30, color: _footprintGold),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.visitedProvinceCount(_visitedProvinces.length),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.l10n.memoriesCount(_entries.length),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _mapCard() {
    final locatedEntries = _locatedEntries;
    final center = locatedEntries.isEmpty
        ? const LatLng(13.2, 101.0)
        : LatLng(
            locatedEntries
                    .map((entry) => entry.latitude!)
                    .reduce((a, b) => a + b) /
                locatedEntries.length,
            locatedEntries
                    .map((entry) => entry.longitude!)
                    .reduce((a, b) => a + b) /
                locatedEntries.length,
          );

    return Container(
      height: 310,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xfffff7dc),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffeadfca)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: locatedEntries.isEmpty ? 5.3 : 7,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.mapTileUrl,
                userAgentPackageName: 'com.example.myapp',
              ),
              if (locatedEntries.isNotEmpty)
                CircleLayer(
                  circles: locatedEntries
                      .map(
                        (entry) => CircleMarker(
                          point: LatLng(entry.latitude!, entry.longitude!),
                          radius: 34,
                          color: _footprintGold.withValues(alpha: 0.22),
                          borderColor: _footprintGold,
                          borderStrokeWidth: 2,
                        ),
                      )
                      .toList(),
                ),
              if (locatedEntries.isNotEmpty)
                MarkerLayer(
                  markers: locatedEntries
                      .map(
                        (entry) => Marker(
                          point: LatLng(entry.latitude!, entry.longitude!),
                          width: 38,
                          height: 38,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _footprintGold,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 7,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.flag,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
          if (locatedEntries.isEmpty)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.72),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_location_alt_outlined,
                          size: 40,
                          color: _footprintGold,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.l10n.noFootprint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.noFootprintDescription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyProvinces() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffeadfca)),
    ),
    child: Text(
      context.l10n.noFootprintDescription,
      style: const TextStyle(color: Colors.black54, height: 1.4),
    ),
  );
}
