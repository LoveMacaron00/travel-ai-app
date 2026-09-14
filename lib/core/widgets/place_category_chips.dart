import 'package:flutter/material.dart';
import 'package:myapp/core/utils/place_category.dart';
import 'package:myapp/l10n/l10n.dart';

/// แถบตัวกรองหมวดหมู่แนวนอน ใช้ร่วมกันระหว่างหน้าเลือกสถานที่กับดูสถานที่ทั้งหมด
class PlaceCategoryChips extends StatelessWidget {
  const PlaceCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: placeCategoryFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final key = placeCategoryFilters[index];
          final isSelected = selected.toLowerCase() == key;
          final color = placeCategoryColor(key);
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  placeCategoryIcon(key),
                  size: 16,
                  color: isSelected ? Colors.white : color,
                ),
                const SizedBox(width: 6),
                Text(placeCategoryLabel(l10n, key)),
              ],
            ),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: const Color(0xffe9ad0c),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xff292620),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            side: const BorderSide(color: Color(0xffdfd1b8)),
            onSelected: (_) => onSelected(key),
          );
        },
      ),
    );
  }
}
