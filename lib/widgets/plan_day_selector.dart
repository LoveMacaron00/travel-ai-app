import 'package:flutter/material.dart';

/// ตัวเลือกวันที่ของแผน ซึ่งแสดงแผนและเส้นทางทีละวัน
class PlanDaySelector extends StatelessWidget {
  const PlanDaySelector({
    required this.dayNumbers,
    required this.selectedIndex,
    required this.dayLabel,
    required this.onSelected,
    super.key,
  });

  final List<int> dayNumbers;
  final int selectedIndex;
  final String dayLabel;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: dayNumbers.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, index) => ChoiceChip(
        key: ValueKey('plan-day-${dayNumbers[index]}'),
        label: Text('$dayLabel ${dayNumbers[index]}'),
        selected: index == selectedIndex,
        showCheckmark: false,
        selectedColor: const Color(0xffe9ad0c),
        labelStyle: TextStyle(
          color: index == selectedIndex
              ? Colors.white
              : const Color(0xff292620),
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: Color(0xffdfd1b8)),
        onSelected: (_) => onSelected(index),
      ),
    ),
  );
}
