part of '../plan_screen.dart';

// Bottom sheet รายละเอียดสถานที่และกติกาแสดงค่าเข้าชม
extension _PlanDetailsView on _PlanScreenState {
  void _showStopDetails(TravelStop stop, int number) {
    final destinationId = int.tryParse(stop.destinationId);
    final detailFuture = destinationId == null
        ? null
        : _loadStopDetails(destinationId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .78,
        maxChildSize: .94,
        minChildSize: .5,
        builder: (context, controller) => FutureBuilder<Map<String, dynamic>>(
          future: detailFuture,
          builder: (context, snapshot) {
            final detail = snapshot.data?['success'] == true
                ? Map<String, dynamic>.from(snapshot.data!['data'])
                : <String, dynamic>{};
            final gallery = _detailImages(detail, stop.imageUrl);
            final description = stripHtmlText(
              '${detail['description'] ?? stop.tip}',
            );
            final admissionDetails = _admissionDetails(detail);
            return Container(
              decoration: const BoxDecoration(
                color: _canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 220,
                    child: gallery.isEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              color: const Color(0xffeee7da),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.landscape, size: 50),
                          )
                        : PageView.builder(
                            itemCount: gallery.length,
                            itemBuilder: (_, index) => ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                gallery[index],
                                headers: AppServices.media.headersFor(
                                  gallery[index],
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xffeee7da),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '$number. ${stop.place}',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stop.arrivalTime} · ${stop.durationMinutes} min · ${_modeLabel(stop.transportMode)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stop.activity,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Estimated cost for this stop',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _detailCostRow(
                    Icons.confirmation_number_outlined,
                    'Admission',
                    stop.entryCost,
                  ),
                  if (admissionDetails.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff4d2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Admission details from TAT',
                            style: TextStyle(
                              color: Color(0xff876100),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          ...admissionDetails.map(
                            (detail) => Text(
                              detail,
                              style: const TextStyle(
                                color: Color(0xff684d0a),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _detailCostRow(
                    Icons.restaurant_outlined,
                    'Food',
                    stop.foodCost,
                  ),
                  _detailCostRow(
                    _PlanScreenState._modeOptions[stop.transportMode] ??
                        Icons.route,
                    'Transport',
                    stop.transportCost,
                  ),
                  const Divider(height: 28),
                  _detailCostRow(
                    Icons.account_balance_wallet_outlined,
                    'Stop total',
                    stop.entryCost + stop.foodCost + stop.transportCost,
                    emphasis: true,
                  ),
                  if (stop.segments.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'Journey details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...stop.segments.map(
                      (segment) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xffffe9a6),
                          foregroundColor: const Color(0xff856000),
                          child: Icon(
                            _PlanScreenState._modeOptions[segment.mode] ??
                                Icons.route,
                          ),
                        ),
                        title: Text(
                          '${_modeLabel(segment.mode)} · ${segment.estimatedMinutes} min',
                        ),
                        subtitle: Text(
                          [
                            segment.from,
                            segment.to,
                          ].where((v) => v.isNotEmpty).join(' → '),
                        ),
                        trailing: Text(
                          '฿${_money(segment.estimatedCost)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _gold),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlanNavigationScreen(destination: stop),
                        ),
                      ),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate to this place'),
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

  Future<Map<String, dynamic>> _loadStopDetails(int destinationId) async {
    final result = await AppServices.destinations.getDestinationDetails(
      destinationId,
    );
    if (result['success'] == true) {
      unawaited(AppServices.activity.recordDestinationView(destinationId));
    }
    return result;
  }

  List<String> _detailImages(Map<String, dynamic> detail, String fallback) {
    return collectDestinationImages(detail, fallback: fallback);
  }

  List<String> _admissionDetails(Map<String, dynamic> detail) {
    final fee = resolveAdmissionFee(detail);
    if (fee == null) return const [];
    return _formatAdmissionFee(fee);
  }

  List<String> _formatAdmissionFee(Map fee) {
    final lines = <String>[];
    if (fee['thaiAdult'] != null) {
      lines.add(
        'Adult: ฿${_money(double.tryParse('${fee['thaiAdult']}') ?? 0)}',
      );
    }
    if (fee['thaiChild'] != null) {
      lines.add(
        'Child: ฿${_money(double.tryParse('${fee['thaiChild']}') ?? 0)}',
      );
    }
    if (fee['foreignerAdult'] != null) {
      lines.add(
        'Foreigner adult: ฿${_money(double.tryParse('${fee['foreignerAdult']}') ?? 0)}',
      );
    }
    if (fee['foreignerChild'] != null) {
      lines.add(
        'Foreigner child: ฿${_money(double.tryParse('${fee['foreignerChild']}') ?? 0)}',
      );
    }
    final detailText = stripHtmlText('${fee['detail'] ?? ''}');
    if (detailText.isNotEmpty) lines.add(detailText);
    return lines;
  }

  Widget _detailCostRow(
    IconData icon,
    String label,
    double cost, {
    bool emphasis = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 18, color: emphasis ? _gold : Colors.black45),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: emphasis ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          '฿${_money(cost)}',
          style: TextStyle(
            fontWeight: emphasis ? FontWeight.w900 : FontWeight.w700,
            color: emphasis ? _gold : _ink,
          ),
        ),
      ],
    ),
  );

  Widget _buildPlanStopMarker(TravelStop stop, int number) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _gold, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.attractions, color: _gold, size: 24),
              Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 128),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _gold),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '$number. ${stop.place}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
