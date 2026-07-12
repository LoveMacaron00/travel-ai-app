import 'package:flutter/material.dart';
import 'package:myapp/services/api_service.dart';

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
  late final Future<Map<String, dynamic>> _detailFuture;
  final PageController _galleryController = PageController();
  int _imageIndex = 0;
  double? _galleryDragStartX;

  @override
  void initState() {
    super.initState();
    _detailFuture = ApiService.getDestinationDetails(widget.destinationId);
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
          final province = '${detail['province'] ?? 'Thailand'}';
          final images = _images(detail);
          final description = _plainText('${detail['description'] ?? ''}');
          final hours = _openingHours(detail);
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
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: images.length,
                                  onPageChanged: (index) =>
                                      setState(() => _imageIndex = index),
                                  itemBuilder: (_, index) => Image.network(
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
                            tooltip: 'Previous photo',
                            onPressed: () => _changeImage(-1, images.length),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          top: 155,
                          child: _galleryButton(
                            icon: Icons.chevron_right_rounded,
                            tooltip: 'Next photo',
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
                                    province,
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
                        const Text(
                          'AT A GLANCE',
                          style: TextStyle(
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
                                'Hours',
                                hours.isEmpty
                                    ? 'Check before visiting'
                                    : hours.split('\n').first,
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
                                'Admission',
                                fee.isEmpty
                                    ? 'See on arrival'
                                    : fee.values.first,
                              ),
                            ),
                          ],
                        ),
                        if (hours.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _sectionTitle(
                            Icons.schedule_outlined,
                            'Opening hours',
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
                            'Admission fee',
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
                            'About this place',
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
                          const Text(
                            'Some details are unavailable right now.',
                            style: TextStyle(color: Colors.black45),
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
            label: const Text(
              'View on map',
              style: TextStyle(fontWeight: FontWeight.w800),
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

  List<String> _images(Map<String, dynamic> detail) {
    final images = <String>[
      if (widget.fallbackImageUrl.isNotEmpty)
        ApiService.getFullImageUrl(widget.fallbackImageUrl),
    ];
    if (detail['image_url'] != null) {
      images.add(ApiService.getFullImageUrl('${detail['image_url']}'));
    }
    if (detail['images'] is List) {
      for (final image in detail['images'] as List) {
        if (image is Map && image['image_url'] != null) {
          images.add(ApiService.getFullImageUrl('${image['image_url']}'));
        }
      }
    }
    return images.where((image) => image.isNotEmpty).toSet().toList();
  }

  String _openingHours(Map<String, dynamic> detail) {
    final raw = detail['opening_hours'];
    if (raw is List && raw.isNotEmpty) {
      final entries = raw
          .whereType<Map>()
          .map((item) {
            final day = '${item['day'] ?? ''}';
            final open = '${item['open'] ?? item['openTime'] ?? ''}';
            final close = '${item['close'] ?? item['closeTime'] ?? ''}';
            return [
              day,
              if (open.isNotEmpty) open,
              if (close.isNotEmpty) close,
            ].join(' ').trim();
          })
          .where((line) => line.isNotEmpty)
          .toList();
      if (entries.isNotEmpty) return entries.join('\n');
    }
    final open = '${detail['opening_time'] ?? ''}';
    final close = '${detail['closing_time'] ?? ''}';
    return [
      open,
      close,
    ].where((time) => time.isNotEmpty && time != '00:00').join(' – ');
  }

  Map<String, String> _fee(Map<String, dynamic> detail) {
    final directFee = detail['admission_fee'];
    final raw = detail['tat_raw'];
    final nested = raw is Map && raw['information'] is Map
        ? raw['information']['fee']
        : null;
    final fee = directFee is Map && directFee.isNotEmpty
        ? directFee
        : nested is Map
        ? nested
        : raw is Map && raw['fee'] is Map
        ? raw['fee']
        : null;
    if (fee is! Map) return const {};
    final values = <String, String>{};
    const labels = {
      'thaiAdult': 'Thai adult',
      'thaiChild': 'Thai child',
      'foreignerAdult': 'Foreigner adult',
      'foreignerChild': 'Foreigner child',
    };
    for (final entry in labels.entries) {
      final value = fee[entry.key];
      if (value != null && '$value'.isNotEmpty) values[entry.value] = '฿$value';
    }
    final detailText = _plainText('${fee['detail'] ?? ''}');
    if (detailText.isNotEmpty) values['Conditions'] = detailText;
    return values;
  }

  String _plainText(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
