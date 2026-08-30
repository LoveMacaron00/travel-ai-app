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
  final titleCtrl = TextEditingController(text: initialTitle ?? '');
  final provinceCtrl = TextEditingController(text: initialProvince ?? '');
  final noteCtrl = TextEditingController(text: initialNote ?? '');
  XFile? pickedImage;
  LatLng? selectedLocation = initialLocation;
  bool removeExistingImage = false;
  final existingImageUrls = List<String>.from(initialImageUrls);

  // Keep controllers alive until sheet returns; dispose after.
  return showModalBottomSheet<DiaryManualResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (BuildContext innerContext, StateSetter setSheetState) {
        Future<void> pickImage(ImageSource source) async {
          final picker = ImagePicker();
          final file = await picker.pickImage(
            source: source,
            imageQuality: 84,
            maxWidth: 1600,
          );
          if (file != null) setSheetState(() => pickedImage = file);
        }

        final bool hasPreview = pickedImage != null ||
            (existingImageUrls.isNotEmpty && !removeExistingImage);

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
            MediaQuery.of(innerContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEdit ? innerContext.l10n.editMemory : innerContext.l10n.manualDiaryTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                if (!hasPreview) ...[
                  Row(
                    children: [
                      Expanded(
                        child: imageSourceCard(
                          icon: Icons.photo_camera_outlined,
                          label: innerContext.l10n.takePhoto,
                          onTap: () => pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: imageSourceCard(
                          icon: Icons.photo_library_outlined,
                          label: innerContext.l10n.chooseFromGallery,
                          onTap: () => pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: pickedImage != null
                            ? FutureBuilder<Uint8List>(
                                future: pickedImage!.readAsBytes(),
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
                                  existingImageUrls.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => imageFallback(),
                                ),
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setSheetState(() {
                            if (pickedImage != null) {
                              pickedImage = null;
                            } else {
                              removeExistingImage = true;
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
                          onTap: () => pickImage(ImageSource.camera),
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
                                Text(innerContext.l10n.capturePhoto,
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
                          onTap: () => pickImage(ImageSource.gallery),
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
                                Text(innerContext.l10n.choosePhoto,
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
                  controller: titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: innerContext.l10n.placeName,
                    hintText: innerContext.l10n.placeNameHint,
                    prefixIcon: const Icon(Icons.place_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: provinceCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: innerContext.l10n.provinceVisited,
                    hintText: innerContext.l10n.provinceHint,
                    prefixIcon: const Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final result = await Navigator.push<LatLng>(
                      innerContext,
                      MaterialPageRoute(builder: (_) => MapPickerScreen(initialLocation: selectedLocation)),
                    );
                    if (result != null) setSheetState(() => selectedLocation = result);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedLocation != null ? _sheetGold : Colors.grey,
                        width: selectedLocation != null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      color: selectedLocation != null ? _sheetPaleGold : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.map_outlined,
                            color: selectedLocation != null ? _sheetGold : Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedLocation != null
                                ? '${innerContext.l10n.selectedLocation}: ${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}'
                                : innerContext.l10n.selectLocationOnMap,
                            style: TextStyle(
                              color: selectedLocation != null ? Colors.black87 : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (selectedLocation != null)
                          GestureDetector(
                            onTap: () => setSheetState(() => selectedLocation = null),
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
                  controller: noteCtrl,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: innerContext.l10n.memoryNote,
                    hintText: innerContext.l10n.memoryNoteHint,
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
                      title: titleCtrl.text.trim(),
                      province: provinceCtrl.text.trim(),
                      note: noteCtrl.text.trim(),
                      pickedImage: pickedImage,
                      selectedLocation: selectedLocation,
                      removeExistingImage: removeExistingImage,
                      existingImageUrls: existingImageUrls,
                    );
                    // Dispose after pop via then
                    Navigator.pop(innerContext, result);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _sheetGold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(innerContext.l10n.saveMemory),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ).then((result) {
    // Dispose controllers after sheet closes
    titleCtrl.dispose();
    provinceCtrl.dispose();
    noteCtrl.dispose();
    return result;
  });
}
