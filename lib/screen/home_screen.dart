import 'package:flutter/material.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/screen/all_destinations_screen.dart';
import 'package:myapp/screen/chatbot_screen.dart';
import 'package:myapp/screen/destination_detail_screen.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/widgets/media_image.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onProfileTap;
  final ValueChanged<int> onExploreDestination;

  const HomeScreen({
    super.key,
    required this.onProfileTap,
    required this.onExploreDestination,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _destinationsFuture;
  late String _loadedLanguage;

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
    final result = await AppServices.destinations.getDestinations(limit: 3);
    if (result['success'] == true && result['data'] is List) {
      return List<Map<String, dynamic>>.from(
        (result['data'] as List).whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    }
    throw Exception(result['message'] ?? 'Failed to load destinations');
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGold = Color(0xFFF4C025);
    const Color lightGold = Color(0xFFFFD54F);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        color: brandGold,
        onRefresh: () async {
          setState(() {
            _destinationsFuture = _loadDestinations();
          });
          await _destinationsFuture;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [brandGold, lightGold],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            const Text(
                              "Go Thai",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: widget.onProfileTap,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white,
                              backgroundImage: mediaImageProvider(
                                AppServices.media
                                        .fullUrl(
                                          AppServices
                                              .auth
                                              .currentUser?['profile_image_url'],
                                        )
                                        .isNotEmpty
                                    ? AppServices.media.fullUrl(
                                        AppServices
                                            .auth
                                            .currentUser?['profile_image_url'],
                                      )
                                    : AppServices.media.defaultAvatarUrl,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.readyToExplore,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: brandGold,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.aiTravelSuite,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFeatureItem(
                              Icons.calendar_month,
                              l10n.planTravel,
                              brandGold,
                            ),
                            _buildFeatureItem(
                              Icons.forum,
                              l10n.chatbot,
                              brandGold,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ChatbotScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildFeatureItem(
                              Icons.document_scanner_outlined,
                              l10n.scanWithAi,
                              brandGold,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ChatbotScreen(
                                      openScannerOnStart: true,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.destinations,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllDestinationsScreen(
                            onExploreDestination: widget.onExploreDestination,
                          ),
                        ),
                      ),
                      child: Text(
                        l10n.seeAll,
                        style: const TextStyle(
                          color: brandGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _destinationsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildDestinationLoadingList();
                  }

                  if (snapshot.hasError) {
                    return _buildDestinationMessage(
                      icon: Icons.cloud_off,
                      title: l10n.couldNotLoadTatDestinations,
                      subtitle: l10n.pullDownTryAgain,
                    );
                  }

                  final destinations = snapshot.data ?? [];
                  if (destinations.isEmpty) {
                    return _buildDestinationMessage(
                      icon: Icons.travel_explore,
                      title: l10n.noDestinationsYet,
                      subtitle: l10n.tatReturnedNoImages,
                    );
                  }

                  return ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      return _buildDestinationCard(
                        destinations[index],
                        brandGold,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationCard(Map<String, dynamic> dest, Color brandGold) {
    final String name = (dest['name'] ?? '').toString().trim();
    final String city = (dest['city'] ?? context.l10n.thailand).toString();
    final String location = (dest['location'] ?? '').toString();
    final String image = (dest['image'] ?? '').toString();
    final int viewer = int.tryParse((dest['viewer'] ?? 0).toString()) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final id = int.tryParse('${dest['id'] ?? ''}');
            if (id == null) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DestinationDetailScreen(
                  destinationId: id,
                  fallbackName: name.isNotEmpty ? name : city,
                  fallbackImageUrl: image,
                  onExploreMap: () => widget.onExploreDestination(id),
                ),
              ),
            );
            if (!mounted) return;
            setState(() {
              _destinationsFuture = _loadDestinations();
            });
          },
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: mediaNetworkImage(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.visibility,
                            color: Colors.black54,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatViewerCount(viewer),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    bottom: 18,
                    right: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: brandGold,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location.isNotEmpty ? location : city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
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
        ),
      ),
    );
  }

  Widget _buildDestinationLoadingList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            height: 200,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.black38, size: 38),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViewerCount(int value) {
    if (value >= 1000000) {
      return context.l10n.viewsCount(
        '${(value / 1000000).toStringAsFixed(1)}M',
      );
    }
    if (value >= 1000) {
      return context.l10n.viewsCount('${(value / 1000).toStringAsFixed(1)}K');
    }
    return context.l10n.viewsCount('$value');
  }

  Widget _buildFeatureItem(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
