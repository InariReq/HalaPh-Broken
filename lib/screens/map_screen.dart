import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/map_service.dart';
import 'package:halaph/models/destination.dart';

class MapScreen extends StatefulWidget {
  final List<Destination>? destinations;
  final Destination? selectedDestination;

  const MapScreen({super.key, this.destinations, this.selectedDestination});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  LatLng? _userLocation;
  List<Destination> _allDestinations = [];

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Get destinations
      if (widget.destinations != null) {
        _allDestinations = widget.destinations!;
      } else {
        _allDestinations = await DestinationService.getDestinations();
      }

      // Try to get user location
      try {
        final position = await MapService.getCurrentLocation();
        if (position != null) {
          _userLocation = LatLng(position.latitude, position.longitude);
        } else {
          _userLocation = const LatLng(12.8797, 121.7740);
        }
      } catch (e) {
        print('Could not get user location: $e');
        _userLocation = const LatLng(12.8797, 121.7740);
      }

      // Create markers with error handling
      try {
        _markers = MapService.createDestinationMarkers(_allDestinations);
      } catch (e) {
        print('Error creating markers: $e');
        _markers = {}; // Empty markers if creation fails
      }

      // Add user location marker if available
      if (_userLocation != null) {
        try {
          _markers.add(
            Marker(
              markerId: const MarkerId('user_location'),
              position: _userLocation!,
              infoWindow: const InfoWindow(title: 'Your Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
            ),
          );
        } catch (e) {
          print('Error adding user location marker: $e');
        }
      }

      setState(() {
        _isLoading = false;
      });

      // Move camera to show all destinations or selected destination
      _moveCameraToInitialPosition();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error initializing map: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Map initialization failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _moveCameraToInitialPosition() {
    if (_mapController == null) return;

    if (widget.selectedDestination != null) {
      // Move to selected destination
      final coords = MapService.getDestinationCoordinates(
        widget.selectedDestination!,
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(coords, 15.0));
    } else if (_userLocation != null && _allDestinations.isNotEmpty) {
      // Find nearby destinations and show them
      final nearbyDestinations = MapService.findNearbyDestinations(
        _allDestinations,
        _userLocation!,
        50.0, // 50km radius
      );

      if (nearbyDestinations.isNotEmpty) {
        final coords = nearbyDestinations
            .map((dest) => MapService.getDestinationCoordinates(dest))
            .toList();
        _mapController!.animateCamera(MapService.getCameraBounds(coords));
      } else {
        // Show Philippines overview
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(const LatLng(12.8797, 121.7740), 6.0),
        );
      }
    } else {
      // Default to Philippines overview
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(const LatLng(12.8797, 121.7740), 6.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Map View',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_userLocation != null)
            IconButton(
              icon: const Icon(Icons.my_location, color: Colors.black87),
              onPressed: _moveToUserLocation,
            ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black87),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _userLocation ?? const LatLng(12.8797, 121.7740),
                zoom: 6,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _moveCameraToInitialPosition();
              },
              markers: _markers,
              myLocationEnabled: _userLocation != null,
              myLocationButtonEnabled: false,
              compassEnabled: true,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDestinationList,
        icon: const Icon(Icons.list),
        label: const Text('Destinations'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
    );
  }

  void _moveToUserLocation() {
    if (_mapController != null && _userLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 15.0),
      );
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DestinationCategory.values.map((category) {
            return CheckboxListTile(
              title: Text(category.toString().split('.').last),
              value: true, // For now, show all categories
              onChanged: (value) {
                // TODO: Implement filtering logic
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDestinationList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Destinations',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _allDestinations.length,
                  itemBuilder: (context, index) {
                    final destination = _allDestinations[index];
                    final distance = _userLocation != null
                        ? MapService.calculateDistance(
                            _userLocation!,
                            MapService.getDestinationCoordinates(destination),
                          )
                        : null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(destination.imageUrl),
                        ),
                        title: Text(destination.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(destination.location),
                            if (distance != null)
                              Text(
                                '${distance.toStringAsFixed(1)} km away',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.directions),
                        onTap: () {
                          Navigator.of(context).pop();
                          _moveToDestination(destination);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveToDestination(Destination destination) {
    if (_mapController != null) {
      final coords = MapService.getDestinationCoordinates(destination);
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(coords, 15.0));
    }
  }
}
