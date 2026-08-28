import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/model/travel_diary_entry.dart';
import 'package:myapp/screen/chatbot_screen.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/services/image_upload.dart';
import 'package:myapp/services/location_service.dart';
import 'package:myapp/services/travel_diary_automation_service.dart';
import 'package:myapp/services/travel_diary_service.dart';
import 'package:myapp/widgets/diary_manual_sheet.dart';
import 'package:myapp/widgets/media_image.dart';

const _diaryGold = Color(0xfff4b400);
const _diaryPaleGold = Color(0xffffefbd);
const _diaryBorder = Color(0xffe6e6e6);

class TravelDiaryScreen extends StatefulWidget {
  const TravelDiaryScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<TravelDiaryScreen> createState() => _TravelDiaryScreenState();
}

class _TravelDiaryScreenState extends State<TravelDiaryScreen> {
  late final TravelDiaryService _diary;
  final Map<String, Timer> _noteSaveTimers = {};
  Timer? _locationReloadTimer;
  List<TravelDiaryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _diary = AppServices.diary;
    LocationService.instance.addListener(_onLocationChanged);
    _initializeDiary();
  }

  Future<void> _initializeDiary() async {
    if (await TravelDiaryAutomationService.isEnabled()) {
      await AppServices.diaryAutomation.start();
    }
    await _loadEntries();
  }

  @override
  void dispose() {
    LocationService.instance.removeListener(_onLocationChanged);
    _locationReloadTimer?.cancel();
    for (final timer in _noteSaveTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _onLocationChanged() {
    _locationReloadTimer?.cancel();
    _locationReloadTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) unawaited(_loadEntries());
    });
  }

  Future<void> _loadEntries() async {
    final entries = await _diary.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _openAiCamera() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatbotScreen(openScannerOnStart: true),
      ),
    );
    await _loadEntries();
  }

  void _scheduleNoteSave(TravelDiaryEntry entry, String note) {
    _noteSaveTimers[entry.id]?.cancel();
    _noteSaveTimers[entry.id] = Timer(const Duration(milliseconds: 650), () {
      final index = _entries.indexWhere((item) => item.id == entry.id);
      if (index < 0) return;
      final updated = _entries[index].copyWith(note: note.trim());
      _entries[index] = updated;
      unawaited(_diary.upsert(updated));
    });
  }

  Future<void> _deleteEntry(TravelDiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteMemory),
        content: Text(context.l10n.deleteMemoryConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.l10n.deleteMemory,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await _diary.delete(entry.id);
    if (!deleted) return;
    _entries.removeWhere((item) => item.id == entry.id);
    if (mounted) setState(() {});
  }

  Future<void> _addManualDiary() async {
    final result = await showDiaryManualSheet(context: context, isEdit: false);
    if (result == null) return;
    if (result.title.isEmpty && result.province.isEmpty && result.note.isEmpty && result.pickedImage == null) return;

    String? uploadedUrl;
    if (result.pickedImage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.memorySaved}...'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      final bytes = await result.pickedImage!.readAsBytes();
      uploadedUrl = await _diary.uploadImage(
        ImageUpload(bytes: bytes, filename: result.pickedImage!.name),
      );
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    }

    final now = DateTime.now();
    final position = LocationService.instance.currentPosition;
    final entry = TravelDiaryEntry(
      id: 'manual_${now.microsecondsSinceEpoch}',
      date: now,
      title: result.title,
      note: result.note,
      province: result.province,
      imageUrls: uploadedUrl != null ? [uploadedUrl] : const [],
      latitude: result.selectedLocation?.latitude ?? position?.latitude,
      longitude: result.selectedLocation?.longitude ?? position?.longitude,
      source: 'manual',
    );
    final ok = await _diary.upsert(entry);
    if (ok) {
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.memorySaved)),
        );
      }
    }
  }

  Future<void> _editManualDiary(TravelDiaryEntry entry) async {
    final result = await showDiaryManualSheet(
      context: context,
      initialTitle: entry.title,
      initialProvince: entry.province,
      initialNote: entry.note,
      initialImageUrls: entry.imageUrls,
      initialLocation: entry.hasLocation ? LatLng(entry.latitude!, entry.longitude!) : null,
      isEdit: true,
    );
    if (result == null) return;

    String? uploadedUrl;
    List<String> finalImageUrls = [];
    if (result.pickedImage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.memorySaved}...'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      final bytes = await result.pickedImage!.readAsBytes();
      uploadedUrl = await _diary.uploadImage(
        ImageUpload(bytes: bytes, filename: result.pickedImage!.name),
      );
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
      if (uploadedUrl != null) {
        finalImageUrls = [uploadedUrl];
      } else {
        if (!result.removeExistingImage && result.existingImageUrls.isNotEmpty) {
          finalImageUrls = result.existingImageUrls;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.uploadFailed)),
          );
        }
      }
    } else if (!result.removeExistingImage && result.existingImageUrls.isNotEmpty) {
      finalImageUrls = result.existingImageUrls;
    }

    if (result.title.isEmpty && result.province.isEmpty && result.note.isEmpty && finalImageUrls.isEmpty) {
      return;
    }

    final updated = TravelDiaryEntry(
      id: entry.id,
      date: entry.date,
      lastSeenAt: entry.lastSeenAt,
      title: result.title,
      note: result.note,
      province: result.province,
      insight: entry.insight,
      imageUrls: finalImageUrls,
      latitude: result.selectedLocation?.latitude,
      longitude: result.selectedLocation?.longitude,
      destinationId: entry.destinationId,
      source: entry.source,
    );

    final ok = await _diary.upsert(updated);
    if (ok) {
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.memorySaved)),
        );
      }
    }
  }

  List<_DiaryDay> get _days {
    final grouped = <DateTime, List<TravelDiaryEntry>>{};
    for (final entry in _entries) {
      final day = DateUtils.dateOnly(entry.date);
      grouped.putIfAbsent(day, () => []).add(entry);
    }
    final chronological = grouped.keys.toList()..sort();
    final dayNumber = <DateTime, int>{
      for (var index = 0; index < chronological.length; index++)
        chronological[index]: index + 1,
    };
    final newestFirst = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return newestFirst.map((date) {
      final entries = grouped[date]!..sort((a, b) => a.date.compareTo(b.date));
      final places = entries
          .map((entry) => entry.province.trim())
          .where((province) => province.isNotEmpty)
          .toSet();
      final place = places.isNotEmpty
          ? places.take(2).join(', ')
          : entries.first.title;
      return _DiaryDay(
        number: dayNumber[date]!,
        date: date,
        place: place,
        entries: entries,
      );
    }).toList();
  }

  String _formatDate(DateTime date) => DateFormat(
    'd MMMM yyyy',
    Localizations.localeOf(context).languageCode,
  ).format(date);

  String _formatTime(DateTime date) => DateFormat(
    'h:mm a',
    Localizations.localeOf(context).languageCode,
  ).format(date);

  String _formatDuration(int minutes) {
    if (minutes < 60) return context.l10n.diaryMinutes(minutes.clamp(1, 59));
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) return context.l10n.diaryHours(hours);
    return context.l10n.diaryHoursMinutes(hours, remaining);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: BackButton(
        color: Colors.black87,
        onPressed: widget.onBack ?? () => Navigator.maybePop(context),
      ),
      title: Text(
        context.l10n.smartTravelDiary,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: context.l10n.addManualDiary,
          onPressed: _addManualDiary,
          icon: const Icon(Icons.add_circle_outline, color: _diaryGold),
        ),
        IconButton(
          tooltip: context.l10n.openAiCamera,
          onPressed: _openAiCamera,
          icon: const Icon(Icons.photo_camera_outlined, color: _diaryGold),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _diaryGold))
        : _entries.isEmpty
        ? _emptyState()
        : RefreshIndicator(
            color: _diaryGold,
            onRefresh: _loadEntries,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 12, 14, 28),
              itemCount: _days.length,
              itemBuilder: (_, index) => _daySection(_days[index]),
            ),
          ),
  );

  Widget _emptyState() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: _diaryPaleGold,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories_outlined,
              color: _diaryGold,
              size: 42,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.noDiaryEntries,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.diaryAutoDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.45),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _openAiCamera,
            style: FilledButton.styleFrom(
              backgroundColor: _diaryGold,
              foregroundColor: Colors.black,
              minimumSize: const Size(190, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(context.l10n.openAiCamera),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addManualDiary,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              minimumSize: const Size(190, 48),
              side: const BorderSide(color: _diaryGold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.edit_note, color: _diaryGold),
            label: Text(context.l10n.addManualDiary),
          ),
        ],
      ),
    ),
  );

  Widget _daySection(_DiaryDay day) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 26, bottom: 2),
          child: Text(
            context.l10n.diaryDay(
              day.number,
              day.place.isEmpty ? context.l10n.thailand : day.place,
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26, bottom: 20),
          child: Text(
            _formatDate(day.date),
            style: const TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ),
        for (var index = 0; index < day.entries.length; index++)
          _timelineEntry(
            day.entries[index],
            isLast: index == day.entries.length - 1,
          ),
      ],
    ),
  );

  Widget _timelineEntry(TravelDiaryEntry entry, {required bool isLast}) =>
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  _timelineNode(entry),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1,
                        color: const Color(0xffbdbdbd),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _entryHeader(entry),
                    const SizedBox(height: 10),
                    _entryCard(entry),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _timelineNode(TravelDiaryEntry entry) {
    final IconData icon;
    final Color color;
    switch (entry.source) {
      case 'aiCamera':
        icon = Icons.photo_camera;
        color = const Color(0xff9e9e9e);
      case 'manual':
        icon = Icons.edit_note;
        color = const Color(0xff6d9eeb);
      default: // gps
        icon = Icons.location_on;
        color = _diaryGold;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _entryHeader(TravelDiaryEntry entry) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title.isEmpty ? context.l10n.locationDetails : entry.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (entry.durationMinutes > 0) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.schedule, color: _diaryGold, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    _formatDuration(entry.durationMinutes),
                    style: const TextStyle(color: _diaryGold, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          _formatTime(entry.date),
          style: const TextStyle(color: Colors.black45, fontSize: 13),
        ),
      ),
      SizedBox(
        width: 32,
        height: 24,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert, size: 18, color: Colors.black45),
          onSelected: (val) {
            if (val == 'edit') _editManualDiary(entry);
            if (val == 'delete') _deleteEntry(entry);
          },
          itemBuilder: (_) => [
            if (entry.source == 'manual')
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(context.l10n.editMemory),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                context.l10n.deleteMemory,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _entryCard(TravelDiaryEntry entry) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _diaryBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entry.imageUrls.isNotEmpty) ...[
          _imageGallery(entry),
          const SizedBox(height: 10),
        ],
        if (entry.insight.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _diaryPaleGold,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xffffd96b)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: _diaryGold, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${context.l10n.culturalInsight}: ${entry.insight}',
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextFormField(
          key: ValueKey('diary-note-${entry.id}'),
          initialValue: entry.note,
          minLines: 3,
          maxLines: 5,
          onChanged: (value) => _scheduleNoteSave(entry, value),
          decoration: InputDecoration(
            hintText: context.l10n.writeDiaryHint,
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: Icon(Icons.edit_outlined, size: 17),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.black45),
            ),
            contentPadding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
          ),
        ),
      ],
    ),
  );

  Widget _imageGallery(TravelDiaryEntry entry) {
    final images = entry.imageUrls;
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(height: 184, child: _image(images.first)),
      );
    }
    return SizedBox(
      height: 174,
      child: Row(
        children: [
          for (var index = 0; index < images.take(2).length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _image(images[index]),
                    if (index == 1 && images.length > 2)
                      ColoredBox(
                        color: Colors.black38,
                        child: Center(
                          child: Text(
                            '+${images.length - 2}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _image(String imageUrl) => mediaNetworkImage(
    imageUrl,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _imageFallback(),
  );

  Widget _imageFallback() => const ColoredBox(
    color: Color(0xffeeeeee),
    child: Center(
      child: Icon(Icons.image_not_supported_outlined, color: Colors.black26),
    ),
  );
}

class _DiaryDay {
  const _DiaryDay({
    required this.number,
    required this.date,
    required this.place,
    required this.entries,
  });

  final int number;
  final DateTime date;
  final String place;
  final List<TravelDiaryEntry> entries;
}
