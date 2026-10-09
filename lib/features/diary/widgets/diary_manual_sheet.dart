import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/core/di/app_services.dart';
import 'package:myapp/features/map/presentation/map_picker_screen.dart';
import 'package:myapp/core/widgets/media_image.dart';

/// จังหวัดหนึ่งรายการจาก GET /mobile/provinces/all (77 จังหวัด ไทย/อังกฤษ)
class _DiaryProvince {
  const _DiaryProvince({
    required this.code,
    required this.value,
    required this.label,
    required this.nameTh,
    required this.nameEn,
  });

  factory _DiaryProvince.fromJson(Map<String, dynamic> json) => _DiaryProvince(
    code: '${json['code'] ?? ''}',
    value: '${json['value'] ?? ''}',
    label: '${json['label'] ?? json['value'] ?? ''}',
    nameTh: '${json['nameTh'] ?? json['value'] ?? ''}',
    nameEn: '${json['nameEn'] ?? ''}',
  );

  final String code;
  final String value;
  final String label;
  final String nameTh;
  final String nameEn;

  /// เทียบชื่อที่เก็บไว้เดิม (ไทย/อังกฤษ/code) กับรายการนี้
  bool matches(String text) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) return false;
    return value.toLowerCase() == query ||
        label.toLowerCase() == query ||
        nameTh.toLowerCase() == query ||
        nameEn.toLowerCase() == query ||
        code.toLowerCase() == query;
  }

  bool contains(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return label.toLowerCase().contains(q) ||
        value.toLowerCase().contains(q) ||
        nameTh.toLowerCase().contains(q) ||
        nameEn.toLowerCase().contains(q);
  }

  /// ชื่อสำหรับโชว์ใน dropdown — ไทยหลัก + อังกฤษในวงเล็บ (ถ้ามี)
  String get displayName {
    final other = label == nameTh ? nameEn : nameTh;
    if (other.isEmpty || other == label) return label;
    return '$label ($other)';
  }
}

/// Result from diary manual sheet — unified for add/edit to remove duplication.
/// Previously `_addManualDiary` (129) and `_editManualDiary` (487) duplicated 250+ lines.
class DiaryManualResult {
  const DiaryManualResult({
    required this.title,
    required this.province,
    required this.note,
    required this.pickedImage,
    required this.selectedLocation,
    required this.removeExistingImage,
    required this.existingImageUrls,
    this.entryDate,
  });

  final String title;
  final String province;
  final String note;
  final XFile? pickedImage;
  final LatLng? selectedLocation;
  final bool removeExistingImage;
  final List<String> existingImageUrls;

  /// วันที่ผู้ใช้เลือกจากปฏิทินในฟอร์ม — null = ใช้วันปัจจุบัน (พฤติกรรมเดิม)
  final DateTime? entryDate;
}

const _sheetGold = Color(0xfff4b400);

/// Shows unified manual diary sheet for both add and edit.
/// [entryTitle] is null for add ("New Memory"), otherwise "Edit Memory".
/// Returns null if cancelled.
Future<DiaryManualResult?> showDiaryManualSheet({
  required BuildContext context,
  String? initialTitle,
  String? initialProvince,
  String? initialNote,
  List<String> initialImageUrls = const [],
  LatLng? initialLocation,
  bool isEdit = false,
  // วันที่ตั้งต้นของฟอร์ม — กรอกใหม่จากปฏิทินจะส่งวันที่เลือกมาให้เลย
  DateTime? initialDate,
}) {
  return showModalBottomSheet<DiaryManualResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    // FIX: delegate to a StatefulWidget that owns controllers.
    // Previously controllers were created in this function scope and disposed
    // in `.then(...)` after pop. That caused:
    // 1) "TextEditingController was used after being disposed" when an async
    //    callback (pickImage / map picker) called setSheetState after the sheet
    //    was already popped — rebuild tried to use disposed controllers.
    // 2) Assertion `_dependents.isEmpty` at framework.dart:6171 because
    //    StatefulBuilder's innerContext was used for Navigator.push and for
    //    l10n/MediaQuery dependencies; pushing from that innerContext leaves
    //    InheritedElement dependents alive during deactivate.
    builder: (_) => _DiaryManualSheetContent(
      initialTitle: initialTitle,
      initialProvince: initialProvince,
      initialNote: initialNote,
      initialImageUrls: initialImageUrls,
      initialLocation: initialLocation,
      isEdit: isEdit,
      initialDate: initialDate,
    ),
  );
}

class _DiaryManualSheetContent extends StatefulWidget {
  const _DiaryManualSheetContent({
    required this.initialTitle,
    required this.initialProvince,
    required this.initialNote,
    required this.initialImageUrls,
    required this.initialLocation,
    required this.isEdit,
    this.initialDate,
  });

  final String? initialTitle;
  final String? initialProvince;
  final String? initialNote;
  final List<String> initialImageUrls;
  final LatLng? initialLocation;
  final bool isEdit;
  final DateTime? initialDate;

  @override
  State<_DiaryManualSheetContent> createState() =>
      _DiaryManualSheetContentState();
}

class _DiaryManualSheetContentState extends State<_DiaryManualSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _noteCtrl;

  XFile? _pickedImage;
  LatLng? _selectedLocation;
  bool _removeExistingImage = false;
  late List<String> _existingImageUrls;
  // วันที่ของบันทึก — กรอกใหม่ตั้งจากปฏิทินได้, แก้ไขคงวันเดิม (ไม่แก้)
  DateTime? _entryDate;
  // รายการ 77 จังหวัดจาก server — dropdown ทั่วไป (เลือกได้อย่างเดียว)
  List<_DiaryProvince> _provinces = [];
  _DiaryProvince? _selectedProvince;
  bool _provincesLoaded = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _provinceCtrl = TextEditingController(text: widget.initialProvince ?? '');
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
    _selectedLocation = widget.initialLocation;
    _existingImageUrls = List<String>.from(widget.initialImageUrls);
    _entryDate = widget.initialDate != null
        ? DateUtils.dateOnly(widget.initialDate!)
        : null;
    _loadProvinces();
  }

  // โหลด 77 จังหวัดสำหรับ dropdown — พังเงียบใช้พิมพ์ฟรีแทน (ไม่ block ฟอร์ม)
  Future<void> _loadProvinces() async {
    final rows = await AppServices.diary.getProvinces();
    if (!mounted) return;
    final provinces = rows.map(_DiaryProvince.fromJson).toList();
    setState(() {
      _provinces = provinces;
      _provincesLoaded = true;
      // ค่าเดิมที่เคยบันทึกไว้ (ไทย/อังกฤษ) จับคู่กลับเป็นรายการให้เลย
      final initial = widget.initialProvince?.trim() ?? '';
      // ข้อความที่พิมพ์ค้างในช่องฟรี (กรณีโหลดช้า) ก็จับคู่ด้วย
      final current = _provinceCtrl.text.trim();
      final toMatch = initial.isNotEmpty ? initial : current;
      if (toMatch.isNotEmpty) {
        for (final province in provinces) {
          if (province.matches(toMatch)) {
            _selectedProvince = province;
            break;
          }
        }
      }
    });
  }

  // ชื่อจังหวัดที่จะบันทึก — เลือกจาก dropdown ได้ value มาตรฐาน,
  // โหลดไม่สำเร็จ (fallback พิมพ์ฟรี) ใช้ข้อความเดิม
  String get _provinceInput {
    if (_provinces.isNotEmpty) return _selectedProvince?.value ?? '';
    return _provinceCtrl.text.trim();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _provinceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 84,
      maxWidth: 1600,
    );
    // Guard: sheet may have been dismissed while picker was open.
    // Without this, setState on unmounted StatefulBuilder triggers
    // _dependents.isEmpty assertion and use-after-dispose for controllers.
    if (!mounted) return;
    if (file != null) setState(() => _pickedImage = file);
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(initialLocation: _selectedLocation),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _selectedLocation = result);
  }

  // ปฏิทินเลือกวันที่ของบันทึก — บล็อกวันอนาคต (บันทึกย้อนหลังได้อย่างเดียว)
  Future<void> _pickEntryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate ?? DateUtils.dateOnly(now),
      firstDate: DateTime(2000),
      lastDate: DateUtils.dateOnly(now),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _entryDate = DateUtils.dateOnly(picked));
  }

  // ป้ายวันที่ — ปี พ.ศ. เมื่อภาษาไทย, ค.ศ. เมื่อภาษาอังกฤษ
  // แยกเป็น method เพื่อไม่ให้ Localizations.localeOf อยู่ใน string interpolation
  Widget _entryDateLabel() {
    final picked = _entryDate;
    if (picked == null) {
      return Text(
        context.l10n.diaryPickDate,
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      );
    }
    final year =
        picked.year +
        (Localizations.localeOf(context).languageCode == 'th' ? 543 : 0);
    return Text(
      '${context.l10n.diaryPickDate}: ${picked.day}/${picked.month}/$year',
      style: const TextStyle(color: Colors.black, fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPreview =
        _pickedImage != null ||
        (_existingImageUrls.isNotEmpty && !_removeExistingImage);

    Widget imageSourceCard({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) => InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1E4EA)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF202636), size: 27),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF202636),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    Widget imageFallback() => const ColoredBox(
      color: Color(0xffeeeeee),
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.black26),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isEdit
                  ? context.l10n.editMemory
                  : context.l10n.manualDiaryTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            if (!hasPreview) ...[
              Row(
                children: [
                  Expanded(
                    child: imageSourceCard(
                      icon: Icons.photo_camera_outlined,
                      label: context.l10n.takePhoto,
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: imageSourceCard(
                      icon: Icons.photo_library_outlined,
                      label: context.l10n.chooseFromGallery,
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _pickedImage != null
                        ? FutureBuilder<Uint8List>(
                            future: _pickedImage!.readAsBytes(),
                            builder: (_, snap) {
                              if (!snap.hasData) {
                                return const SizedBox(
                                  height: 180,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return Image.memory(
                                snap.data!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              );
                            },
                          )
                        : SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: mediaNetworkImage(
                              _existingImageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => imageFallback(),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (_pickedImage != null) {
                          _pickedImage = null;
                        } else {
                          _removeExistingImage = true;
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.capturePhoto,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => _pickImage(ImageSource.gallery),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.choosePhoto,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.checkInName,
                hintText: context.l10n.placeNameHint,
                prefixIcon: const Icon(Icons.place_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // จังหวัดที่ไป — dropdown ทั่วไป เลือกจาก 77 จังหวัด
            // โหลดไม่สำเร็จใช้ช่องพิมพ์ฟรีเหมือนเดิม กัน block ฟอร์ม
            if (_provinces.isNotEmpty)
              DropdownButtonFormField<_DiaryProvince>(
                initialValue: _selectedProvince,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.provinceVisited,
                  hintText: context.l10n.provinceHint,
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                hint: Text(context.l10n.provinceHint),
                items: _provinces
                    .map(
                      (province) => DropdownMenuItem<_DiaryProvince>(
                        value: province,
                        child: Text(
                          province.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (province) {
                  setState(() => _selectedProvince = province);
                },
              )
            else
              TextField(
                controller: _provinceCtrl,
                textCapitalization: TextCapitalization.sentences,
                enabled: _provincesLoaded,
                decoration: InputDecoration(
                  labelText: context.l10n.provinceVisited,
                  hintText: _provincesLoaded
                      ? context.l10n.provinceHint
                      : '${context.l10n.provinceHint}...',
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            // วันที่ของบันทึก — กรอกใหม่เท่านั้นที่แก้ได้ ผ่านปฏิทิน (ย้อนหลังได้อย่างเดียว)
            if (!widget.isEdit)
              InkWell(
                onTap: _pickEntryDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _entryDateLabel()),
                      if (_entryDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _entryDate = null),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.clear,
                              size: 18,
                              color: Colors.black45,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickLocation,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedLocation != null
                            ? '${context.l10n.selectedLocation}: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                            : context.l10n.selectLocationOnMap,
                        style: TextStyle(
                          color: _selectedLocation != null
                              ? Colors.black
                              : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_selectedLocation != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedLocation = null),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.clear,
                            size: 18,
                            color: Colors.black45,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.memoryNote,
                hintText: context.l10n.memoryNoteHint,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.edit_outlined),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                final result = DiaryManualResult(
                  title: _titleCtrl.text.trim(),
                  province: _provinceInput,
                  note: _noteCtrl.text.trim(),
                  pickedImage: _pickedImage,
                  selectedLocation: _selectedLocation,
                  removeExistingImage: _removeExistingImage,
                  existingImageUrls: _existingImageUrls,
                  entryDate: _entryDate,
                );
                Navigator.pop(context, result);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _sheetGold,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.save_outlined),
              label: Text(context.l10n.saveMemory),
            ),
          ],
        ),
      ),
    );
  }
}
