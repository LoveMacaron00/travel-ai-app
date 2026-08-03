import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/utils/destination_display.dart';
import 'package:myapp/widgets/media_image.dart';

/// แสดงรายละเอียดจาก schema กลางของ mobile API และยังรองรับข้อมูล TAT รุ่นเก่า
class DestinationDetailScreen extends StatefulWidget {
  final int destinationId;
  final String fallbackName;
  final String fallbackImageUrl;
  final VoidCallback? onExploreMap;

  const DestinationDetailScreen({
    super.key,
    required this.destinationId,
    required this.fallbackName,
    required this.fallbackImageUrl,
    this.onExploreMap,
  });

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  late Future<Map<String, dynamic>> _detailFuture;
  late String _loadedLanguage;
  final PageController _galleryController = PageController();
  int _imageIndex = 0;
  double? _galleryDragStartX;

  @override
  void initState() {
    super.initState();
    _loadedLanguage = AppServices.locale.languageCode;
    _detailFuture = _loadDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (language != _loadedLanguage) {
      _loadedLanguage = language;
      _detailFuture = _loadDetails();
    }
  }

  Future<Map<String, dynamic>> _loadDetails() async {
    final result = await AppServices.destinations.getDestinationDetails(
      widget.destinationId,
    );
    if (result['success'] == true) {
      // ไม่รอ analytics เพื่อให้หน้า detail แสดงได้ทันทีแม้ network ช้า
      unawaited(
        AppServices.activity.recordDestinationView(widget.destinationId),
      );
    }
    return result;
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final detail = snapshot.data?['success'] == true
              ? Map<String, dynamic>.from(snapshot.data!['data'])
              : <String, dynamic>{};
          final name = '${detail['name'] ?? widget.fallbackName}';
          final rawLocation = detail['location'];
          final location = rawLocation is Map
              ? Map<String, dynamic>.from(rawLocation)
              : <String, dynamic>{};
          final address = _firstLocationText([
            location['address'],
            detail['address'],
          ]);
          final province = _firstLocationText([
            location['province'],
            detail['province'],
            context.l10n.thailand,
          ]);
          final district = _firstLocationText([
            location['district'],
            detail['district'],
          ]);
          final subDistrict = _firstLocationText([
            location['subDistrict'],
            detail['sub_district'],
          ]);
          final postcode = _firstLocationText([
            location['postcode'],
            detail['postcode'],
          ]);
          final locationSummary = [
            subDistrict,
            district,
            province,
          ].where((part) => part.isNotEmpty).join(', ');
          final images = collectDestinationImages(
            detail,
            fallback: widget.fallbackImageUrl,
          );
          final description = stripHtmlText('${detail['description'] ?? ''}');
          final hours = formatDestinationOpeningHours(detail);
          final hoursSummary = formatDestinationOpeningTimeSummary(detail);
          final fee = _fee(detail);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 382,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      images.isEmpty
                          ? Container(
                              color: const Color(0xffe9e2d7),
                              child: const Icon(
                                Icons.landscape_outlined,
                                size: 60,
                              ),
                            )
                          : Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (event) =>
                                  _galleryDragStartX = event.position.dx,
                              onPointerUp: (event) {
                                final start = _galleryDragStartX;
                                _galleryDragStartX = null;
                                if (start == null) return;
                                final distance = event.position.dx - start;
                                if (distance.abs() < 48) return;
                                _changeImage(
                                  distance < 0 ? 1 : -1,
                                  images.length,
                                );
                              },
                              onPointerCancel: (_) => _galleryDragStartX = null,
                              child: IgnorePointer(
                                child: PageView.builder(
                                  controller: _galleryController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: images.length,
                                  onPageChanged: (index) =>
                                      setState(() => _imageIndex = index),
                                  itemBuilder: (_, index) => mediaNetworkImage(
                                    images[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xffe9e2d7),
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black38,
                              Colors.transparent,
                              Colors.black87,
                            ],
                            stops: [0, .42, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        top: 44,
                        child: _topButton(
                          Icons.arrow_back,
                          () => Navigator.pop(context),
                        ),
                      ),
                      if (images.length > 1) ...[
                        Positioned(
                          left: 14,
                          top: 155,
                          child: _galleryButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: context.l10n.previousPhoto,
                            onPressed: () => _changeImage(-1, images.length),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          top: 155,
                          child: _galleryButton(
                            icon: Icons.chevron_right_rounded,
                            tooltip: context.l10n.nextPhoto,
                            onPressed: () => _changeImage(1, images.length),
                          ),
                        ),
                      ],
                      if (images.length > 1)
                        Positioned(
                          right: 18,
                          bottom: 30,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${_imageIndex + 1} / ${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 24,
                        right: 76,
                        bottom: 30,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (detail['category'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffe9ad0c),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${detail['category']}'
                                      .replaceAll('_', ' ')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    letterSpacing: .8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 9),
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                height: 1.04,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xffffd55e),
                                  size: 17,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    locationSummary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xfff8f9fa),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 118),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.atAGlance.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xff8b806f),
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _quickFact(
                                Icons.schedule_outlined,
                                context.l10n.hours,
                                hoursSummary.isEmpty
                                    ? context.l10n.checkBeforeVisiting
                                    : hoursSummary,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 46,
                              color: const Color(0xffddd8cf),
                            ),
                            Expanded(
                              child: _quickFact(
                                Icons.confirmation_number_outlined,
                                context.l10n.admission,
                                fee.isEmpty
                                    ? context.l10n.seeOnArrival
                                    : fee.values.first,
                              ),
                            ),
                          ],
                        ),
                        if (detail.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _sectionTitle(
                            Icons.location_on_outlined,
                            context.l10n.locationDetails,
                          ),
                          const SizedBox(height: 10),
                          _locationRow(context.l10n.address, address),
                          _locationRow(context.l10n.subDistrict, subDistrict),
                          _locationRow(context.l10n.district, district),
                          _locationRow(context.l10n.province, province),
                          _locationRow(context.l10n.postcode, postcode),
                        ],
                        if (hours.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _sectionTitle(
                            Icons.schedule_outlined,
                            context.l10n.openingHours,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            hours,
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (fee.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _sectionTitle(
                            Icons.confirmation_number_outlined,
                            context.l10n.admissionFee,
                          ),
                          const SizedBox(height: 10),
                          ...fee.entries.map(
                            (entry) => _feeRow(entry.key, entry.value),
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _sectionTitle(
                            Icons.menu_book_outlined,
                            context.l10n.aboutThisPlace,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Colors.black87,
                              height: 1.55,
                              fontSize: 15,
                            ),
                          ),
                        ],
                        if (snapshot.hasError ||
                            snapshot.data?['success'] == false) ...[
                          const SizedBox(height: 22),
                          Text(
                            context.l10n.detailsUnavailable,
                            style: const TextStyle(color: Colors.black45),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffe9ad0c),
            ),
            onPressed: widget.onExploreMap ?? () => Navigator.pop(context),
            icon: const Icon(Icons.map_outlined),
            label: Text(
              context.l10n.viewOnMap,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topButton(IconData icon, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.all(8),
    child: Material(
      color: Colors.white.withValues(alpha: .92),
      shape: const CircleBorder(),
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
    ),
  );

  Widget _galleryButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) => Material(
    color: Colors.black45,
    shape: const CircleBorder(),
    child: Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        color: Colors.white,
        iconSize: 30,
        icon: Icon(icon),
      ),
    ),
  );

  void _changeImage(int direction, int imageCount) {
    final target = (_imageIndex + direction + imageCount) % imageCount;
    _galleryController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _quickFact(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xffe9ad0c)),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xff8b806f),
            fontSize: 10,
            letterSpacing: .8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 20, color: const Color(0xffe9ad0c)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    ],
  );

  Widget _feeRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _locationRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  String _firstLocationText(List<dynamic> values) {
    for (final value in values) {
      final candidate = value is Map ? value['name'] : value;
      final text = '${candidate ?? ''}'.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Map<String, String> _fee(Map<String, dynamic> detail) {
    final fee = resolveAdmissionFee(detail);
    if (fee == null) return const {};
    final values = <String, String>{};
    final labels = {
      'thaiAdult': context.l10n.thaiAdult,
      'thaiChild': context.l10n.thaiChild,
      'foreignerAdult': context.l10n.foreignerAdult,
      'foreignerChild': context.l10n.foreignerChild,
    };
    for (final entry in labels.entries) {
      final value = fee[entry.key];
      if (value != null && '$value'.isNotEmpty) values[entry.value] = '฿$value';
    }
    final detailText = stripHtmlText('${fee['detail'] ?? ''}');
    if (detailText.isNotEmpty) values[context.l10n.conditions] = detailText;
    return values;
  }
}
