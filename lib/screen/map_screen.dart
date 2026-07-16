import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/model/place_marker.dart';
import 'package:myapp/model/travel_plan.dart';
import 'package:myapp/screen/destination_detail_screen.dart';
import 'package:myapp/screen/plan_navigation_screen.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/services/location_service.dart';

part 'map/map_view.dart';

/// แผนที่รวมสถานที่จาก backend, ตำแหน่งผู้ใช้ และเส้นทาง OSRM
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

  // extension view เรียกผ่าน wrapper นี้แทน protected State.setState โดยตรง
  void _updateState(VoidCallback update) => setState(update);

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
      final result = await AppServices.destinations.getDestinations();
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
                  ? AppServices.media.fullUrl(item['image'].toString())
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
  Widget build(BuildContext context) => _buildMapView(context);
}
