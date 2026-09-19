import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/features/diary/domain/travel_diary_entry.dart';
import 'package:myapp/core/di/app_services.dart';
import 'package:myapp/features/media/data/image_upload.dart';
import 'package:myapp/features/diary/data/travel_diary_service.dart';
import 'package:myapp/features/diary/data/travel_journey_service.dart';
import 'package:myapp/features/diary/presentation/travel_footprint_screen.dart';
import 'package:myapp/features/diary/widgets/diary_calendar_card.dart';
import 'package:myapp/features/diary/widgets/diary_manual_sheet.dart';
import 'package:myapp/features/diary/widgets/diary_sub_entry_sheet.dart';
import 'package:myapp/core/widgets/media_image.dart';

const _diaryGold = Color(0xfff4b400);
const _diaryPaleGold = Color(0xffffefbd);
const _diaryBorder = Color(0xffe6e6e6);

/// หน้า Smart Travel Diary — สมุดบันทึกการเดินทางแบบ timeline แบ่งตามวัน
/// ผู้ใช้บันทึกไดอารี่ด้วยการ Check-in หรือเขียนเองได้
class TravelDiaryScreen extends StatefulWidget {
  const TravelDiaryScreen({
    super.key,
    this.onBack,
    this.onOpenFootprint,
    this.focusEntryId,
  });

  final VoidCallback? onBack;
  final VoidCallback? onOpenFootprint;
  final String? focusEntryId;

  @override
  State<TravelDiaryScreen> createState() => _TravelDiaryScreenState();
}

class _TravelDiaryScreenState extends State<TravelDiaryScreen> {
  late final TravelDiaryService _diary;
  List<TravelDiaryEntry> _entries = [];
  final Set<String> _expandedInsightIds = {};
  bool _loading = true;
  // ปฏิทินกรองตามวัน — null = แสดงทั้งหมด
  DateTime? _selectedCalendarDay;
  DateTime _calendarMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _diary = AppServices.diary;
    TravelJourneyService.instance.addListener(_onJourneyUpdated);
    _loadEntries();
  }

  void _onJourneyUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TravelJourneyService.instance.removeListener(_onJourneyUpdated);
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final entries = await _diary.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
      // เดือนปฏิทินตามวันที่เลือกไว้ — ถ้ายังไม่เลือกใช้เดือนปัจจุบัน
      final anchor = _selectedCalendarDay ?? DateTime.now();
      _calendarMonth = DateTime(anchor.year, anchor.month);
      // ถ้าวันที่เลือกไว้ไม่มี entry แล้ว (เช่นลบไป) ให้ล้างฟิลเตอร์
      if (_selectedCalendarDay != null &&
          !_entries.any(
            (e) => DateUtils.isSameDay(
              DateUtils.dateOnly(e.date),
              _selectedCalendarDay,
            ),
          )) {
        _selectedCalendarDay = null;
      }
    });
  }

  /// ลบ entry — มี dialog ยืนยันก่อนเสมอ เพราะลบแล้วถอนคืนไม่ได้
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

  /// เพิ่มบันทึกเองจากฟอร์ม — อัปโหลดรูปก่อน (ถ้ามี) แล้วจึงบันทึก entry
  /// รูปไม่สำเร็จก็ยังบันทึกข้อความได้ แค่ไม่มีรูปประกอบ
  /// [forDay] คือวันที่เลือกจากปฏิทิน — บันทึกจะลงวันนั้นแทนวันปัจจุบัน
  Future<void> _addManualDiary({DateTime? forDay}) async {
    final result = await showDiaryManualSheet(
      context: context,
      isEdit: false,
      initialDate: forDay,
    );
    if (!mounted) return;
    if (result == null) return;
    if (result.title.isEmpty &&
        result.province.isEmpty &&
        result.note.isEmpty &&
        result.pickedImage == null) {
      return;
    }

    String? uploadedUrl;
    if (result.pickedImage != null) {
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.memorySaved}...'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      final bytes = await result.pickedImage!.readAsBytes();
      uploadedUrl = await _diary.uploadImage(
        ImageUpload(bytes: bytes, filename: result.pickedImage!.name),
      );
      if (!mounted) return;
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    }

    if (!mounted) return;
    final now = DateTime.now();
    // วันที่ของบันทึก: ที่เลือกจากปฏิทินในฟอร์ม > วันที่แตะบนปฏิทินเดือน > ปัจจุบัน
    final pickedDay = result.entryDate ?? forDay;
    final entryDate = pickedDay != null
        ? DateTime(
            pickedDay.year,
            pickedDay.month,
            pickedDay.day,
            now.hour,
            now.minute,
          )
        : now;
    final entry = TravelDiaryEntry(
      id: 'manual_${now.microsecondsSinceEpoch}',
      date: entryDate,
      title: result.title,
      note: result.note,
      province: result.province,
      imageUrls: uploadedUrl != null ? [uploadedUrl] : const [],
      latitude: result.selectedLocation?.latitude,
      longitude: result.selectedLocation?.longitude,
      source: 'manual',
    );
    final ok = await _diary.upsert(entry);
    if (!mounted) return;
    if (ok) {
      // บันทึกลงวันที่เลือก — เลื่อนปฏิทินไปเดือนนั้นแล้วกรองให้เห็นทันที
      if (pickedDay != null) {
        _selectedCalendarDay = DateUtils.dateOnly(pickedDay);
        _calendarMonth = DateTime(pickedDay.year, pickedDay.month);
      }
      await _loadEntries();
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.memorySaved)));
      }
    }
  }

  Future<void> _selectCheckInForDiary() async {
    final checkIns = _entries.where((entry) => entry.hasLocation).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final selected = await showModalBottomSheet<TravelDiaryEntry>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.selectExistingCheckIn,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (checkIns.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    context.l10n.noCheckIns,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              else
                SizedBox(
                  height: 320,
                  child: ListView.separated(
                    itemCount: checkIns.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final entry = checkIns[index];
                      final title = entry.title.isNotEmpty
                          ? entry.title
                          : entry.province.isNotEmpty
                          ? entry.province
                          : context.l10n.locationDetails;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: _diaryPaleGold,
                          child: Icon(Icons.location_on, color: _diaryGold),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(_formatDate(entry.date)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(sheetContext, entry),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      await _addDiaryToEntry(selected);
    }
  }

  /// แก้ไข entry ที่สร้างเอง — กติกาภาพ:
  /// อัปโหลดรูปใหม่สำเร็จ → แทนที่รูปเดิมทั้งหมด
  /// อัปโหลดพลาด → คงรูปเดิมไว้ (เว้นแต่ผู้ใช้สั่งลบรูปเดิมในฟอร์มแล้ว) พร้อมแจ้งเตือน
  Future<void> _editManualDiary(TravelDiaryEntry entry) async {
    final result = await showDiaryManualSheet(
      context: context,
      initialTitle: entry.title,
      initialProvince: entry.province,
      initialNote: entry.note,
      initialImageUrls: entry.imageUrls,
      isEdit: true,
    );
    if (!mounted) return;
    if (result == null) return;

    String? uploadedUrl;
    List<String> finalImageUrls = [];
    if (result.pickedImage != null) {
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.memorySaved}...'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      final bytes = await result.pickedImage!.readAsBytes();
      uploadedUrl = await _diary.uploadImage(
        ImageUpload(bytes: bytes, filename: result.pickedImage!.name),
      );
      if (!mounted) return;
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
      if (uploadedUrl != null) {
        finalImageUrls = [uploadedUrl];
      } else {
        if (!result.removeExistingImage &&
            result.existingImageUrls.isNotEmpty) {
          finalImageUrls = result.existingImageUrls;
        }
        if (mounted) {
          final l10n = context.l10n;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.uploadFailed)));
        }
      }
    } else if (!result.removeExistingImage &&
        result.existingImageUrls.isNotEmpty) {
      finalImageUrls = result.existingImageUrls;
    }

    if (result.title.isEmpty &&
        result.province.isEmpty &&
        result.note.isEmpty &&
        finalImageUrls.isEmpty) {
      return;
    }

    if (!mounted) return;
    final updated = TravelDiaryEntry(
      id: entry.id,
      date: entry.date,
      lastSeenAt: entry.lastSeenAt,
      title: result.title,
      note: result.note,
      province: result.province,
      insight: entry.insight,
      imageUrls: finalImageUrls,
      latitude: entry.latitude,
      longitude: entry.longitude,
      destinationId: entry.destinationId,
      source: entry.source,
    );

    final ok = await _diary.upsert(updated);
    if (!mounted) return;
    if (ok) {
      await _loadEntries();
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.memorySaved)));
      }
    }
  }

  Future<void> _addDiaryToEntry(TravelDiaryEntry entry) async {
    final result = await showDiarySubEntrySheet(
      context: context,
      checkInTitle: entry.title.isNotEmpty ? entry.title : entry.province,
    );
    if (result == null || !mounted) return;

    final List<String> uploadedUrls = [];
    if (result.pickedImages.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.memorySaved}...'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      for (final img in result.pickedImages) {
        final bytes = await img.readAsBytes();
        final url = await _diary.uploadImage(
          ImageUpload(bytes: bytes, filename: img.name),
        );
        if (url != null) uploadedUrls.add(url);
      }
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    }
    if (!mounted) return;

    final now = DateTime.now();
    final newSub = DiarySubEntry(
      id: 'sub_${now.microsecondsSinceEpoch}',
      time: now,
      note: result.note,
      imageUrls: uploadedUrls,
    );

    final updated = entry.addSubEntry(newSub);
    final ok = await _diary.upsert(updated);
    if (!mounted) return;
    if (ok) {
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.memorySaved)));
      }
    }
  }

  Future<void> _editDiarySubEntry(
    TravelDiaryEntry entry,
    DiarySubEntry sub,
  ) async {
    final result = await showDiarySubEntrySheet(
      context: context,
      initialNote: sub.note,
      initialImageUrls: sub.imageUrls,
      isEdit: true,
      checkInTitle: entry.title.isNotEmpty ? entry.title : entry.province,
    );
    if (result == null || !mounted) return;

    final List<String> finalImages = List.from(result.keptExistingImages);
    if (result.pickedImages.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.memorySaved}...'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      for (final img in result.pickedImages) {
        final bytes = await img.readAsBytes();
        final url = await _diary.uploadImage(
          ImageUpload(bytes: bytes, filename: img.name),
        );
        if (url != null) finalImages.add(url);
      }
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    }
    if (!mounted) return;

    final updatedSub = sub.copyWith(note: result.note, imageUrls: finalImages);

    final updated = entry.updateSubEntry(updatedSub);
    final ok = await _diary.upsert(updated);
    if (!mounted) return;
    if (ok) {
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.memorySaved)));
      }
    }
  }

  Future<void> _deleteDiarySubEntry(
    TravelDiaryEntry entry,
    DiarySubEntry sub,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteDiaryEntry),
        content: Text(context.l10n.deleteDiaryEntryConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.l10n.deleteDiaryEntry,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final updated = entry.removeSubEntry(sub.id);
    final ok = await _diary.upsert(updated);
    if (!mounted) return;
    if (ok) {
      await _loadEntries();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.deleteMemory)));
      }
    }
  }

  void _openFootprint() {
    if (widget.onOpenFootprint != null) {
      widget.onOpenFootprint!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelFootprintScreen(
          onBack: () => Navigator.pop(context),
          onOpenDiary: () => Navigator.pop(context),
        ),
      ),
    ).then((_) {
      if (mounted) _loadEntries();
    });
  }

  /// จัดกลุ่ม entries ตามวันเพื่อวาด timeline
  /// เลขวัน (Day 1, 2, ...) นับจากเก่าสุด แต่ลิสต์ที่ได้เรียงใหม่สุดก่อน
  /// ภายในวันเดียวเรียงเก่า → ใหม่ ส่วนชื่อสถานที่ของวันใช้จังหวัดสูงสุด 2 ที่
  /// ถ้าไม่มีจังหวัดใช้ชื่อ entry แรกแทน
  /// ถ้าเลือกวันจากปฏิทิน (_selectedCalendarDay) กรองเฉพาะวันนั้น
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
    var newestFirst = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    if (_selectedCalendarDay != null) {
      newestFirst = newestFirst
          .where((date) => DateUtils.isSameDay(date, _selectedCalendarDay))
          .toList();
    }
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

  // format วันที่/เวลา ตามภาษาที่ตั้งในแอป (ไทย/อังกฤษ)
  String _formatDate(DateTime date) => DateFormat(
    'd MMMM yyyy',
    Localizations.localeOf(context).languageCode,
  ).format(date);

  String _formatTime(DateTime date) => DateFormat('HH:mm').format(date);

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
          tooltip: context.l10n.selectCheckInForDiary,
          onPressed: _selectCheckInForDiary,
          icon: const Icon(Icons.add_location_alt_outlined, color: _diaryGold),
        ),
        IconButton(
          tooltip: context.l10n.goToFootprint,
          onPressed: _openFootprint,
          icon: const Icon(Icons.map_outlined, color: _diaryGold),
        ),
        IconButton(
          tooltip: context.l10n.addManualDiary,
          onPressed: () => _addManualDiary(forDay: _selectedCalendarDay),
          icon: const Icon(Icons.add_circle_outline, color: _diaryGold),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _diaryGold))
        : _entries.isEmpty && _selectedCalendarDay == null
        ? _emptyState()
        : RefreshIndicator(
            color: _diaryGold,
            onRefresh: _loadEntries,
            child: _diaryBody(),
          ),
  );

  Widget _journeyRecordingBanner() {
    final journey = TravelJourneyService.instance;
    if (!journey.isRecording) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfffff7dc),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _diaryGold, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1a000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.recordingJourneyActive,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.l10n.timeElapsed}: ${journey.formattedDuration} • ${context.l10n.distanceWalked}: ${journey.formattedDistance}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openFootprint,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xffa67400),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.walkingTrail,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ชุดวันของปฏิทิน — วันที่เคยบันทึก + รูปแรกของวันนั้น (badge ใต้เลขวัน)
  Set<DateTime> get _calendarDays =>
      _entries.map((e) => DateUtils.dateOnly(e.date)).toSet();

  Map<DateTime, String> get _calendarThumbs {
    final thumbs = <DateTime, String>{};
    for (final entry in _entries) {
      final day = DateUtils.dateOnly(entry.date);
      if (thumbs.containsKey(day)) continue;
      if (entry.imageUrls.isNotEmpty) thumbs[day] = entry.imageUrls.first;
    }
    return thumbs;
  }

  // แตะวันเดิมซ้ำ = ล้างฟิลเตอร์กลับทั้งหมด (เหมือนกากบาทในปฏิทิน)
  void _onCalendarDaySelected(DateTime date) {
    final day = DateUtils.dateOnly(date);
    setState(() {
      if (_selectedCalendarDay != null &&
          DateUtils.isSameDay(_selectedCalendarDay, day)) {
        _selectedCalendarDay = null;
      } else {
        _selectedCalendarDay = day;
      }
    });
  }

  Widget _diaryBody() {
    final days = _days;
    final selectedDay = _selectedCalendarDay;
    final showPreview =
        selectedDay != null &&
        days.length == 1 &&
        DateUtils.isSameDay(days.first.date, selectedDay);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 14, 28),
      itemCount: 2 + (showPreview ? 1 : 0) + (days.isEmpty ? 1 : days.length),
      itemBuilder: (_, index) {
        if (index == 0) return _journeyRecordingBanner();
        if (index == 1) {
          return DiaryCalendarCard(
            focusedMonth: _calendarMonth,
            selectedDay: _selectedCalendarDay,
            daysWithEntries: _calendarDays,
            thumbnailByDay: _calendarThumbs,
            onMonthChanged: (month) => setState(() => _calendarMonth = month),
            onDaySelected: _onCalendarDaySelected,
            onClearDay: () => setState(() => _selectedCalendarDay = null),
          );
        }
        if (showPreview && index == 2) {
          return DiaryDayPreviewCard(
            date: days.first.date,
            place: days.first.place,
            entries: days.first.entries,
          );
        }
        if (days.isEmpty) return _filteredEmptyState();
        final day = days[showPreview ? index - 3 : index - 2];
        return _daySection(day);
      },
    );
  }

  // เลือกวันแล้วไม่มีบันทึก — ชวนกรอกย้อนหลังลงวันนั้นได้เลย
  Widget _filteredEmptyState() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 0, 8),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _diaryBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_note_outlined, color: _diaryGold, size: 36),
          const SizedBox(height: 10),
          Text(
            context.l10n.diaryNoEntriesOnDay,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _addManualDiary(forDay: _selectedCalendarDay),
            style: FilledButton.styleFrom(
              backgroundColor: _diaryGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.diaryAddForDay),
          ),
        ],
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
            context.l10n.noDiaryEntriesDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.45),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _selectCheckInForDiary,
            style: FilledButton.styleFrom(
              backgroundColor: _diaryGold,
              foregroundColor: Colors.black,
              minimumSize: const Size(250, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(context.l10n.selectCheckInForDiary),
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

  /// ไอคอน/สีของ node บน timeline แยกตามการมีพิกัดหรือการเขียนเอง
  Widget _timelineNode(TravelDiaryEntry entry) {
    final IconData icon;
    final Color color;
    switch (entry.source) {
      case 'manual':
        icon = Icons.edit_note;
        color = const Color(0xff6d9eeb);
      default:
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
            Row(
              children: [
                Flexible(
                  child: Text(
                    entry.title.isEmpty
                        ? context.l10n.locationDetails
                        : entry.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (entry.province.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _diaryPaleGold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.province,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff8a6300),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                if (entry.hasLocation) ...[
                  const Icon(Icons.place, color: _diaryGold, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    context.l10n.locationDetails,
                    style: const TextStyle(
                      color: _diaryGold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (entry.durationMinutes > 0) ...[
                  const Icon(Icons.schedule, color: Colors.black45, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    _formatDuration(entry.durationMinutes),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
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
            if (val == 'add') _addDiaryToEntry(entry);
            if (val == 'edit') _editManualDiary(entry);
            if (val == 'delete') _deleteEntry(entry);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'add',
              child: Row(
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(context.l10n.addDiaryEntry),
                ],
              ),
            ),
            if (entry.source == 'manual' || entry.source == 'gps')
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

  Widget _subEntryWidget(
    TravelDiaryEntry entry,
    DiarySubEntry sub, {
    bool includeInsight = false,
  }) {
    final expandedIds = _expandedInsightIds;
    final toggleId = entry.id;
    final isExpanded = expandedIds.contains(toggleId);

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 13, color: Colors.black45),
              const SizedBox(width: 5),
              Text(
                _formatTime(sub.time),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 28,
                height: 22,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 16,
                    color: Colors.black45,
                  ),
                  onSelected: (val) {
                    if (val == 'edit') _editDiarySubEntry(entry, sub);
                    if (val == 'delete') _deleteDiarySubEntry(entry, sub);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text(context.l10n.editDiaryEntry),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        context.l10n.deleteDiaryEntry,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!includeInsight && sub.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            _imagesWidget(sub.imageUrls),
          ],
          if (includeInsight &&
              (sub.imageUrls.isNotEmpty || entry.insight.isNotEmpty)) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() {
                if (!expandedIds.add(toggleId)) {
                  expandedIds.remove(toggleId);
                }
              }),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _diaryPaleGold.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffffd96b)),
                ),
                child: Row(
                  children: [
                    Icon(
                      sub.imageUrls.isNotEmpty
                          ? Icons.photo_outlined
                          : Icons.auto_awesome,
                      color: _diaryGold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sub.imageUrls.isNotEmpty
                            ? context.l10n.diaryPhotos(sub.imageUrls.length)
                            : context.l10n.culturalInsight,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xff8a6300),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              if (sub.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                _imagesWidget(sub.imageUrls),
              ],
              if (includeInsight && entry.insight.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _diaryPaleGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.insight,
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ],
          ],
          if (sub.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sub.note,
              style: const TextStyle(
                fontSize: 14,
                height: 1.42,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _entryCard(TravelDiaryEntry entry) {
    final isFocused =
        widget.focusEntryId != null && widget.focusEntryId == entry.id;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused ? _diaryGold : _diaryBorder,
          width: isFocused ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (isFocused)
            BoxShadow(
              color: _diaryGold.withValues(alpha: 0.22),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry.subEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'ยังไม่มีไดอารี่ในจุดเช็คอินนี้ แตะปุ่มด้านล่างเพื่อเขียนบันทึกหรือแนบรูปภาพ',
                style: const TextStyle(fontSize: 13, color: Colors.black45),
              ),
            )
          else ...[
            _subEntryWidget(
              entry,
              entry.subEntries.first,
              includeInsight: entry.insight.isNotEmpty,
            ),
            for (var i = 1; i < entry.subEntries.length; i++) ...[
              const SizedBox(height: 10),
              _subEntryWidget(entry, entry.subEntries[i]),
            ],
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _addDiaryToEntry(entry),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xff8a6300),
              side: const BorderSide(color: Color(0xffffe082)),
              backgroundColor: const Color(0xfffffdf7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 18,
              color: _diaryGold,
            ),
            label: Text(
              context.l10n.addDiaryEntry,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// แกลเลอรีรูป — 1 รูปโชว์เต็ม, หลายรูปโชว์ 2 รูปแรก
  Widget _imagesWidget(List<String> images) {
    if (images.isEmpty) return const SizedBox.shrink();
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(height: 180, child: _image(images.first)),
      );
    }
    return SizedBox(
      height: 160,
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

/// ข้อมูลหนึ่งวันของ diary เอาไปแสดงเป็น section เดียวบน timeline
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
