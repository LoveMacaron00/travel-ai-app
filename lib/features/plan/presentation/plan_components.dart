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
                  style: const TextStyle(
                    color: Color(0xff4a443b),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '฿${_money(e.value)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xff3f3a33),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.estimateDisclaimer,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xff6b6257),
            fontSize: 11,
            height: 1.4,
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
    // โชว์จุดเริ่มที่มีผลกับแผนจริง (ทริปล่วงหน้า/อยู่นอกพื้นที่ GPS จะถูกตัดออก)
    final start = _calcOrigin;
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
  // รถยนต์/เดิน/บัส/รถไฟ/เรือ — ใช้เมื่อ DB ไม่มี icon_url
  IconData _transportFallbackIcon(String keyLower) => switch (keyLower) {
    'car' => Icons.directions_car,
    'walking' || 'walk' => Icons.directions_walk,
    'bus' => Icons.directions_bus,
    'train' => Icons.train,
    'ferry' || 'boat' || 'ship' => Icons.directions_boat,
    'bicycle' || 'bike' || 'cycling' => Icons.directions_bike,
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
          // เลือกได้แบบเดียว — แตะอันไหนใช้อันนั้น (ต้องมี 1 อันเสมอ)
          onSelected: (_) => _updateState(() {
            selected
              ..clear()
              ..add(item.key);
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
    // รายการที่ติ๊กเลือกไว้ (id) — ยังไม่เพิ่มจริงจนกว่าจะกดยืนยัน
    final selectedIds = <String>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _canvas,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => AnimatedBuilder(
          animation: _locationService,
          builder: (context, _) {
            // เรียง/โชว์ระยะเฉพาะเมื่อมีจุดเริ่มที่มีผลกับแผน
            // (ทริปล่วงหน้า/อยู่นอกพื้นที่ — ไม่เรียงตาม GPS ปัจจุบัน)
            final origin = _calcOrigin;
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
                              final isSelected = selectedIds.contains(p.id);
                              final description = stripHtmlText(p.description);
                              final distanceLabel = origin == null
                                  ? null
                                  : _distanceLabel(origin, p);
                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: const Color(0xfffff6d7),
                                selectedColor: Colors.black87,
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
                                        // ติ๊กเลือก/ยกเลิก — ยังไม่เพิ่มจริงจนกว่าจะกดยืนยัน
                                        // รายการซ้ำแจ้งเตือนทันที ไม่ให้ติ๊ก
                                        if (_isPlaceAlreadyPicked(p)) {
                                          _showPlanSnack(
                                            context.l10n.placeAlreadyAdded(
                                              p.title,
                                            ),
                                          );
                                          return;
                                        }
                                        setSheet(() {
                                          if (!selectedIds.remove(p.id)) {
                                            selectedIds.add(p.id);
                                          }
                                        });
                                      },
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.add_circle,
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
                  // แถบยืนยัน — กดทีเดียวเพิ่มทุกที่ที่ติ๊กไว้
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: const Color(
                              0xffeee7da,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () => _confirmSelectedPlaces(
                                  sheetContext,
                                  selectedIds,
                                ),
                          icon: const Icon(Icons.check),
                          label: Text(
                            selectedIds.isEmpty
                                ? context.l10n.addAPlace
                                : '${context.l10n.addAPlace} (${selectedIds.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
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

  // ที่นี้ถูกเลือกไปแล้วหรือยัง — ผลลัพธ์กันซ้ำในวันที่เลือก, ฟอร์มกันซ้ำใน must-visit
  // (เทียบทั้ง id และชื่อ กัน AI/DB เขียนชื่อเพี้ยน)
  bool _isPlaceAlreadyPicked(PlaceMarker p) {
    if (_plan != null) return _isDuplicateInSelectedDay(p);
    return _mustVisit.any(
      (x) => x.id == p.id || _placeKey(x.title) == _placeKey(p.title),
    );
  }

  // ยืนยันรายการที่ติ๊กไว้ — เพิ่มทีเดียวหลายที่พร้อมกัน
  // ฟอร์ม: ลง must-visit / ผลลัพธ์: ลง must-visit + วันที่เลือก (กันซ้ำ + จำกัดจำนวนเหมือนเดิม)
  void _confirmSelectedPlaces(
    BuildContext sheetContext,
    Set<String> selectedIds,
  ) {
    final selected = <PlaceMarker>[];
    for (final id in selectedIds) {
      final match = _places.where((p) => p.id == id).firstOrNull;
      if (match != null) selected.add(match);
    }
    Navigator.pop(sheetContext);
    if (selected.isEmpty || !mounted) return;

    var added = 0;
    var limited = false;
    String lastAddedName = '';
    for (final p in selected) {
      if (_plan != null && _isDuplicateInSelectedDay(p)) continue;
      if (!_mustVisit.any((x) => x.id == p.id)) {
        if (_mustVisit.length >= _PlanScreenState._maxMustVisitPlaces) {
          limited = true;
          continue;
        }
        _mustVisit.add(p);
      }
      if (_plan != null) {
        if (_addStopToSelectedDay(p)) {
          added++;
          lastAddedName = p.title;
        }
      } else {
        added++;
        lastAddedName = p.title;
      }
    }
    if (!mounted) return;
    _updateState(() {});
    if (added == 0) {
      _showPlanSnack(context.l10n.mustVisitLimitReached);
    } else if (added == 1 && !limited) {
      _showPlanSnack(context.l10n.placeAdded(lastAddedName));
    } else {
      _showPlanSnack(context.l10n.placesAdded(added));
    }
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
        Icon(icon, size: 15, color: const Color(0xff6b6257)),
        const SizedBox(width: 5),
        Text(
          '฿${_money(value)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xff3f3a33),
          ),
        ),
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

  // หน่วยนาทีสำหรับโชว์ — เกินชั่วโมงย่อเป็น ชม.
  // (เช่น 120 → "2 ชั่วโมง", 125 → "2 ชั่วโมง 5 นาที" แทนตัวเลขดิบยาว ๆ)
  String _prettyMinutes(int minutes) {
    if (minutes < 60) return '$minutes ${context.l10n.minutesShort}';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return context.l10n.diaryHours(hours);
    return context.l10n.diaryHoursMinutes(hours, rest);
  }

  // กล่องโซ่เวลาของจุดแวะ — แยก 2 บรรทัดให้อ่านง่าย:
  // บรรทัดหลัก: ถึง → เที่ยว → ออก / บรรทัดรอง (ถ้ามีขาเข้า): ออก → เดินทาง → ถึง
  // จุดแรกของวันที่มีขาเข้า (departure→stop0): day start คือ DEPARTURE
  // จึงโชว์ "ออก HH:MM" ต้นทางในบรรทัดรอง (ออก = ถึง − เดินทาง)
  // เที่ยวดึกขึ้นแดงทั้งบรรทัดหลัก — เห็นชัดแบบในภาพ (23:09 / 00:45)
  Widget _stopChainInfo(TravelStop stop, int selectedDayOrder) {
    final lateNight = _isLateNightVisit(stop);
    final visitWord = context.l10n.visitLabel;
    final arrive = stop.arrivalTime;
    final leave =
        _clockFromMinutes(_clockToMinutes(arrive) + stop.durationMinutes);
    final mainLine =
        '${context.l10n.arriveLabel} $arrive · $visitWord '
        '${_prettyMinutes(stop.durationMinutes)} · '
        '${context.l10n.leaveLabel} $leave';
    String? subLine;
    if (stop.segments.isNotEmpty) {
      final leg = stop.segments.first.estimatedMinutes;
      if (selectedDayOrder <= 1) {
        final depart = _clockFromMinutes(_clockToMinutes(arrive) - leg);
        subLine =
            '${context.l10n.leaveLabel} $depart · ${context.l10n.travelLabel} ${_prettyMinutes(leg)}';
      } else {
        subLine = '${context.l10n.travelLabel} ${_prettyMinutes(leg)}';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mainLine,
          style: TextStyle(
            color: lateNight
                ? const Color(0xffb84d36)
                : const Color(0xff5b5347),
            fontSize: 13,
            height: 1.5,
            fontWeight: lateNight ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        if (subLine != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions,
                  size: 13,
                  color: Color(0xff6b6257),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    subLine,
                    style: const TextStyle(
                      color: Color(0xff6b6257),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- เวลาเปิด-ปิด + กันเที่ยวดึก (mirror ฝั่ง server planScheduler) ---
  // ที่เที่ยวต้องถึงก่อน 21:00 / ออกไม่เกิน 22:00
  bool _isLateNightVisit(TravelStop stop) {
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

  // ถึง/ออกอยู่นอกเวลาเปิด-ปิดไหม — ไม่รู้เวลาเปิดถือว่าผ่าน
  bool _isOutsideOpeningHours(TravelStop stop) {
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

  // ชื่อวันแบบย่อสำหรับชิปปิดทำการ ("ส–อา" หรือ "จ,พ,ศ")
  String _openDaysShort(List<int> days) {
    const th = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final names = Localizations.localeOf(context).languageCode == 'th'
        ? th
        : en;
    final sorted = [...days]..sort();
    var contiguous = sorted.length > 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] != sorted[i - 1] + 1) {
        contiguous = false;
        break;
      }
    }
    if (contiguous) {
      return '${names[sorted.first - 1]}–${names[sorted.last - 1]}';
    }
    return sorted.map((d) => names[d - 1]).join(',');
  }

  // ชิปเตือนใต้โซ่เวลา: ปิดทำการวันนี้ (แดง) / เที่ยวดึก (แดง) /
  // อาจปิดแล้ว+เวลาเปิด (ส้ม) / เวลาเปิดเฉย ๆ (เทา)
  // คืน [] ถ้าไม่มีอะไรต้องเตือน — ใช้ทั้งการ์ด (_stopTile) และ bottom sheet
  // dayDate = วันที่จริงของวันนี้ (null = ไม่รู้วัน ข้ามเช็กวันเปิด)
  List<Widget> _timeWarningChips(TravelStop stop, {DateTime? dayDate}) {
    final chips = <Widget>[];
    // ปิดทำการวันนี้ (เช่น ถนนคนเดินเปิดแค่เสาร์-อาทิตย์) — สำคัญสุด
    if (dayDate != null && stop.openDays.isNotEmpty) {
      final clean = stop.openDays.where((d) => d >= 1 && d <= 7).toSet();
      if (clean.isNotEmpty && !clean.contains(dayDate.weekday)) {
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
                const Icon(
                  Icons.block_outlined,
                  size: 13,
                  color: Color(0xffb84d36),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '${context.l10n.closedToday} (${context.l10n.openingHours} ${_openDaysShort(clean.toList())})',
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
    }
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

  String _modeLabel(String value) {
    final keyLower = value.toLowerCase();
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
      'bicycle' || 'bike' || 'cycling' => context.l10n.transportBicycle,
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
