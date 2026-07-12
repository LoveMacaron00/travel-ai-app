import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/model/place_marker.dart';
import 'package:myapp/model/travel_plan.dart';
import 'package:myapp/screen/destination_detail_screen.dart';
import 'package:myapp/screen/plan_navigation_screen.dart';
import 'package:myapp/services/api_service.dart';
import 'package:myapp/services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService.instance;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  LatLng? _currentPosition;
  PlaceMarker? _selectedMarker;
  bool _isLocating = false;

  List<PlaceMarker> _places = [];
  List<PlaceMarker> _filteredPlaces = [];
  List<PlaceMarker> _suggestions = [];
  bool _showSuggestions = false;
  String? _pendingDestinationId;

  String _selectedCategory = 'all';
  final List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'ทุกหมวดหมู่'},
    {'id': 'attraction', 'label': 'สถานที่ท่องเที่ยว'},
    {'id': 'accommodation', 'label': 'ที่พัก'},
    {'id': 'restaurant', 'label': 'ร้านอาหาร'},
    {'id': 'shop', 'label': 'ร้านค้า'},
    {'id': 'other', 'label': 'อื่นๆ'},
  ];

  @override
  void initState() {
    super.initState();
    _currentPosition = _locationService.currentPosition;
    _locationService.addListener(_onSharedLocationChanged);
    _loadDestinations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPosition == null) {
        _getCurrentLocation();
      }
    });

    _searchController.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _locationService.removeListener(_onSharedLocationChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSharedLocationChanged() {
    if (!mounted) return;
    final previousPosition = _currentPosition;
    final nextPosition = _locationService.currentPosition;
    setState(() {
      _currentPosition = nextPosition;
      _isLocating = _locationService.isLoading;
    });
    if (nextPosition != null && nextPosition != previousPosition) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(nextPosition, 15.0);
      });
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final matched = _places.where((p) {
      final matchesQuery =
          query.isEmpty ||
          p.title.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query) ||
          _getCategoryLabel(p.category).toLowerCase().contains(query);

      final matchesCategory =
          _selectedCategory == 'all' ||
          p.category.toLowerCase() == _selectedCategory.toLowerCase();

      return matchesQuery && matchesCategory;
    }).toList();

    setState(() {
      if (query.isNotEmpty) {
        _suggestions = matched.take(5).toList();
        _showSuggestions = matched.isNotEmpty;
      } else {
        _suggestions = [];
        _showSuggestions = false;
      }
      _filteredPlaces = matched;
    });
  }

  void _selectSuggestion(PlaceMarker place) {
    _searchController.text = place.title;
    _searchFocus.unfocus();
    setState(() {
      _showSuggestions = false;
      _selectedMarker = place;
      _filteredPlaces = [place];
    });
    _mapController.move(LatLng(place.latitude, place.longitude), 16.0);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _selectedMarker = null;
    });
    _applyFilters();
  }

  Future<void> _loadDestinations() async {
    try {
      final result = await ApiService.getDestinations();
      if (result['success'] == true && result['data'] is List) {
        final List<dynamic> data = result['data'];
        List<PlaceMarker> fetchedPlaces = [];
        for (var i = 0; i < data.length; i++) {
          var item = data[i];
          if (item['latitude'] == null ||
              item['longitude'] == null ||
              item['latitude'].toString().trim().isEmpty ||
              item['longitude'].toString().trim().isEmpty) {
            continue;
          }
          double? lat = double.tryParse(item['latitude'].toString());
          double? lng = double.tryParse(item['longitude'].toString());
          if (lat == null || lng == null) continue;

          fetchedPlaces.add(
            PlaceMarker(
              id: item['id']?.toString() ?? i.toString(),
              title:
                  item['name']?.toString() ??
                  item['city']?.toString() ??
                  'Unknown Place',
              description:
                  item['location']?.toString() ??
                  'Beautiful destination in Thailand.',
              latitude: lat,
              longitude: lng,
              imageUrl: item['image'] != null
                  ? ApiService.getFullImageUrl(item['image'].toString())
                  : 'https://images.unsplash.com/photo-1572076046187-57500d0fdb29?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
              category: item['category']?.toString() ?? 'other',
            ),
          );
        }
        if (mounted) {
          setState(() {
            _places = fetchedPlaces;
            _filteredPlaces = List.from(fetchedPlaces);
          });
          if (_pendingDestinationId != null) {
            showDestination(int.tryParse(_pendingDestinationId!) ?? -1);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading destinations: $e');
    }
  }

  void showDestination(int destinationId) {
    PlaceMarker? place;
    for (final item in _places) {
      if (item.id == destinationId.toString()) {
        place = item;
        break;
      }
    }
    if (place == null) {
      _pendingDestinationId = destinationId.toString();
      return;
    }
    final selectedPlace = place;
    _pendingDestinationId = null;
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _selectedCategory = 'all';
      _selectedMarker = selectedPlace;
      _filteredPlaces = List.from(_places);
      _suggestions = [];
      _showSuggestions = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(
          LatLng(selectedPlace.latitude, selectedPlace.longitude),
          16.0,
        );
      }
    });
  }

  void _navigateTo(PlaceMarker place) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanNavigationScreen(
          destination: TravelStop(
            destinationId: place.id,
            place: place.title,
            activity: place.description,
            latitude: place.latitude,
            longitude: place.longitude,
            imageUrl: place.imageUrl,
            arrivalTime: '',
            durationMinutes: 0,
            entryCost: 0,
            foodCost: 0,
            transportMode: 'car',
            transportCost: 0,
            tip: '',
            segments: const [],
          ),
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    if (_isLocating) return;
    final position = await _locationService.refresh(
      openSettingsWhenDenied: true,
    );
    if (!mounted) return;
    if (position != null) {
      _mapController.move(position, 15.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to get your GPS location. Check location settings and permission.',
          ),
        ),
      );
    }
  }

  void _zoomIn() => _mapController.move(
    _mapController.camera.center,
    _mapController.camera.zoom + 1,
  );

  void _zoomOut() => _mapController.move(
    _mapController.camera.center,
    _mapController.camera.zoom - 1,
  );

  void _resetRotation() => _mapController.rotate(0.0);

  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return 'ทุกหมวดหมู่';
      case 'attraction':
        return 'สถานที่ท่องเที่ยว';
      case 'accommodation':
        return 'ที่พัก';
      case 'restaurant':
        return 'ร้านอาหาร';
      case 'shop':
        return 'ร้านค้า';
      case 'other':
        return 'อื่นๆ';
      default:
        return category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Colors.grey.shade700;
      case 'attraction':
        return Colors.redAccent;
      case 'accommodation':
        return Colors.blueAccent;
      case 'restaurant':
        return Colors.orange;
      case 'shop':
        return Colors.green;
      case 'other':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.apps;
      case 'attraction':
        return Icons.attractions;
      case 'accommodation':
        return Icons.hotel;
      case 'restaurant':
        return Icons.restaurant;
      case 'shop':
        return Icons.shopping_bag;
      case 'other':
        return Icons.category;
      default:
        return Icons.place;
    }
  }

  Widget _buildMarkerIcon(PlaceMarker place) {
    final iconColor = _getCategoryColor(place.category);
    final iconData = _getCategoryIcon(place.category);
    final isSelected = _selectedMarker?.id == place.id;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedMarker = place);
        _mapController.move(LatLng(place.latitude, place.longitude), 16.0);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.orange : iconColor,
                width: isSelected ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              iconData,
              color: isSelected ? Colors.orange : iconColor,
              size: isSelected ? 24 : 20,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                place.title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── MAP ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _currentPosition ?? const LatLng(13.7500, 100.4913),
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                _searchFocus.unfocus();
                setState(() {
                  _selectedMarker = null;
                  _showSuggestions = false;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.myapp',
              ),
              MarkerLayer(
                markers: _filteredPlaces.map((place) {
                  return Marker(
                    width: 80.0,
                    height: 80.0,
                    point: LatLng(place.latitude, place.longitude),
                    child: _buildMarkerIcon(place),
                  );
                }).toList(),
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40.0,
                      height: 40.0,
                      point: _currentPosition!,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 15.0,
                            height: 15.0,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // ── SEARCH BAR + SUGGESTIONS ──
          Positioned(
            top: 50.0,
            left: 16.0,
            right: 16.0,
            child: Column(
              children: [
                // Search Input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10.0,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: 'Search for tourist attractions.',
                      border: InputBorder.none,
                      icon: const Icon(
                        Icons.search,
                        color: Colors.orangeAccent,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: _clearSearch,
                            )
                          : const Icon(
                              Icons.auto_awesome,
                              color: Colors.orangeAccent,
                            ),
                    ),
                  ),
                ),

                // Categories
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat['id'];
                      final catId = cat['id']!;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(catId),
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : _getCategoryColor(catId),
                              ),
                              const SizedBox(width: 6),
                              Text(cat['label']!),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedCategory = catId;
                              _selectedMarker = null;
                              _applyFilters();
                            });
                          },
                          selectedColor: Colors.orange,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.orange
                                  : Colors.grey.shade300,
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    },
                  ),
                ),

                // Suggestions Dropdown
                if (_showSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10.0,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (context, index) {
                          final place = _suggestions[index];
                          final catColor = _getCategoryColor(place.category);
                          final catIcon = _getCategoryIcon(place.category);
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 2.0,
                            ),
                            minLeadingWidth: 36,
                            leading: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(catIcon, color: catColor, size: 17),
                            ),
                            title: Text(
                              place.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              place.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            onTap: () => _selectSuggestion(place),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── MAP CONTROLS ──
          Positioned(
            right: 16.0,
            bottom: _selectedMarker != null ? 180.0 : 100.0,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4.0),
                    ],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _zoomIn,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      const Divider(height: 1, indent: 8, endIndent: 8),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: _zoomOut,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4.0),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.explore),
                    onPressed: _resetRotation,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4.0),
                    ],
                  ),
                  child: IconButton(
                    icon: _isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.my_location,
                            color: Colors.orangeAccent,
                          ),
                    onPressed: _getCurrentLocation,
                  ),
                ),
              ],
            ),
          ),

          // ── INFO CARD ──
          if (_selectedMarker != null)
            Positioned(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final place = _selectedMarker!;
                    final id = int.tryParse(place.id);
                    if (id == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DestinationDetailScreen(
                          destinationId: id,
                          fallbackName: place.title,
                          fallbackImageUrl: place.imageUrl,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 8.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.network(
                              _selectedMarker!.imageUrl,
                              width: 80.0,
                              height: 80.0,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey.shade300,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.white,
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedMarker!.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _selectedMarker = null,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getCategoryLabel(
                                      _selectedMarker!.category,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6.0),
                                Text(
                                  _selectedMarker!.description,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13.0,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xffe9ad0c),
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () =>
                                        _navigateTo(_selectedMarker!),
                                    icon: const Icon(
                                      Icons.navigation_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Navigate',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
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
            ),
        ],
      ),
    );
  }
}
