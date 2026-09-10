import 'package:flutter/material.dart';

class ProvinceOption {
  const ProvinceOption({
    required this.value,
    required this.label,
    required this.destinationCount,
  });

  factory ProvinceOption.fromJson(Map<String, dynamic> json) => ProvinceOption(
    value: '${json['value'] ?? ''}'.trim(),
    label: '${json['label'] ?? json['value'] ?? ''}'.trim(),
    destinationCount: int.tryParse('${json['destinationCount'] ?? 0}') ?? 0,
  );

  final String value;
  final String label;
  final int destinationCount;
}

class ProvinceSelector extends StatelessWidget {
  const ProvinceSelector({
    super.key,
    required this.value,
    required this.options,
    required this.loading,
    required this.decoration,
    required this.selectHint,
    required this.loadingHint,
    required this.onChanged,
  });

  final String? value;
  final List<ProvinceOption> options;
  final bool loading;
  final InputDecoration decoration;
  final String selectHint;
  final String loadingHint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const ValueKey('plan-province-selector'),
    child: DropdownButtonFormField<String>(
      key: ValueKey('plan-province-value-${value ?? 'any'}'),
      initialValue: value,
      isExpanded: true,
      decoration: value == null
          ? decoration
          : decoration.copyWith(
              suffixIcon: IconButton(
                key: const ValueKey('clear-plan-province'),
                tooltip: selectHint,
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close),
              ),
            ),
      hint: Text(loading ? loadingHint : selectHint),
      items: options
          .map(
            (province) => DropdownMenuItem<String>(
              value: province.value,
              child: Text(
                '${province.label} (${province.destinationCount})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: loading ? null : onChanged,
    ),
  );
}
