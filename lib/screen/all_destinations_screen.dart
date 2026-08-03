import 'package:flutter/material.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/screen/destination_detail_screen.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/widgets/media_image.dart';

class AllDestinationsScreen extends StatefulWidget {
  final ValueChanged<int> onExploreDestination;

  const AllDestinationsScreen({super.key, required this.onExploreDestination});

  @override
  State<AllDestinationsScreen> createState() => _AllDestinationsScreenState();
}

class _AllDestinationsScreenState extends State<AllDestinationsScreen> {
  late Future<List<Map<String, dynamic>>> _destinationsFuture;
  late String _loadedLanguage;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadedLanguage = AppServices.locale.languageCode;
    _destinationsFuture = _loadDestinations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (language != _loadedLanguage) {
      _loadedLanguage = language;
      _destinationsFuture = _loadDestinations();
    }
  }

  Future<List<Map<String, dynamic>>> _loadDestinations() async {
    final result = await AppServices.destinations.getDestinations(
      forceRefresh: true,
    );
    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    throw Exception(result['message'] ?? 'Failed to load destinations');
  }

  Future<void> _refresh() async {
    setState(() => _destinationsFuture = _loadDestinations());
    await _destinationsFuture;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        backgroundColor: const Color(0xfff8f9fa),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.allDestinations,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchDestinationsHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.clearSearch,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _destinationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _message(
                    icon: Icons.cloud_off_outlined,
                    title: l10n.couldNotLoadDestinations,
                    action: FilledButton(
                      onPressed: _refresh,
                      child: Text(l10n.tryAgain),
                    ),
                  );
                }
                final destinations = snapshot.data ?? [];
                if (destinations.isEmpty) {
                  return _message(
                    icon: Icons.travel_explore_outlined,
                    title: l10n.noDestinationsYet,
                  );
                }
                final matches = destinations.where(_matchesSearch).toList();
                if (matches.isEmpty) {
                  return _message(
                    icon: Icons.search_off_rounded,
                    title: l10n.noPlacesFound(_query),
                  );
                }
                return RefreshIndicator(
                  color: const Color(0xffe9ad0c),
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _destinationItem(matches[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(Map<String, dynamic> destination) {
    if (_query.isEmpty) return true;
    final needle = _query.toLowerCase();
    final searchable = [
      destination['name'],
      destination['location'],
      destination['city'],
      destination['province'],
      destination['category'],
    ].whereType<Object>().join(' ').toLowerCase();
    return searchable.contains(needle);
  }

  Widget _message({
    required IconData icon,
    required String title,
    Widget? action,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Colors.black38),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    ),
  );

  Widget _destinationItem(Map<String, dynamic> destination) {
    final id = int.tryParse('${destination['id'] ?? ''}');
    final name = '${destination['name'] ?? context.l10n.destination}';
    final location =
        '${destination['location'] ?? destination['city'] ?? context.l10n.thailand}';
    final image = '${destination['image'] ?? destination['image_url'] ?? ''}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: id == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DestinationDetailScreen(
                    destinationId: id,
                    fallbackName: name,
                    fallbackImageUrl: image,
                    onExploreMap: () => widget.onExploreDestination(id),
                  ),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: mediaNetworkImage(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xffeee8df),
                      child: const Icon(Icons.image_outlined),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xffe9ad0c),
                          size: 17,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
