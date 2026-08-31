import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/screen/map_picker_screen.dart';
import 'package:myapp/widgets/media_image.dart';

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
  });

  final String title;
  final String province;
  final String note;
  final XFile? pickedImage;
  final LatLng? selectedLocation;
  final bool removeExistingImage;
  final List<String> existingImageUrls;
}

const _sheetGold = Color(0xfff4b400);
const _sheetPaleGold = Color(0xffffefbd);

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
  });

  final String? initialTitle;
  final String? initialProvince;
  final String? initialNote;
  final List<String> initialImageUrls;
  final LatLng? initialLocation;
  final bool isEdit;

  @override
  State<_DiaryManualSheetContent> createState() => _DiaryManualSheetContentState();
}

class _DiaryManualSheetContentState extends State<_DiaryManualSheetContent> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _noteCtrl;

  XFile? _pickedImage;
  LatLng? _selectedLocation;
  bool _removeExistingImage = false;
  late List<String> _existingImageUrls;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _provinceCtrl = TextEditingController(text: widget.initialProvince ?? '');
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
    _selectedLocation = widget.initialLocation;
    _existingImageUrls = List<String>.from(widget.initialImageUrls);
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
    // Use this State's context (stable, owns controllers) instead of an
    // inner StatefulBuilder context. Pushing from StatefulBuilder's
    // innerContext was causing framework.dart:6171 _dependents.isEmpty
    // because inherited dependencies (l10n, MediaQuery) were still tracked.
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => MapPickerScreen(initialLocation: _selectedLocation)),
    );
    if (!mounted) return;
    if (result != null) setState(() => _selectedLocation = result);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPreview = _pickedImage != null ||
        (_existingImageUrls.isNotEmpty && !_removeExistingImage);

    Widget imageSourceCard({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) =>
        InkWell(
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
              widget.isEdit ? context.l10n.editMemory : context.l10n.manualDiaryTitle,
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
                                  child: Center(child: CircularProgressIndicator()),
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
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(context.l10n.capturePhoto,
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(context.l10n.choosePhoto,
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                labelText: context.l10n.placeName,
                hintText: context.l10n.placeNameHint,
                prefixIcon: const Icon(Icons.place_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _provinceCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.provinceVisited,
                hintText: context.l10n.provinceHint,
                prefixIcon: const Icon(Icons.flag_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickLocation,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedLocation != null ? _sheetGold : Colors.grey,
                    width: _selectedLocation != null ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  color: _selectedLocation != null ? _sheetPaleGold : Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(Icons.map_outlined,
                        color: _selectedLocation != null ? _sheetGold : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedLocation != null
                            ? '${context.l10n.selectedLocation}: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                            : context.l10n.selectLocationOnMap,
                        style: TextStyle(
                          color: _selectedLocation != null ? Colors.black87 : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_selectedLocation != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedLocation = null),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.clear, size: 18, color: Colors.black45),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                final result = DiaryManualResult(
                  title: _titleCtrl.text.trim(),
                  province: _provinceCtrl.text.trim(),
                  note: _noteCtrl.text.trim(),
                  pickedImage: _pickedImage,
                  selectedLocation: _selectedLocation,
                  removeExistingImage: _removeExistingImage,
                  existingImageUrls: _existingImageUrls,
                );
                Navigator.pop(context, result);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _sheetGold,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
