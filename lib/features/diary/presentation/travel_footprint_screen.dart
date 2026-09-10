import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/features/diary/domain/travel_diary_entry.dart';
import 'package:myapp/features/diary/presentation/travel_diary_screen.dart';
import 'package:myapp/core/di/app_services.dart';
import 'package:myapp/features/diary/data/travel_diary_automation_service.dart';
import 'package:myapp/features/diary/data/travel_diary_service.dart';
import 'package:myapp/core/widgets/media_image.dart';

const _footprintGold = Color(0xfff4b400);
const _footprintCanvas = Color(0xfff8f9fa);
const _footprintBorder = Color(0xffeadfca);
const _footprintChipBg = Color(0xffffe7a0);
const _footprintCardBg = Color(0xfffff7dc);

const _defaultMapCenter = LatLng(13.2, 101.0);
const _defaultMapZoom = 7.0;
const _emptyMapZoom = 5.3;
const _focusZoom = 14.0;

class TravelFootprintScreen extends StatefulWidget {
  const TravelFootprintScreen({super.key, this.onBack, this.onOpenDiary});

  final VoidCallback? onBack;
  final VoidCallback? onOpenDiary;

  @override
  State<TravelFootprintScreen> createState() => _TravelFootprintScreenState();
}

class _TravelFootprintScreenState extends State<TravelFootprintScreen> {
  late final TravelDiaryService _diary;
  final _mapController = MapController();
  final _scrollController = ScrollController();
  final _mapKey = GlobalKey();
  List<TravelDiaryEntry> _entries = [];
  bool _loading = true;
  String? _selectedEntryId;

  @override
  void initState() {
    super.initState();
    _diary = AppServices.diary;
    _loadEntries();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    if (await TravelDiaryAutomationService.isEnabled()) {
      await AppServices.diaryAutomation.start();
    }
    final entries = await _diary.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
      // ถ้า entry ที่เลือกไว้ถูกลบไป ให้ล้างฟิลเตอร์
      if (_selectedEntryId != null &&
          !_entries.any((e) => e.id == _selectedEntryId)) {
        _selectedEntryId = null;
      }
    });
  }

  List<TravelDiaryEntry> get _filteredEntries {
    if (_selectedEntryId == null) return _entries;
    final filtered = _entries.where((e) => e.id == _selectedEntryId).toList();
    // ถ้าฟิลเตอร์แล้วไม่เจอ (ข้อมูลเปลี่ยน) ให้กลับมาแสดงทั้งหมด
    return filtered.isEmpty ? _entries : filtered;
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
    if (widget.onOpenDiary != null) {
      widget.onOpenDiary!.call();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TravelDiaryScreen()),
    );
    await _loadEntries();
  }

  /// แตะการ์ด timeline → zoom แผนที่ไปที่ mark (ไม่เปิด diary)
  /// แตะซ้ำตอนเลือกอยู่แล้ว หรือ entry ไม่มีพิกัด → เปิด diary แทน
  void _focusEntry(TravelDiaryEntry entry) {
    if (entry.id == _selectedEntryId || !entry.hasLocation) {
      _openDiary();
      return;
    }
    setState(() => _selectedEntryId = entry.id);
    _mapController.move(LatLng(entry.latitude!, entry.longitude!), _focusZoom);
    final mapContext = _mapKey.currentContext;
    if (mapContext != null) {
      Scrollable.ensureVisible(
        mapContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  /// แตะ mark บนแผนที่ → เลือก + จัดกึ่งกลาง mark (คง zoom เดิม)
  void _focusMarker(TravelDiaryEntry entry) {
    setState(() => _selectedEntryId = entry.id);
    _mapController.move(
      LatLng(entry.latitude!, entry.longitude!),
      _mapController.camera.zoom,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _footprintCanvas,
    appBar: AppBar(
      backgroundColor: _footprintCanvas,
      surfaceTintColor: Colors.transparent,
      leading: BackButton(
        color: Colors.black87,
        onPressed: widget.onBack ?? () => Navigator.maybePop(context),
      ),
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
              controller: _scrollController,
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
                            backgroundColor: _footprintChipBg,
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
                    const Spacer(),
                    if (_selectedEntryId != null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: _footprintGold,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () =>
                            setState(() => _selectedEntryId = null),
                        icon: const Icon(Icons.clear, size: 16),
                        label: Text(context.l10n.clearSearch),
                      ),
                  ],
                ),
                if (_selectedEntryId != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.memoriesCount(_filteredEntries.length),
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                if (_filteredEntries.isEmpty)
                  _emptyProvinces()
                else
                  ..._filteredEntries.map(_timelineCard),
              ],
            ),
          ),
  );

  String _timelineTitle(TravelDiaryEntry entry) {
    final title = entry.title.trim();
    if (title.isNotEmpty) return title;
    final province = entry.province.trim();
    if (province.isNotEmpty) return province;
    return entry.note.trim().isEmpty ? '—' : entry.note.trim();
  }

  String _visitedLabel(TravelDiaryEntry entry) {
    final elapsed = DateTime.now().difference(entry.date);
    if (elapsed.inHours < 1) return context.l10n.visitedToday;
    if (elapsed.inHours < 24) {
      return context.l10n.visitedHoursAgo(elapsed.inHours);
    }
    if (elapsed.inDays < 30) return context.l10n.visitedDaysAgo(elapsed.inDays);
    final months = elapsed.inDays ~/ 30;
    return context.l10n.visitedMonthsAgo(months < 1 ? 1 : months);
  }

  String _formatEntryDate(TravelDiaryEntry entry) {
    final locale = Localizations.localeOf(context).languageCode;
    final datePart = DateFormat(
      'd MMM yyyy',
      locale,
    ).format(entry.date);
    final timePart = DateFormat('HH:mm', locale).format(entry.date);
    return '$datePart • $timePart';
  }

  Widget _timelineFallbackThumb() => Container(
    width: 72,
    height: 72,
    color: const Color(0xfffff2cc),
    child: const Icon(Icons.place_outlined, color: _footprintGold),
  );

  Widget _timelineThumb(TravelDiaryEntry entry) {
    final url = entry.imageUrls.isNotEmpty ? entry.imageUrls.first : '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: url.isEmpty
            ? _timelineFallbackThumb()
            : mediaNetworkImage(
                url,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _timelineFallbackThumb(),
              ),
      ),
    );
  }

  Widget _timelineCard(TravelDiaryEntry entry) {
    final isSelected = entry.id == _selectedEntryId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? _footprintCardBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _focusEntry(entry),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _footprintGold : _footprintBorder,
                width: isSelected ? 2 : 1,
              ),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 13,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatEntryDate(entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.history,
                            size: 13,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _visitedLabel(entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
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
  }

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

  LatLng _mapCenter(List<TravelDiaryEntry> located) {
    if (located.isEmpty) return _defaultMapCenter;
    var lat = 0.0;
    var lng = 0.0;
    for (final entry in located) {
      lat += entry.latitude!;
      lng += entry.longitude!;
    }
    return LatLng(lat / located.length, lng / located.length);
  }

  CircleMarker _footprintCircle(TravelDiaryEntry entry) {
    final isSelected = entry.id == _selectedEntryId;
    return CircleMarker(
      point: LatLng(entry.latitude!, entry.longitude!),
      radius: isSelected ? 40 : 34,
      color: _footprintGold.withValues(alpha: isSelected ? 0.32 : 0.22),
      borderColor: _footprintGold,
      borderStrokeWidth: isSelected ? 3 : 2,
    );
  }

  Marker _footprintMarker(TravelDiaryEntry entry) {
    final isSelected = entry.id == _selectedEntryId;
    return Marker(
      point: LatLng(entry.latitude!, entry.longitude!),
      width: isSelected ? 46 : 38,
      height: isSelected ? 46 : 38,
      child: GestureDetector(
        onTap: () => _focusMarker(entry),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.black87 : _footprintGold,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isSelected ? 4 : 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 7,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isSelected ? Icons.check : Icons.flag,
            color: Colors.white,
            size: isSelected ? 22 : 19,
          ),
        ),
      ),
    );
  }

  Widget _mapCard() {
    final locatedEntries = _locatedEntries;

    return Container(
      key: _mapKey,
      height: 310,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _footprintCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _footprintBorder),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter(locatedEntries),
              initialZoom: locatedEntries.isEmpty
                  ? _emptyMapZoom
                  : _defaultMapZoom,
              onTap: (_, __) {
                if (_selectedEntryId != null) {
                  setState(() => _selectedEntryId = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.mapTileUrl,
                userAgentPackageName: 'com.example.myapp',
              ),
              if (locatedEntries.isNotEmpty)
                CircleLayer(
                  circles: locatedEntries.map(_footprintCircle).toList(),
                ),
              if (locatedEntries.isNotEmpty)
                MarkerLayer(
                  markers: locatedEntries.map(_footprintMarker).toList(),
                ),
            ],
          ),
          if (locatedEntries.isEmpty) _mapEmptyOverlay(),
        ],
      ),
    );
  }

  Widget _mapEmptyOverlay() => Positioned.fill(
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
  );

  Widget _emptyProvinces() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _footprintBorder),
    ),
    child: Text(
      context.l10n.noFootprintDescription,
      style: const TextStyle(color: Colors.black54, height: 1.4),
    ),
  );
}
