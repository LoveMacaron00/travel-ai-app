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

  /// null = แตะแล้วแค่สลับวันดู (ไม่มีฟีเจอร์ลบ)
  /// ไม่ null = แตะวันที่เลือกอยู่ซ้ำอีกทีคือลบวันนั้น (มี dialog ยืนยัน)
  final VoidCallback? onRemoveDay;

  /// false = เหลือวันเดียว ลบอีกไม่ได้ (แตะซ้ำจะขึ้น SnackBar เตือนแทน)
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
        final removeDay = onRemoveDay;
        return ChoiceChip(
          key: ValueKey('plan-day-${dayNumbers[index]}'),
          // chip ที่เลือกอยู่โชว์ไอคอนถังขยะไว้ให้รู้ว่าแตะซ้ำคือลบ
          // (ไอคอนเป็นแค่สัญลักษณ์ เป้าแตะคือทั้ง chip ไม่ต้องเล็ง)
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$dayLabel ${dayNumbers[index]}'),
              if (selected && removeDay != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white70,
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
          // chip ไหนยังไม่ถูกเลือก = แตะเพื่อสลับไปดูวันนั้น
          // chip ที่เลือกอยู่ = แตะซ้ำเพื่อลบวันนั้น (มี dialog ยืนยัน ไม่ต้องเล็งปุ่ม x)
          // เหลือวันเดียวแตะซ้ำจะขึ้น SnackBar เตือนแทน
          onSelected: (_) {
            if (selected && removeDay != null) {
              removeDay();
            } else {
              onSelected(index);
            }
          },
        );
      },
    ),
  );
}
