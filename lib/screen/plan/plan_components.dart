part of '../plan_screen.dart';

// UI components และ interaction ย่อยที่ใช้ร่วมกันในหน้าแผน
extension _PlanComponents on _PlanScreenState {
  Widget _costSummary(TravelPlan plan) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffeadcc2)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.estimatedTripCost,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '฿${_money(plan.totalEstimatedCost)}',
              style: const TextStyle(
                color: _gold,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const Divider(height: 26),
        ...plan.budgetBreakdown.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  _title(e.key),
                  style: const TextStyle(color: Colors.black54),
                ),
                const Spacer(),
                Text(
                  '฿${_money(e.value)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.estimateDisclaimer,
          style: const TextStyle(color: Colors.black38, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _section({
    required int number,
    required String title,
    required String subtitle,
    required Widget child,
  }) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffeadcc2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _gold,
              foregroundColor: Colors.white,
              child: Text('$number'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _locationTile() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xfffff6d7),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        const Icon(Icons.my_location, color: _gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.currentGpsLocation,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                _position == null
                    ? (_locating
                          ? context.l10n.findingLocation
                          : context.l10n.locationUnavailable)
                    : '${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(onPressed: _getLocation, icon: const Icon(Icons.refresh)),
      ],
    ),
  );

  Widget _chips(List<String> options, Set<String> selected) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options
        .map(
          (v) => FilterChip(
            label: Text(_interestLabel(v)),
            selected: selected.contains(v),
            selectedColor: const Color(0xffffe7a0),
            checkmarkColor: const Color(0xff986b00),
            onSelected: (on) => _updateState(() {
              if (on) {
                selected.add(v);
              } else {
                selected.remove(v);
              }
            }),
          ),
        )
        .toList(),
  );

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dates,
    );
    if (picked != null) {
      _updateState(() {
        _dates = picked;
        _days = picked.duration.inDays + 1;
      });
    }
  }

  void _showPlacePicker() {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          final filtered = _places
              .where(
                (p) =>
                    (_selectedProvince == null ||
                        p.province == _selectedProvince) &&
                    (query.isEmpty ||
                        p.title.toLowerCase().contains(query.toLowerCase())),
              )
              .take(30)
              .toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .78,
            maxChildSize: .92,
            builder: (_, controller) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    context.l10n.addAPlace,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (v) => setSheet(() => query = v),
                    decoration: _inputDecoration(
                      context.l10n.searchPlacesThailand,
                      Icons.search,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: p.imageUrl.isEmpty
                              ? const SizedBox(
                                  width: 52,
                                  child: Icon(Icons.place),
                                )
                              : mediaNetworkImage(
                                  p.imageUrl,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        title: Text(
                          p.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          p.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.add_circle, color: _gold),
                        onTap: () async {
                          if (!_mustVisit.any((x) => x.id == p.id)) {
                            _mustVisit.add(p);
                          }
                          Navigator.pop(sheetContext);
                          if (_plan != null) {
                            await _generate();
                          } else if (mounted) {
                            _updateState(() {});
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _gold),
        filled: true,
        fillColor: const Color(0xfffbf8f1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xffe6dbc8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xffe6dbc8)),
        ),
      );
  Widget _roundIcon(IconData icon, VoidCallback onTap) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: IconButton(onPressed: onTap, icon: Icon(icon)),
  );
  Widget _stat(String value, String label) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.black45, fontSize: 11),
          ),
        ],
      ),
    ),
  );
  Widget _price(IconData icon, double value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xfff4f0e8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15, color: Colors.black45),
        const SizedBox(width: 5),
        Text('฿${_money(value)}', style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _money(num n) => n.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  String _modeLabel(String value) => switch (value.toLowerCase()) {
    'car' => context.l10n.transportCar,
    'walking' => context.l10n.transportWalking,
    _ => _title(value),
  };

  String _interestLabel(String value) => switch (value) {
    'Food' => context.l10n.interestFood,
    'Cafe' => context.l10n.interestCafe,
    'Nature' => context.l10n.interestNature,
    'Beach' => context.l10n.interestBeach,
    'Temple' => context.l10n.interestTemple,
    'Adventure' => context.l10n.interestAdventure,
    'Shopping' => context.l10n.interestShopping,
    'Nightlife' => context.l10n.interestNightlife,
    'Culture' => context.l10n.interestCulture,
    _ => value,
  };

  String _title(String value) => switch (value.toLowerCase()) {
    'food' => context.l10n.food,
    'transport' => context.l10n.transport,
    'admission' => context.l10n.admission,
    _ =>
      value
          .split(RegExp(r'[_ ]'))
          .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
          .join(' '),
  };
}
