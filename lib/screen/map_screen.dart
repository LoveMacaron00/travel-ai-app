import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:myapp/model/place_marker.dart';
import 'package:myapp/services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  PlaceMarker? _selectedMarker;
  bool _isLocating = false;

  List<PlaceMarker> _places = [];
  bool _isLoadingPlaces = true;

  @override
  void initState() {
    super.initState();
    // Default center to Bangkok if location is not fetched yet
    _currentPosition = const LatLng(13.7563, 100.5018); 
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    try {
      final result = await ApiService.getPopularDestinations();
      if (result['success'] == true && result['data'] is List) {
        final List<dynamic> data = result['data'];
        List<PlaceMarker> fetchedPlaces = [];
        for (var i = 0; i < data.length; i++) {
          var item = data[i];
          
          if (item['latitude'] == null || item['longitude'] == null || item['latitude'].toString().trim().isEmpty || item['longitude'].toString().trim().isEmpty) {
            continue;
          }

          double? lat = double.tryParse(item['latitude'].toString());
          double? lng = double.tryParse(item['longitude'].toString());
          
          if (lat == null || lng == null) {
            continue;
          }
          
          fetchedPlaces.add(
            PlaceMarker(
              id: item['id']?.toString() ?? i.toString(),
              title: item['name']?.toString() ?? item['city']?.toString() ?? 'Unknown Place',
              description: item['location']?.toString() ?? 'Beautiful destination in Thailand.',
              latitude: lat,
              longitude: lng,
              imageUrl: item['image'] != null ? ApiService.getFullImageUrl(item['image'].toString()) : 'https://images.unsplash.com/photo-1572076046187-57500d0fdb29?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
              category: item['category']?.toString() ?? 'Temple', 
            )
          );
        }
        if (mounted) {
          setState(() {
            _places = fetchedPlaces;
            _isLoadingPlaces = false;
          });
        }
      } else {
        if (mounted) setState(() { _isLoadingPlaces = false; });
      }
    } catch (e) {
      debugPrint('Error loading destinations: $e');
      if (mounted) setState(() { _isLoadingPlaces = false; });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    var status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _mapController.move(_currentPosition!, 15.0);
        });
      } catch (e) {
        debugPrint("Error getting location: $e");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
    }

    setState(() {
      _isLocating = false;
    });
  }

  void _zoomIn() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
  }

  void _resetRotation() {
    _mapController.rotate(0.0);
  }

  Widget _buildMarkerIcon(PlaceMarker place) {
    IconData iconData;
    Color iconColor;

    switch (place.category) {
      case 'Palace':
        iconData = Icons.account_balance;
        iconColor = const Color(0xFFF4C025); // brandGold
        break;
      case 'Temple':
        iconData = Icons.temple_buddhist;
        iconColor = Colors.redAccent;
        break;
      case 'Historic':
        iconData = Icons.castle;
        iconColor = Colors.brown;
        break;
      default:
        iconData = Icons.place;
        iconColor = Colors.blue;
    }

    bool isSelected = _selectedMarker?.id == place.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMarker = place;
        });
        _mapController.move(LatLng(place.latitude, place.longitude), 16.0);
      },
      child: Column(
        children: [
          Icon(
            iconData,
            color: isSelected ? Colors.amber : iconColor,
            size: isSelected ? 48 : 36,
          ),
          if (isSelected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
              ),
              child: Text(
                place.title,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(13.7500, 100.4913),
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedMarker = null; // Dismiss card on map tap
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.myapp',
              ),
              MarkerLayer(
                markers: _places.map((place) {
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
                          color: Colors.blue.withOpacity(0.3),
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

          // Search Bar
          Positioned(
            top: 50.0,
            left: 16.0,
            right: 16.0,
            child: Container(
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
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search for tourist attractions.',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.orangeAccent),
                  suffixIcon: Icon(Icons.auto_awesome, color: Colors.orangeAccent),
                ),
              ),
            ),
          ),

          // Map Controls
          Positioned(
            right: 16.0,
            bottom: _selectedMarker != null ? 180.0 : 100.0,
            child: Column(
              children: [
                // Zoom Controls
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4.0)],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _zoomIn,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      const Divider(height: 1, indent: 8, endIndent: 8),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: _zoomOut,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Compass
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4.0)],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.explore),
                    onPressed: _resetRotation,
                  ),
                ),
                const SizedBox(height: 16),
                // Location Toggle (GPS)
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4.0)],
                  ),
                  child: IconButton(
                    icon: _isLocating 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, color: Colors.orangeAccent),
                    onPressed: _getCurrentLocation,
                  ),
                ),
              ],
            ),
          ),

          // Info Card
          if (_selectedMarker != null)
            Positioned(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
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
                              Container(width: 80, height: 80, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                const Text(
                                  '0.5 km', // Mock distance
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              _selectedMarker!.description,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13.0,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
