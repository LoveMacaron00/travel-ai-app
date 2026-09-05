import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/config/app_config.dart';
import 'package:myapp/l10n/l10n.dart';
import 'package:myapp/model/place_marker.dart';
import 'package:myapp/model/travel_plan.dart';
import 'package:myapp/screen/destination_detail_screen.dart';
import 'package:myapp/screen/plan_navigation_screen.dart';
import 'package:myapp/services/app_services.dart';
import 'package:myapp/services/location_service.dart';
import 'package:myapp/widgets/media_image.dart';

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
  late String _loadedLanguage;

  String _selectedCategory = 'all';
  final List<String> _categories = [
    'all',
    'attraction',
    'accommodation',
    'restaurant',
    'shop',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadedLanguage = AppServices.locale.languageCode;
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
      if (_searchFocus.hasFocus) {
        _updateSearchSuggestions();
      } else {
        if (_showSuggestions) {
          setState(() => _showSuggestions = false);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (language != _loadedLanguage) {
      _loadedLanguage = language;
      _loadDestinations();
    }
  }

  @override
  void dispose() {
    _locationService.removeListener(_onSharedLocationChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
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
    if (_searchFocus.hasFocus) {
      _updateSearchSuggestions();
    }
  }

  void _onSearchChanged() {
    _updateSearchSuggestions();
  }

  void _updateSearchSuggestions() {
    if (!mounted) return;
    final query = _searchController.text.trim().toLowerCase();
    // ถ้า query ว่างแต่ focus อยู่ ให้โชว์ 5 ที่ใกล้ที่สุด (ตามรูปที่ขอ)
    if (query.isEmpty) {
      if (!_searchFocus.hasFocus) {
        if (_showSuggestions || _suggestions.isNotEmpty) {
          setState(() {
            _suggestions = [];
            _showSuggestions = false;
          });
        }
        return;
      }
      // โชว์ 5 แนะนำใกล้สุด
      List<PlaceMarker> nearest = List<PlaceMarker>.from(_places);
      if (_currentPosition != null && nearest.isNotEmpty) {
        const d = Distance();
        nearest.sort((a, b) {
          final da = d.as(
            LengthUnit.Kilometer,
            _currentPosition!,
            LatLng(a.latitude, a.longitude),
          );
          final db = d.as(
            LengthUnit.Kilometer,
            _currentPosition!,
            LatLng(b.latitude, b.longitude),
          );
          return da.compareTo(db);
        });
      }
      final newSuggestions = nearest.take(5).toList();
      final show = newSuggestions.isNotEmpty;
      if (_suggestions.length == newSuggestions.length &&
          _showSuggestions == show &&
          _suggestions.every((e) => newSuggestions.contains(e))) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _suggestions = newSuggestions;
        _showSuggestions = show;
      });
      return;
    }
    final matched = _places.where((p) {
      return p.title.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
    }).toList();
    // เรียงใกล้สุดก่อนเมื่อมีตำแหน่งปัจจุบัน
    if (_currentPosition != null) {
      const d = Distance();
      matched.sort((a, b) {
        final da = d.as(
          LengthUnit.Kilometer,
          _currentPosition!,
          LatLng(a.latitude, a.longitude),
        );
        final db = d.as(
          LengthUnit.Kilometer,
          _currentPosition!,
          LatLng(b.latitude, b.longitude),
        );
        return da.compareTo(db);
      });
    }
    final newSuggestions = matched.take(5).toList();
    final show = matched.isNotEmpty && _searchFocus.hasFocus;
    if (_suggestions.length == newSuggestions.length &&
        _showSuggestions == show &&
        _suggestions.every((e) => newSuggestions.contains(e))) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _suggestions = newSuggestions;
      _showSuggestions = show;
    });
  }

  void _applyFilters() {
    if (!mounted) return;
    final byCategory = _selectedCategory == 'all'
        ? List<PlaceMarker>.from(_places)
        : _places
              .where(
                (p) => p.category.toLowerCase() == _selectedCategory.toLowerCase(),
              )
              .toList();
    final query = _searchController.text.trim().toLowerCase();
    List<PlaceMarker> newSuggestions = [];
    bool show = false;
    if (_searchFocus.hasFocus) {
      List<PlaceMarker> source;
      if (query.isNotEmpty) {
        source = _places.where((p) {
          return p.title.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query) ||
              p.category.toLowerCase().contains(query);
        }).toList();
      } else {
        // โฟกัสแต่ยังไม่พิมพ์ → โชว์ 5 ใกล้สุด
        source = List<PlaceMarker>.from(_places);
      }
      if (_currentPosition != null && source.isNotEmpty) {
        const d = Distance();
        source.sort((a, b) {
          final da = d.as(
            LengthUnit.Kilometer,
            _currentPosition!,
            LatLng(a.latitude, a.longitude),
          );
          final db = d.as(
            LengthUnit.Kilometer,
            _currentPosition!,
            LatLng(b.latitude, b.longitude),
          );
          return da.compareTo(db);
        });
      }
      if (query.isNotEmpty) {
        newSuggestions = source.take(5).toList();
        show = source.isNotEmpty;
      } else {
        newSuggestions = source.take(5).toList();
        show = newSuggestions.isNotEmpty;
      }
    }
    if (!mounted) return;
    setState(() {
      _filteredPlaces = byCategory;
      _suggestions = newSuggestions;
      _showSuggestions = show;
    });
  }

  void _selectSuggestion(PlaceMarker place) {
    // กัน listener เด้งแล้วโชว์ suggestions ซ้ำ
    _searchController.removeListener(_onSearchChanged);
    _searchController.text = place.title;
    _searchController.addListener(_onSearchChanged);
    _searchFocus.unfocus();

    // สถานที่ที่เลือกต้องมี mark บนแผนที่เสมอ แม้กำลังกรองหมวดหมู่ค้างไว้อยู่
    final markerVisible = _filteredPlaces.any((p) => p.id == place.id);
    setState(() {
      if (!markerVisible) {
        _selectedCategory = 'all';
        _filteredPlaces = List.from(_places);
      }
      _suggestions = [];
      _showSuggestions = false;
      _selectedMarker = place;
    });

    // ย้ายกล้องหลังเฟรมถัดไปให้ marker layer พร้อมก่อน — แพทเทิร์นเดียวกับ showDestination
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(LatLng(place.latitude, place.longitude), 16.0);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _selectedMarker = null;
    });
  }

  Future<void> _loadDestinations() async {
    final requestedLanguage = AppServices.locale.languageCode;
    try {
      final result = await AppServices.destinations.getDestinations();
      if (!mounted || requestedLanguage != AppServices.locale.languageCode) {
        return;
      }
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
          if (lat.isNaN || lng.isNaN || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
            continue;
          }

          fetchedPlaces.add(
            PlaceMarker(
              id: item['id']?.toString() ?? i.toString(),
              title:
                  item['name']?.toString() ??
                  item['city']?.toString() ??
                  context.l10n.unknownPlace,
              description:
                  item['location']?.toString() ??
                  context.l10n.beautifulThailandDestination,
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
          if (_searchFocus.hasFocus) {
            _updateSearchSuggestions();
          }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.gpsUnavailable)));
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
        return context.l10n.categoryAll;
      case 'attraction':
        return context.l10n.categoryAttraction;
      case 'accommodation':
        return context.l10n.categoryAccommodation;
      case 'restaurant':
        return context.l10n.categoryRestaurant;
      case 'shop':
        return context.l10n.categoryShop;
      case 'other':
        return context.l10n.categoryOther;
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

  String _distanceText(PlaceMarker place) {
    final pos = _currentPosition;
    if (pos == null) return '';
    // กันพิกัดเพี้ยน
    if (place.latitude.isNaN ||
        place.longitude.isNaN ||
        place.latitude < -90 ||
        place.latitude > 90 ||
        place.longitude < -180 ||
        place.longitude > 180) {
      return '';
    }
    final km = const Distance().as(
      LengthUnit.Kilometer,
      pos,
      LatLng(place.latitude, place.longitude),
    );
    if (km.isNaN || km.isInfinite) return '';
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
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
