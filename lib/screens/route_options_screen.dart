import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/google_maps_api_service.dart';

class RouteOptionsScreen extends StatefulWidget {
  final String destinationId;
  final String destinationName;
  final String? source;
  final Destination? destination;

  const RouteOptionsScreen({
    super.key,
    required this.destinationId,
    required this.destinationName,
    this.source,
    this.destination,
  });

  @override
  State<RouteOptionsScreen> createState() => _RouteOptionsScreenState();
}

class _RouteOptionsScreenState extends State<RouteOptionsScreen> {
  GoogleMapController? _mapController;
  bool _isLoading = true;
  String? _errorMessage;

  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  final List<_RouteViewModel> _routes = [];
  _RouteViewModel? _selectedRoute;
  TravelMode? _preferredMode;

  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  List<_RouteViewModel> get _visibleRoutes {
    if (_preferredMode == null) return _routes;
    return _routes.where((route) => route.mode == _preferredMode).toList();
  }

  Future<void> _loadRouteData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final origin = await DestinationService.getCurrentLocation();
      final destination = await _resolveDestinationLocation();

      final routes = <_RouteViewModel>[];
      final googleResults = await GoogleMapsApiService.getAllDirectionsModes(
        origin: origin,
        destination: destination,
      );

      final seenSignatures = <String>{};
      for (final response in googleResults) {
        for (final googleRoute in response.routes) {
          final converted = _convertGoogleRoute(
            googleRoute,
            origin,
            destination,
          );
          final signature =
              '${converted.mode.name}|${converted.summary}|'
              '${converted.boardStop}|${converted.dropOffStop}|${converted.routeLabel}';
          if (seenSignatures.add(signature)) {
            routes.add(converted);
          }
        }
      }

      if (routes.isEmpty) {
        final fallbackRoutes = await BudgetRoutingService.calculateBudgetRoutes(
          origin: origin,
          destination: destination,
        );
        routes.addAll(
          fallbackRoutes.map(
            (route) => _RouteViewModel(
              id: route.id,
              mode: route.mode,
              duration: route.duration,
              distanceKm: route.distance,
              cost: route.cost,
              fareLabel: route.cost <= 0
                  ? 'Free'
                  : 'PHP ${route.cost.toStringAsFixed(0)}',
              fareIsConfirmed: false,
              summary: route.summary,
              tips: route.tips,
              instructions: route.instructions,
              transitLegs: const [],
              routeLabel: null,
              polyline: route.polyline,
              boardStop: null,
              dropOffStop: null,
              boardLocation: null,
              dropOffLocation: null,
            ),
          ),
        );
      }

      routes.sort((a, b) {
        final aScore = a.cost + (a.duration.inMinutes * 0.15);
        final bScore = b.cost + (b.duration.inMinutes * 0.15);
        return aScore.compareTo(bScore);
      });

      if (!mounted) return;
      setState(() {
        _currentLocation = origin;
        _destinationLocation = destination;
        _routes
          ..clear()
          ..addAll(routes);
        _selectedRoute = _visibleRoutes.isNotEmpty
            ? _visibleRoutes.first
            : null;
        _isLoading = false;
      });
      _refreshMapOverlays();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load routes. Please try again.';
      });
    }
  }

  Future<LatLng> _resolveDestinationLocation() async {
    if (widget.destination?.coordinates != null) {
      return widget.destination!.coordinates!;
    }

    Destination? destination;
    if (widget.destinationId.isNotEmpty) {
      destination = await DestinationService.getDestination(
        widget.destinationId,
      );
      destination ??= await DestinationService.getDestinationByPlaceId(
        widget.destinationId,
      );
    }

    if (destination?.coordinates != null) {
      return destination!.coordinates!;
    }

    final geocoded = await GoogleMapsApiService.geocodeAddress(
      widget.destinationName,
    );
    if (geocoded != null) return geocoded;

    throw Exception('Destination coordinates not found.');
  }

  _RouteViewModel _convertGoogleRoute(
    GoogleRoute route,
    LatLng origin,
    LatLng destination,
  ) {
    final flattenedSteps = _flattenSteps(
      route.legs.expand((leg) => leg.steps).toList(),
    );
    final mode = _inferMode(flattenedSteps);

    String? boardStop;
    String? dropOffStop;
    LatLng? boardLocation;
    LatLng? dropOffLocation;
    final instructions = <String>[];
    final transitLegs = <_TransitLegViewModel>[];

    for (final step in flattenedSteps) {
      if (step.transitDetails != null) {
        final td = step.transitDetails!;
        final leg = _TransitLegViewModel(
          vehicleLabel: _resolveVehicleLabel(td.line),
          lineLabel: _resolveLineLabel(td.line),
          headsign: td.headsign,
          departureStop: td.departureStop.name,
          arrivalStop: td.arrivalStop.name,
          departureTime: td.departureTimeText,
          arrivalTime: td.arrivalTimeText,
          stopCount: td.numStops,
        );
        transitLegs.add(leg);
        boardStop ??= td.departureStop.name;
        dropOffStop = td.arrivalStop.name;
        boardLocation ??= td.departureStop.location;
        dropOffLocation = td.arrivalStop.location;

        instructions.add(
          'Ride ${leg.vehicleLabel} ${leg.lineLabel} toward ${leg.headsign}. '
          'Board at ${leg.departureStop} and get off at ${leg.arrivalStop}'
          '${leg.stopCount > 0 ? ' (${leg.stopCount} stops).' : '.'}',
        );
      } else {
        final text = _cleanInstruction(step.htmlInstructions);
        if (text.isNotEmpty) {
          instructions.add(text);
        }
      }
    }

    final polyline = _decodePolyline(route.overviewPolyline);
    final distanceKm = route.totalDistance;
    final fareIsConfirmed = route.fare != null && route.fare!.value > 0;
    final cost = fareIsConfirmed
        ? route.fare!.value
        : _estimateCost(mode, distanceKm);
    final fareLabel = fareIsConfirmed
        ? (route.fare!.text.isNotEmpty ? route.fare!.text : _formatPhp(cost))
        : _formatPhp(cost);
    final tips = _buildTips(mode, route, boardStop, dropOffStop);
    final routeLabel = transitLegs.isNotEmpty
        ? transitLegs.first.routeLabel
        : null;

    return _RouteViewModel(
      id: 'google_${mode.name}_${DateTime.now().microsecondsSinceEpoch}',
      mode: mode,
      duration: route.totalDuration,
      distanceKm: distanceKm,
      cost: cost,
      fareLabel: fareLabel,
      fareIsConfirmed: fareIsConfirmed,
      summary: route.summary.isNotEmpty
          ? route.summary
          : _defaultSummaryForMode(mode),
      tips: tips,
      instructions: instructions,
      transitLegs: transitLegs,
      routeLabel: routeLabel,
      polyline: polyline.isNotEmpty ? polyline : [origin, destination],
      boardStop: boardStop,
      dropOffStop: dropOffStop,
      boardLocation: boardLocation,
      dropOffLocation: dropOffLocation,
    );
  }

  List<GoogleStep> _flattenSteps(List<GoogleStep> steps) {
    final out = <GoogleStep>[];
    for (final step in steps) {
      if (step.travelMode.toUpperCase() == 'TRANSIT') {
        out.add(step);
        continue;
      }
      if (step.subSteps.isNotEmpty) {
        out.addAll(_flattenSteps(step.subSteps));
      } else {
        out.add(step);
      }
    }
    return out;
  }

  TravelMode _inferMode(List<GoogleStep> steps) {
    final transitStep = steps
        .where((s) => s.transitDetails != null)
        .firstOrNull;
    if (transitStep != null) {
      final vehicleType = transitStep.transitDetails!.line.vehicleType
          .toUpperCase();
      if (vehicleType.contains('RAIL') ||
          vehicleType.contains('SUBWAY') ||
          vehicleType.contains('TRAIN') ||
          vehicleType.contains('TRAM')) {
        return TravelMode.train;
      }
      if (vehicleType.contains('BUS')) {
        return TravelMode.bus;
      }
      return TravelMode.jeepney;
    }

    final hasDriving = steps.any(
      (step) => step.travelMode.toUpperCase() == 'DRIVING',
    );
    if (hasDriving) return TravelMode.driving;
    return TravelMode.walking;
  }

  double _estimateCost(TravelMode mode, double distanceKm) {
    switch (mode) {
      case TravelMode.driving:
        return (distanceKm / PhilippineFares.vehicleFuelConsumption) *
                PhilippineFares.fuelPricePerLiter +
            PhilippineFares.parkingRatePerHour;
      case TravelMode.jeepney:
        return distanceKm <= 4
            ? PhilippineFares.traditionalJeepneyBase
            : PhilippineFares.traditionalJeepneyBase +
                  (distanceKm - 4) * PhilippineFares.traditionalJeepneyPerKm;
      case TravelMode.bus:
        return distanceKm <= 5
            ? PhilippineFares.airconBusBase
            : PhilippineFares.airconBusBase +
                  (distanceKm - 5) * PhilippineFares.busPerKm;
      case TravelMode.train:
        return PhilippineFares.mrt3Base;
      case TravelMode.walking:
        return 0;
    }
  }

  List<String> _buildTips(
    TravelMode mode,
    GoogleRoute route,
    String? boardStop,
    String? dropOffStop,
  ) {
    final tips = <String>[];

    if (mode == TravelMode.walking) {
      tips.add('Free route. Wear comfortable footwear.');
    }
    if (mode == TravelMode.driving) {
      tips.add('Watch for toll fees and parking costs.');
    }
    if (route.fare != null && route.fare!.value > 0) {
      tips.add('Live transit fare: ${route.fare!.text}.');
    } else if (mode == TravelMode.bus ||
        mode == TravelMode.train ||
        mode == TravelMode.jeepney) {
      tips.add('Fare shown is an estimate when live fare is unavailable.');
    }
    if (boardStop != null && boardStop.isNotEmpty) {
      tips.add('Board at $boardStop.');
    }
    if (dropOffStop != null && dropOffStop.isNotEmpty) {
      tips.add('Get off at $dropOffStop.');
    }
    if (route.warnings.isNotEmpty) {
      tips.addAll(route.warnings.take(2));
    }
    return tips;
  }

  String _defaultSummaryForMode(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return 'Walking route';
      case TravelMode.driving:
        return 'Driving route';
      case TravelMode.jeepney:
        return 'Public utility jeepney route';
      case TravelMode.bus:
        return 'Bus route';
      case TravelMode.train:
        return 'Train route';
    }
  }

  String _resolveVehicleLabel(GoogleTransitLine line) {
    if (line.vehicleName.trim().isNotEmpty) return line.vehicleName.trim();
    if (line.vehicleType.trim().isNotEmpty) {
      final value = line.vehicleType.trim().toLowerCase();
      return value[0].toUpperCase() + value.substring(1);
    }
    return 'Transit';
  }

  String _resolveLineLabel(GoogleTransitLine line) {
    if (line.shortName.trim().isNotEmpty) return line.shortName.trim();
    if (line.name.trim().isNotEmpty) return line.name.trim();
    return 'Route';
  }

  String _formatPhp(double amount) {
    if (amount <= 0) return 'Free';
    return 'PHP ${amount.toStringAsFixed(0)}';
  }

  String _cleanInstruction(String html) {
    if (html.isEmpty) return '';
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .trim();
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _refreshMapOverlays() {
    final origin = _currentLocation;
    final destination = _destinationLocation;
    final route = _selectedRoute;
    if (origin == null || destination == null) return;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('origin'),
        position: origin,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: InfoWindow(title: widget.destinationName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (route?.boardLocation != null && route!.boardStop != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('board_stop'),
          position: route.boardLocation!,
          infoWindow: InfoWindow(title: 'Board', snippet: route.boardStop),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }
    if (route?.dropOffLocation != null && route!.dropOffStop != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff_stop'),
          position: route.dropOffLocation!,
          infoWindow: InfoWindow(title: 'Get Off', snippet: route.dropOffStop),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    final polylines = <Polyline>{};
    if (route != null && route.polyline.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('selected_route'),
          points: route.polyline,
          color: _modeColor(route.mode),
          width: 6,
          patterns: route.mode == TravelMode.walking
              ? [PatternItem.dash(12), PatternItem.gap(8)]
              : const [],
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    _fitMapToRoute();
  }

  Color _modeColor(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return const Color(0xFF43A047);
      case TravelMode.driving:
        return const Color(0xFF1976D2);
      case TravelMode.jeepney:
        return const Color(0xFFF57C00);
      case TravelMode.bus:
        return const Color(0xFF6D4C41);
      case TravelMode.train:
        return const Color(0xFF8E24AA);
    }
  }

  Future<void> _fitMapToRoute() async {
    final controller = _mapController;
    final route = _selectedRoute;
    if (controller == null || route == null || route.polyline.isEmpty) return;

    final points = route.polyline;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
    } catch (_) {
      // Map may not be ready on first frame; ignore and keep default camera.
    }
  }

  String _modeName(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return 'Walking';
      case TravelMode.driving:
        return 'Driving';
      case TravelMode.jeepney:
        return 'Jeepney';
      case TravelMode.bus:
        return 'Bus';
      case TravelMode.train:
        return 'Train';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Routes to ${widget.destinationName}'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRouteData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final visibleRoutes = _visibleRoutes;
    if (_selectedRoute == null && visibleRoutes.isNotEmpty) {
      _selectedRoute = visibleRoutes.first;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refreshMapOverlays(),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(14.5995, 120.9842),
              zoom: 13,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _fitMapToRoute();
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
          ),
        ),
        _buildModeFilters(),
        Expanded(
          child: visibleRoutes.isEmpty
              ? const Center(
                  child: Text('No routes match this transport preference.'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    ...visibleRoutes.map(_buildRouteCard),
                    if (_selectedRoute != null)
                      _buildRouteGuide(_selectedRoute!),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildModeFilters() {
    const modes = [
      null,
      TravelMode.jeepney,
      TravelMode.bus,
      TravelMode.train,
      TravelMode.driving,
      TravelMode.walking,
    ];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: modes.map((mode) {
          final isSelected = _preferredMode == mode;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(mode == null ? 'All' : _modeName(mode)),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _preferredMode = mode;
                  final visible = _visibleRoutes;
                  _selectedRoute = visible.isEmpty ? null : visible.first;
                });
                _refreshMapOverlays();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRouteCard(_RouteViewModel route) {
    final isSelected = _selectedRoute?.id == route.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? _modeColor(route.mode) : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _selectedRoute = route);
          _refreshMapOverlays();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions, color: _modeColor(route.mode)),
                  const SizedBox(width: 8),
                  Text(
                    _modeName(route.mode),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    route.fareLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${route.duration.inMinutes} min • ${route.distanceKm.toStringAsFixed(1)} km',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Text(
                route.fareIsConfirmed
                    ? 'Fare source: Live transit fare'
                    : 'Fare source: Estimated',
                style: TextStyle(
                  color: route.fareIsConfirmed
                      ? Colors.green[700]
                      : Colors.orange[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (route.routeLabel != null && route.routeLabel!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Route: ${route.routeLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              if (route.boardStop != null && route.boardStop!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Board: ${route.boardStop}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              if (route.dropOffStop != null && route.dropOffStop!.isNotEmpty)
                Text(
                  'Get off: ${route.dropOffStop}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 8),
              Text(route.summary, style: TextStyle(color: Colors.grey[800])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteGuide(_RouteViewModel route) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route Guide',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (route.tips.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: route.tips
                  .map(
                    (tip) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(tip, style: const TextStyle(fontSize: 12)),
                    ),
                  )
                  .toList(),
            ),
          if (route.tips.isNotEmpty) const SizedBox(height: 12),
          if (route.transitLegs.isNotEmpty) ...[
            const Text(
              'Ride Plan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...route.transitLegs.asMap().entries.map(
              (entry) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDE7FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key + 1}. ${entry.value.routeLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Board at: ${entry.value.departureStop}'),
                    Text('Get off at: ${entry.value.arrivalStop}'),
                    if (entry.value.departureTime.isNotEmpty ||
                        entry.value.arrivalTime.isNotEmpty)
                      Text(
                        'Time: ${entry.value.departureTime} - ${entry.value.arrivalTime}',
                      ),
                    if (entry.value.stopCount > 0)
                      Text('Stops: ${entry.value.stopCount}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          ...route.instructions.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${entry.key + 1}.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  Expanded(child: Text(entry.value)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteViewModel {
  final String id;
  final TravelMode mode;
  final Duration duration;
  final double distanceKm;
  final double cost;
  final String fareLabel;
  final bool fareIsConfirmed;
  final String summary;
  final List<String> tips;
  final List<String> instructions;
  final List<_TransitLegViewModel> transitLegs;
  final String? routeLabel;
  final List<LatLng> polyline;
  final String? boardStop;
  final String? dropOffStop;
  final LatLng? boardLocation;
  final LatLng? dropOffLocation;

  _RouteViewModel({
    required this.id,
    required this.mode,
    required this.duration,
    required this.distanceKm,
    required this.cost,
    required this.fareLabel,
    required this.fareIsConfirmed,
    required this.summary,
    required this.tips,
    required this.instructions,
    required this.transitLegs,
    required this.routeLabel,
    required this.polyline,
    required this.boardStop,
    required this.dropOffStop,
    required this.boardLocation,
    required this.dropOffLocation,
  });
}

class _TransitLegViewModel {
  final String vehicleLabel;
  final String lineLabel;
  final String headsign;
  final String departureStop;
  final String arrivalStop;
  final String departureTime;
  final String arrivalTime;
  final int stopCount;

  _TransitLegViewModel({
    required this.vehicleLabel,
    required this.lineLabel,
    required this.headsign,
    required this.departureStop,
    required this.arrivalStop,
    required this.departureTime,
    required this.arrivalTime,
    required this.stopCount,
  });

  String get routeLabel {
    if (headsign.trim().isEmpty) {
      return '$vehicleLabel $lineLabel';
    }
    return '$vehicleLabel $lineLabel to $headsign';
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
