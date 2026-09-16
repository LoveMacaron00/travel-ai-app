import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/core/widgets/media_image.dart';
import 'package:myapp/features/diary/domain/travel_diary_entry.dart';
import 'package:myapp/l10n/l10n.dart';

const _calendarGold = Color(0xfff4b400);
const _calendarPaleGold = Color(0xfffff7dc);
const _calendarBorder = Color(0xffe6e6e6);
const _calendarWeekday = Color(0xff9e9e9e);

/// ปฏิทินเดือนของ diary ตามภาพตัวอย่าง — แถววันเริ่มอาทิตย์ (Sun..Sat)
/// วันที่มี entry โชว์ badge วงกลม (รูปแรกของวันนั้น ถ้าไม่มีรูปใช้ไอคอนทอง)
/// แตะวันเพื่อกรองลิสต์ข้างล่างเฉพาะวันนั้น แตะซ้ำเพื่อล้างกลับทั้งหมด
class DiaryCalendarCard extends StatelessWidget {
  const DiaryCalendarCard({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.daysWithEntries,
    required this.thumbnailByDay,
    required this.onMonthChanged,
    required this.onDaySelected,
    required this.onClearDay,
  });

  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final Set<DateTime> daysWithEntries;
  final Map<DateTime, String> thumbnailByDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onClearDay;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    // ชื่อวันสั้นตามภาษาเครื่อง เริ่มวันอาทิตย์ (2024-01-07 คือวันอาทิตย์)
    final weekLabels = List<String>.generate(
      7,
      (i) => DateFormat('E', locale).format(DateTime(2024, 1, 7 + i)),
    );
    final monthStart = DateTime(focusedMonth.year, focusedMonth.month);
    // เริ่มแถวจากวันอาทิตย์เหมือนภาพตัวอย่าง (แถวแรก Sun..Sat)
    final firstWeekday = monthStart.weekday % 7;
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final monthLabel = DateFormat(
      'MMMM yyyy',
      locale,
    ).format(monthStart);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 0, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _calendarBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _monthArrow(Icons.chevron_left, () {
                onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month - 1),
                );
              }),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showMonthYearPicker(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            monthLabel,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _monthArrow(Icons.chevron_right, () {
                onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month + 1),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: weekLabels
                .map(
                  (name) => Expanded(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _calendarWeekday,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 2,
              childAspectRatio: 0.78,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (_, index) {
              if (index < firstWeekday) return const SizedBox.shrink();
              final day = index - firstWeekday + 1;
              final date = DateTime(
                focusedMonth.year,
                focusedMonth.month,
                day,
              );
              final key = DateUtils.dateOnly(date);
              final hasEntry = daysWithEntries.contains(key);
              final isSelected =
                  selectedDay != null &&
                  DateUtils.isSameDay(selectedDay, date);
              final thumb = thumbnailByDay[key];
              return GestureDetector(
                onTap: () => onDaySelected(date),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? _calendarGold
                            : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _dayBadge(
                      hasEntry: hasEntry,
                      isSelected: isSelected,
                      thumb: thumb,
                    ),
                  ],
                ),
              );
            },
          ),
          if (selectedDay != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat(
                        'd MMMM yyyy',
                        locale,
                      ).format(selectedDay!),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: _calendarGold,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onClearDay,
                    icon: const Icon(Icons.clear, size: 16),
                    label: Text(context.l10n.diaryShowAll),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _monthArrow(IconData icon, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: Colors.black54),
    ),
  );

  // แตะชื่อเดือน → dialog เลือกเดือน/ปี (เลื่อนปีด้วยลูกศร + แตะเดือนเพื่อยืนยัน)
  Future<void> _showMonthYearPicker(BuildContext context) async {
    final locale = Localizations.localeOf(context).languageCode;
    var year = focusedMonth.year;
    final monthNames = List<String>.generate(
      12,
      (i) => DateFormat('MMM', locale).format(DateTime(2000, i + 1)),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _monthArrow(Icons.chevron_left, () {
                      setDialogState(() => year--);
                    }),
                    Expanded(
                      child: Text(
                        // ปี พ.ศ. อัตโนมัติเมื่อภาษาไทยผ่าน intl (th → BE)
                        DateFormat('yyyy', locale).format(DateTime(year)),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _monthArrow(Icons.chevron_right, () {
                      setDialogState(() => year++);
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: 12,
                  itemBuilder: (_, index) {
                    final isCurrent =
                        index + 1 == focusedMonth.month && year == focusedMonth.year;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(dialogContext);
                        onMonthChanged(DateTime(year, index + 1));
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? _calendarGold
                              : _calendarPaleGold,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? _calendarGold
                                : _calendarBorder,
                          ),
                        ),
                        child: Text(
                          monthNames[index],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isCurrent
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(dialogContext.l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// badge ใต้วนที่: มี entry = วงกลมรูปแรก/ไอคอนทอง (ตามตัวอย่าง),
  /// วันทีเลอก = วงกลมทองทึบ, วันว่าง = จุดเทาจาง
  Widget _dayBadge({
    required bool hasEntry,
    required bool isSelected,
    String? thumb,
  }) {
    if (isSelected) {
      return Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: _calendarGold,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: hasEntry && thumb != null && thumb.isNotEmpty
            ? ClipOval(child: _badgeImage(thumb))
            : const Icon(Icons.check, color: Colors.white, size: 16),
      );
    }
    if (hasEntry) {
      if (thumb != null && thumb.isNotEmpty) {
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _calendarGold, width: 2),
          ),
          child: ClipOval(child: _badgeImage(thumb)),
        );
      }
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _calendarPaleGold,
          shape: BoxShape.circle,
          border: Border.all(color: _calendarGold, width: 2),
        ),
        child: const Icon(
          Icons.location_on,
          color: _calendarGold,
          size: 16,
        ),
      );
    }
    return Container(
      width: 6,
      height: 30,
      alignment: Alignment.topCenter,
      child: Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Color(0xffe0e0e0),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _badgeImage(String url) => mediaNetworkImage(
    url,
    width: 30,
    height: 30,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => const ColoredBox(
      color: _calendarPaleGold,
      child: Icon(Icons.location_on, color: _calendarGold, size: 16),
    ),
  );
}

/// แถบสรุปวันที่เลือกสไตล์ภาพตัวอย่าง — เลขวันตัวใหญ่ + ชื่อที่
/// + จำนวนบันทึก + รูปแรกของวันนั้น (ถ้ามี)
class DiaryDayPreviewCard extends StatelessWidget {
  const DiaryDayPreviewCard({
    super.key,
    required this.date,
    required this.place,
    required this.entries,
  });

  final DateTime date;
  final String place;
  final List<TravelDiaryEntry> entries;

  String? get _thumbnail {
    for (final entry in entries) {
      if (entry.imageUrls.isNotEmpty) return entry.imageUrls.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbnail ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 0, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _calendarBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${date.day}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                DateFormat(
                  'MMM yyyy',
                  Localizations.localeOf(context).languageCode,
                ).format(date),
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.memoriesCount(entries.length),
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (thumb.isNotEmpty) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: mediaNetworkImage(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xffeeeeee),
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.black26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
