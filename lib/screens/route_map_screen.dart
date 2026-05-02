import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/utils/map_utils.dart';

class RouteMapScreen extends StatefulWidget {
  final TravelMode mode;
  final String modeName;
  final LatLng origin;
  final LatLng destination;
  final String polyline;
  final List<Map<String, dynamic>> steps;
  final double fare;

  const RouteMapScreen({
    super.key,
    required this.mode,
    required this.modeName,
    required this.origin,
    required this.destination,
    required this.polyline,
    required this.steps,
    required this.fare,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  void _setupMap() {
    // Add markers for origin and destination
    _markers = {
      Marker(
        markerId: const MarkerId('origin'),
        position: widget.origin,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: widget.destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination'),
      ),
    };

    // Add polyline if available
    if (widget.polyline.isNotEmpty) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: MapUtils.decodePolyline(widget.polyline),
          color: _getModeColor(),
          width: 5,
        ),
      };
    }
  }

  // Polyline decoding moved to MapUtils (MapUtils.decodePolyline)

  Color _getModeColor() {
    switch (widget.mode) {
      case TravelMode.jeepney:
        return Colors.orange;
      case TravelMode.bus:
        return Colors.blue;
      case TravelMode.train:
        return Colors.purple;
      case TravelMode.fx:
        return Colors.teal;
      case TravelMode.walking:
        return Colors.green;
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.modeName} Route'),
        backgroundColor: _getModeColor(),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.origin,
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              _fitBounds();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          // Bottom panel with step instructions
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Fare display
                    if (widget.fare > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.payments, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Fare: ₱${widget.fare.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Step list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: widget.steps.length,
                        itemBuilder: (context, index) {
                          final step = widget.steps[index];
                          final instruction =
                              step['html_instructions'] as String? ?? '';
                          final distance = (step['distance'] as Map?)?['text'] as String? ?? '';
                          final duration = (step['duration'] as Map?)?['text'] as String? ?? '';
                          final isCurrentStep = index == _currentStep;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _currentStep = index;
                              });
                              // Extract lat/lng from step if available
                              final latLng = _extractStepLocation(step);
                              if (latLng != null) {
                                _mapController?.animateCamera(
                                  CameraUpdate.newLatLng(latLng),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: isCurrentStep
                                        ? _getModeColor()
                                        : Colors.grey[300]!,
                                    width: isCurrentStep ? 3 : 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    margin: const EdgeInsets.only(left: 8, right: 12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCurrentStep
                                          ? _getModeColor()
                                          : Colors.grey[300],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isCurrentStep
                                              ? Colors.white
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _stripHtml(instruction),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isCurrentStep
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (distance.isNotEmpty || duration.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              '$distance • $duration',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  LatLng? _extractStepLocation(Map<String, dynamic> step) {
    try {
      final startLocation = step['start_location'] as Map?;
      if (startLocation != null) {
        return LatLng(
          startLocation['lat'] as double,
          startLocation['lng'] as double,
        );
      }
    } catch (_) {}
    return null;
  }

  void _fitBounds() {
    if (_mapController == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        widget.origin.latitude < widget.destination.latitude
            ? widget.origin.latitude
            : widget.destination.latitude,
        widget.origin.longitude < widget.destination.longitude
            ? widget.origin.longitude
            : widget.destination.longitude,
      ),
      northeast: LatLng(
        widget.origin.latitude > widget.destination.latitude
            ? widget.origin.latitude
            : widget.destination.latitude,
        widget.origin.longitude > widget.destination.longitude
            ? widget.origin.longitude
            : widget.destination.longitude,
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }
}
