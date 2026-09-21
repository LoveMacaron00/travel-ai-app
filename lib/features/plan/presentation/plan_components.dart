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

  // การ์ดขากลับใบเต็มต่อจากการ์ดค่าใช้จ่าย: จากสถานที่ปลายทางกลับจุดเริ่มต้น
  // ตัวเลขตรงจาก planData.returnLeg ฝั่ง server (โหมด/กม./นาที/บาท) ไม่คำนวณซ้ำ
  // ขากลับเครื่องบินมีบรรทัด via ("DMK → HKT") เพิ่ม
  Widget _returnLegCard(TravelReturnLeg leg) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _gold, width: 1.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 15,
          backgroundColor: _gold,
          foregroundColor: _ink,
          child: Icon(Icons.keyboard_return, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.returnTripTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '฿${_money(leg.estimatedCost)}',
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${leg.from} → ${leg.to}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_modeLabel(leg.mode)} · '
                '${leg.distanceKm.toStringAsFixed(1)} ${context.l10n.kmShort} · '
                '${leg.estimatedMinutes} ${context.l10n.minutesShort}',
                style: const TextStyle(color: Colors.black45, fontSize: 12),
              ),
              if (leg.via.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    context.l10n.returnVia(leg.via),
                    style: const TextStyle(
                      color: Colors.black38,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
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

  // ไอคอน fallback รายโหมดให้ตรง [Image 1] หน้า plan option:
  // รถยนต์/เดิน/บัส/รถไฟ/เรือ/เครื่องบิน — ใช้เมื่อ DB ไม่มี icon_url
  IconData _transportFallbackIcon(String keyLower) => switch (keyLower) {
    'car' => Icons.directions_car,
    'walking' || 'walk' => Icons.directions_walk,
    'bus' => Icons.directions_bus,
    'train' => Icons.train,
    'ferry' || 'boat' || 'ship' => Icons.directions_boat,
    'flight' || 'plane' => Icons.flight,
    _ => Icons.route,
  };

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
        final fallbackIcon = _transportFallbackIcon(keyLower);
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
    // ทริปล่วงหน้าเพิ่มสถานที่ได้ตามปกติ — มีแค่ระบบนำทางที่ล็อกจนถึงวันเดินทาง
    if (_mustVisit.length >= _PlanScreenState._maxMustVisitPlaces) {
      _showPlanSnack(context.l10n.mustVisitLimitReached);
      return;
    }

    String query = '';
    String selectedCategory = 'all';
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
                      matchesPlaceCategory(p.category, selectedCategory) &&
                      (query.isEmpty ||
                          p.title.toLowerCase().contains(queryLower) ||
                          p.province.toLowerCase().contains(queryLower)),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      onChanged: (v) => setSheet(() => query = v),
                      decoration: _inputDecoration(
                        context.l10n.searchPlacesThailand,
                        Icons.search,
                      ),
                    ),
                  ),
                  // กรองหมวดหมู่ — ชุดเดียวกับแผนที่ + ดูสถานที่ทั้งหมด
                  PlaceCategoryChips(
                    selected: selectedCategory,
                    onSelected: (key) =>
                        setSheet(() => selectedCategory = key),
                  ),
                  const SizedBox(height: 8),
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

  // ป้ายวันที่ของหัวข้อแต่ละวัน — " · 12/9/2026" หรือ '' ถ้าไม่มีวันเริ่มทริป
  // ทริปใหม่ใช้ช่วงที่เลือกในฟอร์ม (_dates) แผนเก่าจาก Profile ใช้ start_date ที่ server เก็บไว้
  // ไม่มีทั้งคู่ (auto_days เก่า) คืน '' ให้โชว์แค่ "วันที่ N" — ไม่มีวันไหนหาย/ซ้ำกัน
  String _dayDateLabel(TravelPlan plan, int dayNumber) {
    final fromForm = _dates?.start;
    if (fromForm != null) {
      return ' · ${_date(fromForm.add(Duration(days: dayNumber - 1)))}';
    }
    final stored = _parsePlanStartDate(plan.startDate);
    if (stored != null) {
      return ' · ${_date(stored.add(Duration(days: dayNumber - 1)))}';
    }
    return '';
  }

  // "YYYY-MM-DD" จาก trips.start_date → DateTime — ใช้ไม่ได้คืน null (โชว์แค่เลขวัน)
  DateTime? _parsePlanStartDate(String value) {
    final parts = value.trim().split('-');
    if (parts.length < 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2].substring(0, 2));
    if (year == null || month == null || day == null) return null;
    if (year < 2000 || year > 2100 || month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }
  String _money(num n) => n.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );

  // ป้ายโซ่เวลาของจุดแวะ:
  // - ที่เที่ยว: "ถึง HH:MM · เที่ยว N นาที · ออก HH:MM" (+ "· เดินทาง M นาที" ขาเข้า)
  // - จุดพักรายทาง (ปั๊ม/คาเฟ่/osm:/stopType rest): ใช้ "พัก" แทน "เที่ยว"
  // - ที่พักค้างคืน (overnight): "ถึง HH:MM · เช็คอิน" เท่านั้น — ไม่มีเที่ยว/ออก/เดินทางต่อ
  //   (ชิป segments ด้านล่างบอกเวลาเดินทางขาเข้าอยู่แล้ว ใส่ซ้ำท้ายป้ายจะอ่านเหมือนเดินทางต่อ)
  // จุดแรกของวันที่มีขาเข้า (departure→stop0): day start คือ DEPARTURE
  // จึงนำหน้าด้วย "ออก HH:MM · เดินทาง M นาที" (ออก = ถึง − เดินทาง)
  String _stopChainLabel(TravelStop stop, int selectedDayOrder) {
    // ที่พักค้างคืนคือจุดจบของวัน — โชว์แค่เวลาเช็คอิน ไม่คำนวณเวลาออก/เดินทางต่อ
    if (stop.isOvernight) {
      return '${context.l10n.arriveLabel} ${stop.arrivalTime} · ${context.l10n.checkIn}';
    }
    final isRest = stop.isRestStop || stop.stopType.toLowerCase() == 'rest';
    // สนามบิน (transfer) ใช้คำว่า "เปลี่ยนเครื่อง" แทน "พัก" — ยังไม่มี key ใน l10n
    // ใช้ตามภาษาแอปตรงนี้ก่อนเหมือน "พัก"/"rest" (th: เปลี่ยนเครื่อง / en: transfer)
    final isAirport = stop.restType.toLowerCase() == 'airport';
    final visitWord = isAirport
        ? (Localizations.localeOf(context).languageCode == 'th'
              ? 'เปลี่ยนเครื่อง'
              : 'transfer')
        : isRest
        ? (Localizations.localeOf(context).languageCode == 'th'
              ? 'พัก'
              : 'rest')
        : context.l10n.visitLabel;
    final arrive = stop.arrivalTime;
    final leave =
        _clockFromMinutes(_clockToMinutes(arrive) + stop.durationMinutes);
    final visit =
        '${context.l10n.arriveLabel} $arrive · $visitWord '
        '${stop.durationMinutes} ${context.l10n.minutesShort} · '
        '${context.l10n.leaveLabel} $leave';
    if (stop.segments.isEmpty) return visit;
    final leg = stop.segments.first.estimatedMinutes;
    if (selectedDayOrder <= 1) {
      final depart = _clockFromMinutes(_clockToMinutes(arrive) - leg);
      return '${context.l10n.leaveLabel} $depart · '
          '${context.l10n.travelLabel} $leg ${context.l10n.minutesShort} · '
          '$visit';
    }
    return '$visit · ${context.l10n.travelLabel} $leg ${context.l10n.minutesShort}';
  }

  // --- เวลาเปิด-ปิด + กันเที่ยวดึก (mirror ฝั่ง server planScheduler) ---
  // ที่เที่ยวต้องถึงก่อน 21:00 / ออกไม่เกิน 22:00 — ที่พัก overnight / จุดพัก rest ยกเว้น
  bool _isLateNightVisit(TravelStop stop) {
    if (stop.isOvernight || stop.isRestStop) return false;
    if (stop.destinationId.startsWith('osm:')) return false;
    final arrival = _strictClockToMinutes(stop.arrivalTime);
    if (arrival == null) return false;
    final departure = arrival + stop.durationMinutes;
    final arrivalClock = arrival % 1440;
    final departureClock = departure % 1440;
    if (arrivalClock >= 21 * 60) return true;
    if (arrivalClock < 5 * 60) return true;
    if (departureClock > 22 * 60 && departureClock < 12 * 60) return true;
    return false;
  }

  // "HH:MM" แบบเข้ม — แปลงไม่ได้คืน null (ไม่ fallback เป็น startTime กันเตือนมั่ว)
  int? _strictClockToMinutes(String clock) {
    final parts = clock.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1].substring(0, 2));
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  // "08:00"/"9:00 PM"/"08.00" → นาที — "00:00" ถือว่าไม่ระบุ (DB ใช้เป็น unknown)
  int? _flexibleTimeToMinutes(String value) {
    final text = value.trim();
    if (text.isEmpty || text == '00:00' || text == '00:00:00') return null;
    final ampm = RegExp(r'([AP])\.?\s*M\.?', caseSensitive: false).firstMatch(text);
    final match = RegExp(r'(\d{1,2})\s*[:.]\s*(\d{2})').firstMatch(text);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || minute > 59) return null;
    if (ampm != null) {
      final isPm = ampm.group(1)!.toUpperCase() == 'P';
      if (hour < 1 || hour > 12) return null;
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
    } else if (hour > 23) {
      return null;
    }
    if (hour == 0 && minute == 0) return null;
    return hour * 60 + minute;
  }

  // ป้าย "08:00–18:00" หรือ '' ถ้าไม่รู้เวลาเปิด
  String _openingRangeLabel(TravelStop stop) {
    final open = _flexibleTimeToMinutes(stop.openingTime);
    final close = _flexibleTimeToMinutes(stop.closingTime);
    if (open == null || close == null) return '';
    String fmt(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return '${fmt(open)}–${fmt(close)}';
  }

  // ถึง/ออกอยู่นอกเวลาเปิด-ปิดไหม — ไม่รู้เวลาเปิดถือว่าผ่าน, overnight/rest ข้าม
  bool _isOutsideOpeningHours(TravelStop stop) {
    if (stop.isOvernight || stop.isRestStop) return false;
    if (stop.destinationId.startsWith('osm:')) return false;
    final open = _flexibleTimeToMinutes(stop.openingTime);
    final close = _flexibleTimeToMinutes(stop.closingTime);
    if (open == null || close == null) return false;
    final arrival = _strictClockToMinutes(stop.arrivalTime);
    if (arrival == null) return false;
    final departure = arrival + stop.durationMinutes;
    if (close == open) return false;
    bool inOpen(int t) => close < open ? (t >= open || t < close) : (t >= open && t < close);
    final arrivalClock = arrival % 1440;
    final departureClock = departure % 1440;
    if (!inOpen(arrivalClock)) return true;
    if (close < open) {
      return !(inOpen(departureClock) || departureClock <= close + 15);
    }
    return departureClock > close + 15;
  }

  // ชิปเตือนใต้โซ่เวลา: เที่ยวดึก (แดง) / อาจปิดแล้ว+เวลาเปิด (ส้ม) / เวลาเปิดเฉย ๆ (เทา)
  // คืน [] ถ้าไม่มีอะไรต้องเตือน — ใช้ทั้งการ์ด (_stopTile) และ bottom sheet
  List<Widget> _timeWarningChips(TravelStop stop) {
    final chips = <Widget>[];
    if (_isLateNightVisit(stop)) {
      chips.add(
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xfffde2e2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xffe76f51)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bedtime_outlined, size: 13, color: Color(0xffb84d36)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${context.l10n.lateNightTag} · ${context.l10n.arriveLabel} ${stop.arrivalTime} — ${context.l10n.moveToDaytimeHint}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xffb84d36),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return chips;
    }
    final range = _openingRangeLabel(stop);
    if (range.isNotEmpty) {
      if (_isOutsideOpeningHours(stop)) {
        chips.add(
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xfffdeeda),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xfff0b429)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_outlined, size: 13, color: Color(0xff9a5b00)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '${context.l10n.maybeClosedTag} (${context.l10n.openingHours} $range)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff9a5b00),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        chips.add(
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, size: 12, color: Colors.black38),
                const SizedBox(width: 4),
                Text(
                  '${context.l10n.openingHours} $range',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),
        );
      }
    }
    return chips;
  }

  // rentalCar = ขารถเช่าหลังบิน (ธงจาก server) — โชว์ป้าย "รถเช่า" แทน "รถยนต์"
  // เช็กก่อน label DB เพราะ DB ไม่มีโหมดรถเช่า (เป็นความหมายเพิ่มฝั่ง client)
  String _modeLabel(String value, {bool rentalCar = false}) {
    final keyLower = value.toLowerCase();
    if (rentalCar && keyLower == 'car') return context.l10n.transportRentalCar;
    // ใช้ label จาก DB ก่อน (รองรับ mode ใหม่ที่ admin เพิ่ม) แล้วค่อย fallback เป็น l10n
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

  String _title(String value) => switch (value.toLowerCase()) {
    'food' => context.l10n.food,
    'transport' => context.l10n.transport,
    'admission' => context.l10n.admission,
    'activities' => context.l10n.activities,
    'accommodation' || 'hotel' => context.l10n.accommodation,
    _ =>
      value
          .split(RegExp(r'[_ ]'))
          .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
          .join(' '),
  };
}
