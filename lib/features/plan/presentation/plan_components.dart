part of 'plan_screen.dart';

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
    String? subtitle,
    Widget? trailing,
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
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _locationTile() {
    final start = _startPoint;
    final isCustom = _customStartPoint != null;
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: _pickCustomStart,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xfffff6d7),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              isCustom ? Icons.location_on : Icons.my_location,
              color: _gold,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCustom
                        ? context.l10n.startPointCustom
                        : context.l10n.startPointGps,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    start == null
                        ? (_locating
                              ? context.l10n.findingLocation
                              : context.l10n.locationUnavailable)
                        : '${start.latitude.toStringAsFixed(5)}, ${start.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                  Text(
                    context.l10n.startPointHint,
                    style: const TextStyle(color: Colors.black38, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isCustom)
              IconButton(
                tooltip: context.l10n.startPointCleared,
                onPressed: _clearCustomStart,
                icon: const Icon(Icons.close),
              ),
            IconButton(
              onPressed: _getLocation,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionIcon(String? iconUrl, IconData fallbackIcon) {
    if (iconUrl != null && iconUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 18,
          height: 18,
          child: mediaNetworkImage(
            iconUrl,
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: 17),
          ),
        ),
      );
    }
    return Icon(fallbackIcon, size: 17);
  }

  Widget _interestChips(Set<String> selected) {
    // Single source: DB ผ่าน _dynamicInterests เท่านั้น (ไม่มี fallback hardcode)
    if (_loadingPlanOptions && _dynamicInterests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (_dynamicInterests.isEmpty) {
      return Text(
        context.l10n.noResults,
        style: const TextStyle(color: Colors.black38, fontSize: 13),
      );
    }
    final items = _dynamicInterests;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final keyLower = item.key.toLowerCase();
        final isSelected = selected.any((s) => s.toLowerCase() == keyLower);
        return FilterChip(
          label: Text(item.label),
          selected: isSelected,
          selectedColor: const Color(0xffffe7a0),
          checkmarkColor: const Color(0xff986b00),
          onSelected: (on) => _updateState(() {
            if (on) {
              selected.add(item.key);
            } else {
              selected.removeWhere((s) => s.toLowerCase() == keyLower);
            }
          }),
        );
      }).toList(),
    );
  }

  Widget _transportChips(Set<String> selected) {
    // Single source: DB ผ่าน _dynamicModes เท่านั้น (ไม่มี fallback hardcode)
    if (_loadingPlanOptions && _dynamicModes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (_dynamicModes.isEmpty) {
      return Text(
        context.l10n.noResults,
        style: const TextStyle(color: Colors.black38, fontSize: 13),
      );
    }
    final items = _dynamicModes;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final keyLower = item.key.toLowerCase();
        const fallbackIcon = Icons.route;
        final isSelected = selected.any((s) => s.toLowerCase() == keyLower);
        return FilterChip(
          avatar: _optionIcon(item.iconUrl, fallbackIcon),
          label: Text(item.label),
          selected: isSelected,
          selectedColor: const Color(0xffffe7a0),
          showCheckmark: false,
          onSelected: (v) => _updateState(() {
            if (v) {
              selected.add(item.key);
            } else if (selected.length > 1) {
              selected.removeWhere((s) => s.toLowerCase() == keyLower);
            }
          }),
        );
      }).toList(),
    );
  }

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
        // จำนวนวันมีแหล่งเดียวคือช่วงวันที่ — ยาวเท่าไหร่ส่งเท่านั้น (clamp 1..7)
        _days = (picked.duration.inDays + 1).clamp(1, 7);
      });
    }
  }

  // จุด 2: เลือกเวลาเริ่มออกเดินทางของทุกวัน — default 09:00 ตรงกับ server
  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      _updateState(() => _startTime = picked);
    }
  }

  // แถวจำนวนวันใต้ช่องวันที่ (โหมด manual อย่างเดียว — อ่านอย่างเดียว)
  // โหมด Auto ช่องวันที่แสดง hint อยู่แล้ว จึงคืน shrink กันข้อความซ้ำสองที่
  Widget _daysStepper() {
    if (_autoDays) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.tripLength,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          _dates == null
              ? '– ${context.l10n.days}'
              : '$_days ${context.l10n.days}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ],
    );
  }

  // จุด 3-4: แบนเนอร์เตือนทันทีที่ฟอร์ม เมื่อสถานที่ไกลเกินจำนวนวันที่กำหนด
  // คำนวณคร่าว ๆ ฝั่ง client — คำเตือนจริงมากับผลลัพธ์จาก server อีกที
  Widget _feasibilityBanner() {
    final warning = _feasibilityWarning();
    if (warning == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfffff4d2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffffd76a)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xff9a6b00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              warning,
              style: const TextStyle(
                color: Color(0xff684d0a),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlacePicker() {
    if (_mustVisit.length >= _PlanScreenState._maxMustVisitPlaces) {
      _showPlanSnack(context.l10n.mustVisitLimitReached);
      return;
    }

    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => AnimatedBuilder(
          animation: _locationService,
          builder: (context, _) {
            final origin = _startPoint;
            final queryLower = query.toLowerCase();
            final matches = _places
                .where(
                  (p) =>
                      query.isEmpty ||
                      p.title.toLowerCase().contains(queryLower) ||
                      p.province.toLowerCase().contains(queryLower),
                )
                .toList();
            if (origin != null) {
              matches.sort(
                (a, b) => const Distance()
                    .as(
                      LengthUnit.Kilometer,
                      origin,
                      LatLng(a.latitude, a.longitude),
                    )
                    .compareTo(
                      const Distance().as(
                        LengthUnit.Kilometer,
                        origin,
                        LatLng(b.latitude, b.longitude),
                      ),
                    ),
              );
            }
            final filtered = matches.take(30).toList();
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
                    child: filtered.isEmpty
                        ? ListView(
                            controller: controller,
                            children: [
                              const SizedBox(height: 60),
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.noResults,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black38,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: controller,
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final p = filtered[i];
                              final description = stripHtmlText(p.description);
                              final distanceLabel = origin == null
                                  ? null
                                  : _distanceLabel(origin, p);
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (p.province.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xffffe7a0),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          p.province,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff986b00),
                                          ),
                                        ),
                                      ),
                                    if (description.isNotEmpty)
                                      Text(
                                        description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (distanceLabel != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xfff4f0e8),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          distanceLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        // เคสเพิ่มเข้าวันที่เลือกของแผนที่สร้างแล้ว —
                                        // ต้องกันซ้ำก่อนเสมอ (เทียบทั้ง id และชื่อ)
                                        if (_plan != null &&
                                            _isDuplicateInSelectedDay(p)) {
                                          Navigator.pop(sheetContext);
                                          _showPlanSnack(
                                            context.l10n.placeAlreadyAdded(
                                              p.title,
                                            ),
                                          );
                                          return;
                                        }
                                        // เคสฟอร์ม (ยังไม่มีแผน) — must-visit ซ้ำ
                                        // ก็แจ้งเตือนด้วย ไม่ใช่เงียบ
                                        if (_plan == null &&
                                            _mustVisit.any(
                                              (x) =>
                                                  x.id == p.id ||
                                                  _placeKey(x.title) ==
                                                      _placeKey(p.title),
                                            )) {
                                          Navigator.pop(sheetContext);
                                          _showPlanSnack(
                                            context.l10n.placeAlreadyAdded(
                                              p.title,
                                            ),
                                          );
                                          return;
                                        }
                                        if (!_mustVisit.any(
                                          (x) => x.id == p.id,
                                        )) {
                                          if (_mustVisit.length >=
                                              _PlanScreenState
                                                  ._maxMustVisitPlaces) {
                                            Navigator.pop(sheetContext);
                                            _showPlanSnack(
                                              context
                                                  .l10n
                                                  .mustVisitLimitReached,
                                            );
                                            return;
                                          }
                                          _mustVisit.add(p);
                                        }
                                        Navigator.pop(sheetContext);
                                        if (_plan != null) {
                                          final added = _addStopToSelectedDay(
                                            p,
                                          );
                                          _showPlanSnack(
                                            added
                                                ? context.l10n.placeAdded(
                                                    p.title,
                                                  )
                                                : context.l10n
                                                      .placeAlreadyAdded(
                                                        p.title,
                                                      ),
                                          );
                                        } else if (mounted) {
                                          _updateState(() {});
                                          _showPlanSnack(
                                            context.l10n.placeAdded(p.title),
                                          );
                                        }
                                      },
                                      child: const Icon(
                                        Icons.add_circle,
                                        color: _gold,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  final detailId = int.tryParse(p.id);
                                  if (detailId == null) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DestinationDetailScreen(
                                        destinationId: detailId,
                                        fallbackName: p.title,
                                        fallbackImageUrl: p.imageUrl,
                                      ),
                                    ),
                                  );
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
      ),
    );
  }

  String _distanceLabel(LatLng origin, PlaceMarker place) {
    final meters = const Distance().distance(
      origin,
      LatLng(place.latitude, place.longitude),
    );
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  InputDecoration _inputDecoration(String? label, IconData icon) =>
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

  // Dialog เปลี่ยนชื่อแผนจากหัวข้อหน้าผลลัพธ์ — เปิดจากปุ่มปากกาข้าง _header
  Future<void> _showRenamePlanDialog(TravelPlan plan) async {
    final controller = TextEditingController(text: plan.title);
    final renamed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.renamePlan),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: _PlanScreenState._maxPlanNameLength,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: dialogContext.l10n.planNameHint,
            counterText: '',
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(dialogContext.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (renamed == null) return;
    await _renameCurrentPlan(renamed);
  }
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

  // ป้ายโซ่เวลาของจุดแวะ: "ถึง HH:MM · เที่ยว N นาที · ออก HH:MM"
  // + ถ้ามีขาเข้า (segments) ต่อท้าย "· เดินทาง M นาที" ให้เห็นที่มาของเวลานั้น
  String _stopChainLabel(TravelStop stop, int selectedDayOrder) {
    final arrive = stop.arrivalTime;
    final leave =
        _clockFromMinutes(_clockToMinutes(arrive) + stop.durationMinutes);
    final visit =
        '${context.l10n.arriveLabel} $arrive · ${context.l10n.visitLabel} '
        '${stop.durationMinutes} ${context.l10n.minutesShort} · '
        '${context.l10n.leaveLabel} $leave';
    if (stop.segments.isEmpty || selectedDayOrder <= 1) return visit;
    final leg = stop.segments.first.estimatedMinutes;
    return '$visit · ${context.l10n.travelLabel} $leg ${context.l10n.minutesShort}';
  }
  String _modeLabel(String value) {
    // ใช้ label จาก DB ก่อน (รองรับ mode ใหม่ที่ admin เพิ่ม) แล้วค่อย fallback เป็น l10n
    final keyLower = value.toLowerCase();
    for (final item in _dynamicModes) {
      if (item.key.toLowerCase() == keyLower) return item.label;
    }
    return switch (keyLower) {
      'car' => context.l10n.transportCar,
      'walking' => context.l10n.transportWalking,
      'bus' => context.l10n.transportBus,
      'train' => context.l10n.transportTrain,
      'ferry' => context.l10n.transportFerry,
      'flight' => context.l10n.transportFlight,
      _ => _title(value),
    };
  }

  bool _usesRoadRoute(String mode) =>
      const {'car', 'walking', 'bus'}.contains(mode.toLowerCase());

  Color _routeColor(String mode) => switch (mode.toLowerCase()) {
    'walking' => const Color(0xff6d7278),
    'bus' => const Color(0xff2d7dd2),
    'train' => const Color(0xff7b2cbf),
    'ferry' => const Color(0xff0096c7),
    'flight' => const Color(0xffe76f51),
    _ => _gold,
  };

  Color _routeLabelColor(String mode) => switch (mode.toLowerCase()) {
    'walking' => const Color(0xff4f5459),
    'bus' => const Color(0xff1f5f9f),
    'train' => const Color(0xff61208f),
    'ferry' => const Color(0xff00779e),
    'flight' => const Color(0xffb84d36),
    _ => const Color(0xff7a5800),
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
