import 'package:flutter/material.dart';
import 'package:myapp/l10n/l10n.dart';

/// ตัวเลือกวันที่ของแผน ซึ่งแสดงแผนและเส้นทางทีละวัน
class PlanDaySelector extends StatelessWidget {
  const PlanDaySelector({
    required this.dayNumbers,
    required this.selectedIndex,
    required this.dayLabel,
    required this.onSelected,
    this.onAddDay,
    this.onRemoveDay,
    this.canRemoveDay = true,
    super.key,
  });

  final List<int> dayNumbers;
  final int selectedIndex;
  final String dayLabel;
  final ValueChanged<int> onSelected;

  /// null = ซ่อนปุ่มเพิ่มวัน (เช่นยังไม่รองรับ)
  final VoidCallback? onAddDay;

  /// null = ซ่อนปุ่มลบวันของวันที่เลือกอยู่
  final VoidCallback? onRemoveDay;

  /// false = เหลือวันเดียว ลบอีกไม่ได้ (โชว์ปุ่มแบบ disabled)
  final bool canRemoveDay;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: dayNumbers.length + (onAddDay == null ? 0 : 1),
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        // ช่องสุดท้าย = ปุ่มเพิ่มวัน
        if (onAddDay != null && index == dayNumbers.length) {
          return ActionChip(
            key: const ValueKey('plan-day-add'),
            avatar: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.addDay),
            side: const BorderSide(color: Color(0xffdfd1b8)),
            onPressed: onAddDay,
          );
        }
        final selected = index == selectedIndex;
        // วันที่เลือกอยู่แสดงปุ่มลบ (x) ท้าย chip — เหลือวันเดียวปุ่มจะ disabled
        return ChoiceChip(
          key: ValueKey('plan-day-${dayNumbers[index]}'),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$dayLabel ${dayNumbers[index]}'),
              if (selected && onRemoveDay != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: canRemoveDay ? onRemoveDay : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: canRemoveDay ? Colors.white70 : Colors.white38,
                  ),
                ),
              ],
            ],
          ),
          selected: selected,
          showCheckmark: false,
          selectedColor: const Color(0xffe9ad0c),
          labelStyle: TextStyle(
            color: selected ? Colors.white : const Color(0xff292620),
            fontWeight: FontWeight.w700,
          ),
          side: const BorderSide(color: Color(0xffdfd1b8)),
          onSelected: (_) => onSelected(index),
        );
      },
    ),
  );
}
