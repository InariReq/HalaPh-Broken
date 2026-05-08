import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/google_maps_service.dart';
import 'package:halaph/models/verified_route.dart';
import 'package:halaph/services/verified_route_service.dart';
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

class _HistoricalInstructionStep {
  final IconData icon;
  final String title;
  final String body;

  const _HistoricalInstructionStep({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _currentStep = 0;
  String _polyline = '';
  List<LatLng> _routePoints = [];
  VerifiedRouteReference? _historicalRouteReference;
  List<HistoricalRouteMatch> _historicalRouteMatches = const [];

  @override
  void initState() {
    super.initState();
    _polyline = widget.polyline;
    _routePoints =
        _polyline.isNotEmpty ? MapUtils.decodePolyline(_polyline) : [];
    _setupMap();
    _loadHistoricalRouteReference();
  }

  Future<void> _loadHistoricalRouteReference() async {
    final reference = await VerifiedRouteService.findHistoricalRouteReference(
      mode: widget.mode,
      destinationName: widget.destinationName,
    );
    final matches = await VerifiedRouteService.findHistoricalRouteMatches(
      mode: widget.mode,
      origin: widget.origin,
      destination: widget.destination,
      limit: 5,
    );

    if (!mounted) return;
    setState(() {
      _historicalRouteReference = reference;
      _historicalRouteMatches = matches;
    });
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
            icon: Icon(Icons.refresh),
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
              child: _buildRoutePanelEntrance(
                order: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF332711)
                        : Colors.amber[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFF6D58A)
                            : Colors.amber[900],
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _historicalRouteMatches.isNotEmpty
                              ? 'Using historical GTFS commute guidance. Live turn-by-turn public transport directions are unavailable.'
                              : 'Live public transport directions are unavailable. HalaPH will not show car-driving directions as commute steps.',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFFFF0C2)
                                    : Colors.amber[900],
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
                  color: Theme.of(context).colorScheme.surfaceContainer,
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
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                    : Colors.grey[300],
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
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Drag anywhere on this panel to expand.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
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
                      return _buildRoutePanelEntrance(
                        order: 1,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.28),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.payments,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.green[300]
                                          : Colors.green[700],
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        widget.fare > 0
                                            ? 'Estimated total fare: ₱${widget.fare.toStringAsFixed(0)}'
                                            : 'No fare estimate available',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${widget.steps.length} steps',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
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
                        ),
                      );
                    }

                    if (index == 2) {
                      return _buildRoutePanelEntrance(
                        order: 2,
                        child: _buildRouteGuidanceCard(),
                      );
                    }

                    if (!hasSteps) {
                      final bestHistoricalMatch =
                          _historicalRouteMatches.isNotEmpty
                              ? _historicalRouteMatches.first
                              : null;

                      if (bestHistoricalMatch != null) {
                        return _buildRoutePanelEntrance(
                          order: 3,
                          child: _buildHistoricalInstructionSteps(
                            bestHistoricalMatch,
                          ),
                        );
                      }

                      return _buildRoutePanelEntrance(
                        order: 3,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF332711)
                                  : const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF8A641B)
                                    : const Color(0xFFFFECB3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFF6D58A)
                                      : Colors.orange,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No verified public transport step list was found for this route. HalaPH will not show car-driving directions as commute instructions.',
                                    style: TextStyle(
                                      height: 1.35,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFFFFF0C2)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentStep
                                  ? _getModeColor()
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.28),
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
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                ),
                                child: Center(
                                  child: Text(
                                    '${stepIndex + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCurrentStep
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                    if (transitInfo.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 7),
                                        child: Text(
                                          transitInfo,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
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

  Widget _buildRoutePanelEntrance({
    required int order,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (order.clamp(0, 4) * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
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
    final historicalReference = _historicalRouteReference;
    final historicalRouteName = historicalReference?.displayName ?? '';

    switch (widget.mode) {
      case TravelMode.jeepney:
        if (lineName.isNotEmpty) {
          return 'Signboard / route name: $lineName. Use this route name when checking the jeepney signboard.';
        }
        if (historicalRouteName.isNotEmpty) {
          return 'Historical signboard / route name: $historicalRouteName. Use this as a route clue only, then confirm with the driver before boarding.';
        }
        return 'No verified jeepney signboard found for this trip. Use the route estimate as a general guide only. Ask the driver if the jeepney passes your exact drop-off before boarding.';
      case TravelMode.bus:
        if (lineName.isNotEmpty) {
          return 'Bus route name: $lineName. Check this route name on the bus signboard or terminal board.';
        }
        if (historicalRouteName.isNotEmpty) {
          return 'Historical bus route name: $historicalRouteName. Use this as a route clue only, then confirm the active route with the conductor.';
        }
        return 'No verified bus signboard found for this trip. Use the route estimate as a general guide only. Confirm the terminal and drop-off point with the conductor.';
      case TravelMode.train:
        if (lineName.isNotEmpty) {
          return 'Rail line: $lineName. Follow the station direction signs and alight at the listed stop when available.';
        }
        if (historicalRouteName.isNotEmpty) {
          return 'Historical rail line: $historicalRouteName. Confirm the current station direction before boarding.';
        }
        return 'No verified rail line found for this trip. Check the station line map and direction signs before entering the platform.';
      case TravelMode.fx:
        if (lineName.isNotEmpty) {
          return 'FX/UV route name: $lineName. Check this route name on the terminal board or vehicle signboard.';
        }
        if (historicalRouteName.isNotEmpty) {
          return 'Historical FX/UV route clue: $historicalRouteName. Confirm the active terminal route with the dispatcher before boarding.';
        }
        return 'No verified FX/UV terminal route found for this trip. Use the route estimate as a general guide only. Ask the dispatcher for the correct van and drop-off.';
      case TravelMode.walking:
        return 'Walk using the map preview and available step list.';
    }
  }

  List<String> _routeDirectionNotes(String lineName) {
    final historicalReference = _historicalRouteReference;

    if (lineName.isNotEmpty) {
      return [
        'Live route step provided this line name.',
        'Use this route or line name when checking the vehicle signboard.',
        'Follow the listed boarding and alighting stops when the step list provides them.',
      ];
    }

    if (historicalReference != null) {
      return [
        historicalReference.sourceLabel,
        historicalReference.sourceDetail,
        'Confirm the route still operates before riding.',
      ];
    }

    switch (widget.mode) {
      case TravelMode.jeepney:
        return [
          'No exact signboard is verified for this route.',
          'Use this as a general commute guide, not a guaranteed active route.',
          'Ask the driver if the jeepney passes your exact drop-off before paying.',
        ];
      case TravelMode.bus:
        return [
          'No exact bus signboard is verified for this route.',
          'Use the nearest terminal or major road direction only as a guide.',
          'Ask the conductor where to alight for the closest transfer or destination point.',
        ];
      case TravelMode.train:
        return [
          'No exact rail direction is verified for this route.',
          'Check the station line map and platform direction signs.',
          'After alighting, follow the last-mile ride estimate in the fare breakdown.',
        ];
      case TravelMode.fx:
        return [
          'No exact FX/UV terminal signboard is verified for this route.',
          'Check the terminal board or ask the dispatcher before boarding.',
          'Confirm the exact drop-off point before paying.',
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
    final bestHistoricalMatch = _historicalRouteMatches.isNotEmpty
        ? _historicalRouteMatches.first
        : null;
    final instruction = _routeDirectionInstruction(lineName);
    final notes = _routeDirectionNotes(lineName);
    final hasExactLine = lineName.isNotEmpty;
    final hasHistoricalReference =
        _historicalRouteReference != null || bestHistoricalMatch != null;

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
                        ? 'Verified route name'
                        : hasHistoricalReference
                            ? 'Historical signboard clue'
                            : 'No verified signboard found',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              instruction,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (bestHistoricalMatch != null && !hasExactLine) ...[
              const SizedBox(height: 10),
              _buildHistoricalRouteMatchCard(bestHistoricalMatch),
            ],
            if (hasHistoricalReference && !hasExactLine) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF332711)
                      : const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF8A641B)
                        : const Color(0xFFFFD699),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFF6D58A)
                          : Color(0xFFB45309),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Historical reference only. Confirm route status before riding.',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFFF0C2)
                              : Color(0xFF92400E),
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildHistoricalInstructionSteps(HistoricalRouteMatch match) {
    final steps = <_HistoricalInstructionStep>[
      _HistoricalInstructionStep(
        icon: Icons.directions_walk_rounded,
        title: 'Walk to boarding point',
        body:
            'Go to ${match.boardStopName}. Estimated walk: ${_formatMeters(match.walkToBoardMeters)}.',
      ),
      _HistoricalInstructionStep(
        icon: Icons.directions_bus_filled_rounded,
        title: 'Board the vehicle',
        body:
            'Look for the signboard / route name: ${match.signboard}. ${match.via.trim().isNotEmpty ? 'Use the via clue: ${match.viaLabel}.' : 'No via point is listed in the GTFS route name.'}',
      ),
      _HistoricalInstructionStep(
        icon: Icons.route_rounded,
        title: 'Ride to the alighting point',
        body:
            'Stay on the route for about ${match.stopCount} stop${match.stopCount == 1 ? '' : 's'}. Confirm with the driver, conductor, or dispatcher before paying.',
      ),
      _HistoricalInstructionStep(
        icon: Icons.flag_rounded,
        title: 'Get off',
        body:
            'Alight at ${match.alightStopName}. This is the matched GTFS drop-off point nearest your destination.',
      ),
      _HistoricalInstructionStep(
        icon: Icons.directions_walk_rounded,
        title: 'Continue to destination',
        body:
            'Walk from the drop-off point to your destination. Estimated walk: ${_formatMeters(match.walkFromAlightMeters)}.',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_list_numbered_rounded,
                    color: _getModeColor()),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Historical GTFS commute steps',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'These steps use matched historical route data. Confirm current operation before riding.',
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(steps.length, (index) {
              final step = steps[index];
              final isLast = index == steps.length - 1;

              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getModeColor().withValues(alpha: 0.12),
                            border: Border.all(
                              color: _getModeColor().withValues(alpha: 0.35),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: _getModeColor(),
                              ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 34,
                            color: _getModeColor().withValues(alpha: 0.18),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(step.icon,
                                    size: 17, color: _getModeColor()),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    step.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              step.body,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalRouteMatchCard(HistoricalRouteMatch match) {
    final alternativeCount = (_historicalRouteMatches.length - 1).clamp(0, 99);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F2537)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2B5A7A)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHistoricalDetailRow(
            icon: Icons.directions_bus_filled_rounded,
            label: 'Signboard / Route Name',
            value: match.signboard,
          ),
          const SizedBox(height: 8),
          _buildHistoricalDetailRow(
            icon: Icons.alt_route_rounded,
            label: 'Via',
            value: match.viaLabel,
          ),
          const SizedBox(height: 8),
          _buildHistoricalDetailRow(
            icon: Icons.place_rounded,
            label: 'Board at',
            value:
                '${match.boardStopName} (${_formatMeters(match.walkToBoardMeters)} walk)',
          ),
          const SizedBox(height: 8),
          _buildHistoricalDetailRow(
            icon: Icons.flag_rounded,
            label: 'Get off at',
            value:
                '${match.alightStopName} (${_formatMeters(match.walkFromAlightMeters)} from destination)',
          ),
          const SizedBox(height: 8),
          _buildHistoricalDetailRow(
            icon: Icons.format_list_numbered_rounded,
            label: 'Stops',
            value:
                '${match.stopCount} stop${match.stopCount == 1 ? '' : 's'} between boarding and alighting',
          ),
          if (alternativeCount > 0) ...[
            const SizedBox(height: 8),
            _buildHistoricalDetailRow(
              icon: Icons.compare_arrows_rounded,
              label: 'Alternatives',
              value:
                  '$alternativeCount other historical route clue${alternativeCount == 1 ? '' : 's'} found near this trip',
            ),
          ],
          const SizedBox(height: 10),
          Text(
            match.sourceWarning,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _getModeColor()),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatMeters(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
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
