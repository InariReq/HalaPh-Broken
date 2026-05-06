import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/google_maps_service.dart';
import 'package:halaph/utils/map_utils.dart';

class RouteMapScreen extends StatefulWidget {
  final TravelMode mode;
  final String modeName;
  final LatLng origin;
  final LatLng destination;
  final String destinationName;
  final String polyline;
  final List<Map<String, dynamic>> steps;
  final double fare;
  final List<String> fareBreakdown;

  const RouteMapScreen({
    super.key,
    required this.mode,
    required this.modeName,
    required this.origin,
    required this.destination,
    required this.destinationName,
    required this.polyline,
    required this.steps,
    required this.fare,
    this.fareBreakdown = const [],
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _currentStep = 0;
  String _polyline = '';
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _polyline = widget.polyline;
    _routePoints =
        _polyline.isNotEmpty ? MapUtils.decodePolyline(_polyline) : [];
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

    // Use route points if available
    if (_routePoints.isNotEmpty) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: _getModeColor(),
          width: 5,
        ),
      };
    }
  }

  Future<void> _reloadRoute() async {
    final profile = _modeProfile(widget.mode);
    final directions = await GoogleMapsService.getDirections(
      startLat: widget.origin.latitude,
      startLon: widget.origin.longitude,
      endLat: widget.destination.latitude,
      endLon: widget.destination.longitude,
      profile: profile,
    );
    if (directions != null) {
      final poly = directions['polyline'] as String? ?? '';
      final pts = MapUtils.decodePolyline(poly);
      setState(() {
        _polyline = poly;
        _routePoints = pts;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: pts,
            color: _getModeColor(),
            width: 5,
          )
        };
      });
    }
  }

  String _modeProfile(TravelMode mode) {
    switch (mode) {
      case TravelMode.jeepney:
      case TravelMode.bus:
      case TravelMode.fx:
        return 'driving';
      case TravelMode.train:
        return 'transit';
      case TravelMode.walking:
        return 'walking';
    }
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadRoute,
            tooltip: 'Refresh Route',
          ),
        ],
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
          // Optional informational banner when live directions are unavailable
          if (!GoogleMapsService.isConfigured || widget.polyline.isEmpty)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live directions are unavailable. Using estimated route data.',
                        style: TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.12,
            maxChildSize: 0.72,
            builder: (context, scrollController) {
              final hasSteps = widget.steps.isNotEmpty;
              final itemCount = hasSteps ? widget.steps.length + 3 : 4;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: ListView.builder(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              width: 46,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _getModeColor().withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.route,
                                    color: _getModeColor(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${widget.modeName} instructions',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Drag anywhere on this panel to expand.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      );
                    }

                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE8E8E8),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payments,
                                      color: Colors.green[700]),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.fare > 0
                                          ? 'Estimated total fare: ₱${widget.fare.toStringAsFixed(0)}'
                                          : 'No fare estimate available',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${widget.steps.length} steps',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.fareBreakdown.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ...widget.fareBreakdown.map(
                                  (line) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: Colors.green[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            line,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                              height: 1.25,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    if (index == 2) {
                      return _buildRouteGuidanceCard();
                    }

                    if (!hasSteps) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFECB3),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Detailed step-by-step directions are unavailable. Use the map preview and estimated route data.',
                                  style: TextStyle(height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final stepIndex = index - 3;
                    final step = widget.steps[stepIndex];
                    final instruction =
                        step['html_instructions'] as String? ?? '';
                    final distance =
                        (step['distance'] as Map?)?['text'] as String? ?? '';
                    final duration =
                        (step['duration'] as Map?)?['text'] as String? ?? '';

                    String transitInfo = '';
                    final transitDetails =
                        step['transit_details'] as Map<String, dynamic>?;
                    if (transitDetails != null) {
                      final line =
                          transitDetails['line'] as Map<String, dynamic>?;
                      final lineName =
                          (line?['short_name'] ?? line?['name'] ?? '')
                              .toString();
                      final depStop = transitDetails['departure_stop']
                          as Map<String, dynamic>?;
                      final depStopName = depStop?['name'] ?? '';
                      final arrStop = transitDetails['arrival_stop']
                          as Map<String, dynamic>?;
                      final arrStopName = arrStop?['name'] ?? '';
                      final depTime = transitDetails['departure_time']
                          as Map<String, dynamic>?;
                      final depTimeText = depTime?['text'] ?? '';
                      final arrTime = transitDetails['arrival_time']
                          as Map<String, dynamic>?;
                      final arrTimeText = arrTime?['text'] ?? '';

                      String detail = '';
                      if (lineName.isNotEmpty) {
                        detail += 'Board $lineName';
                      }
                      if (depStopName.isNotEmpty) {
                        detail += '${detail.isEmpty ? '' : ' '}at $depStopName';
                      }
                      if (depTimeText.isNotEmpty) {
                        detail += ' ($depTimeText)';
                      }
                      if (arrStopName.isNotEmpty) {
                        detail += ' to $arrStopName';
                      }
                      if (arrTimeText.isNotEmpty) {
                        detail += ' ($arrTimeText)';
                      }
                      if (detail.isNotEmpty) transitInfo = detail;
                    }

                    final isCurrentStep = stepIndex == _currentStep;

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        stepIndex == 0 ? 4 : 0,
                        18,
                        stepIndex == widget.steps.length - 1 ? 28 : 10,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _currentStep = stepIndex;
                          });

                          final latLng = _extractStepLocation(step);
                          if (latLng != null) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLng(latLng),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isCurrentStep
                                ? _getModeColor().withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentStep
                                  ? _getModeColor()
                                  : const Color(0xFFE8E8E8),
                              width: isCurrentStep ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCurrentStep
                                      ? _getModeColor()
                                      : Colors.grey[300],
                                ),
                                child: Center(
                                  child: Text(
                                    '${stepIndex + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCurrentStep
                                          ? Colors.white
                                          : Colors.grey[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _stripHtml(instruction),
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: isCurrentStep
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (transitInfo.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 7),
                                        child: Text(
                                          transitInfo,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    if (distance.isNotEmpty ||
                                        duration.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          '$distance • $duration',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w600,
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
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String get _destinationLabel {
    final value = widget.destinationName.trim();
    return value.isEmpty ? 'your destination' : value;
  }

  String _firstTransitLineName() {
    for (final step in widget.steps) {
      final transitDetails = step['transit_details'] as Map<String, dynamic>?;
      final line = transitDetails?['line'] as Map<String, dynamic>?;
      final lineName = (line?['short_name'] ?? line?['name'] ?? '').toString();
      if (lineName.trim().isNotEmpty) return lineName.trim();
    }
    return '';
  }

  String _routeDirectionInstruction(String lineName) {
    final destination = _destinationLabel;

    switch (widget.mode) {
      case TravelMode.jeepney:
        if (lineName.isNotEmpty) {
          return 'Ride the $lineName route heading toward $destination.';
        }
        return 'Look for a jeepney signboard heading toward $destination. Confirm with the driver that it passes your drop-off before boarding.';
      case TravelMode.bus:
        if (lineName.isNotEmpty) {
          return 'Ride the $lineName bus route heading toward $destination.';
        }
        return 'Look for a bus route heading toward $destination or the nearest terminal. Confirm the drop-off point with the conductor before boarding.';
      case TravelMode.train:
        if (lineName.isNotEmpty) {
          return 'Take $lineName toward the station serving $destination.';
        }
        return 'Take the MRT/LRT line toward the station nearest $destination, then use the last-mile ride shown in the fare breakdown.';
      case TravelMode.fx:
        if (lineName.isNotEmpty) {
          return 'Ride the $lineName FX/UV route heading toward $destination.';
        }
        return 'Look for an FX/UV terminal route heading toward $destination. Confirm the terminal and drop-off point before boarding.';
      case TravelMode.walking:
        return 'Walk toward $destination using the map preview and available step list.';
    }
  }

  List<String> _routeDirectionNotes(String lineName) {
    if (lineName.isNotEmpty) {
      return [
        'Use this route or line name when checking the vehicle signboard.',
        'Follow the listed boarding and alighting stops when the step list provides them.',
      ];
    }

    switch (widget.mode) {
      case TravelMode.jeepney:
        return [
          'Use the destination area as your signboard guide.',
          'Ask if the jeepney passes your exact drop-off before paying.',
        ];
      case TravelMode.bus:
        return [
          'Use the destination area or nearest terminal as your route direction.',
          'Ask the conductor where to alight for the closest transfer or destination point.',
        ];
      case TravelMode.train:
        return [
          'Use the rail line and station direction available in the station signboards.',
          'After alighting, follow the last-mile ride estimate in the fare breakdown.',
        ];
      case TravelMode.fx:
        return [
          'Use the terminal or destination area written on the FX/UV signboard.',
          'Confirm the exact drop-off point before boarding.',
        ];
      case TravelMode.walking:
        return [
          'Follow safe pedestrian paths where available.',
          'Use the map preview for orientation.',
        ];
    }
  }

  Widget _buildRouteGuidanceCard() {
    final lineName = _firstTransitLineName();
    final instruction = _routeDirectionInstruction(lineName);
    final notes = _routeDirectionNotes(lineName);
    final hasExactLine = lineName.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _getModeColor().withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getModeColor().withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.signpost_rounded, color: _getModeColor()),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasExactLine
                        ? 'Specific route to look for'
                        : 'Route direction to look for',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              instruction,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: _getModeColor(),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        note,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
