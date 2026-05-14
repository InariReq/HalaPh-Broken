import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/google_maps_service.dart';
import 'package:halaph/services/guide_mode_demo_state.dart';
import 'package:halaph/services/guide_presenter_controller.dart';
import 'package:halaph/models/verified_route.dart';
import 'package:halaph/services/verified_route_service.dart';
import 'package:halaph/utils/map_utils.dart';
import 'package:halaph/widgets/transport_mode_widgets.dart';

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
  final HistoricalRouteMatch? historicalMatch;
  final bool guideModeDemo;
  final GuidePresenterController? guidePresenterController;

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
    this.historicalMatch,
    this.guideModeDemo = false,
    this.guidePresenterController,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

const double _stationAccessRideThresholdKm = 0.80;

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _currentStep = 0;
  String _polyline = '';
  List<LatLng> _routePoints = [];
  List<LatLng> _walkingRoutePoints = [];
  bool _loadingWalkingRoute = false;
  VerifiedRouteReference? _historicalRouteReference;
  bool _guideFareVisible = false;

  @override
  void initState() {
    super.initState();
    _polyline = widget.polyline;
    _routePoints =
        _polyline.isNotEmpty ? MapUtils.decodePolyline(_polyline) : [];
    if (widget.guideModeDemo) {
      return;
    }
    _setupMap();
    _loadHistoricalRouteReference();
  }

  Future<void> _loadHistoricalRouteReference() async {
    final reference = await VerifiedRouteService.findHistoricalRouteReference(
      mode: widget.mode,
      destinationName: widget.destinationName,
    );
    if (!mounted) return;
    setState(() {
      _historicalRouteReference = reference;
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

    if (widget.historicalMatch != null) {
      final match = widget.historicalMatch!;
      final legs = match.legs.isNotEmpty
          ? match.legs
          : <HistoricalRouteLeg>[
              HistoricalRouteLeg(
                route: match.route,
                mode: match.route.mode,
                signboard: match.signboard,
                via: match.via,
                boardStopName: match.boardStopName,
                boardStopLat: match.boardStopLat,
                boardStopLon: match.boardStopLon,
                alightStopName: match.alightStopName,
                alightStopLat: match.alightStopLat,
                alightStopLon: match.alightStopLon,
                walkToBoardMeters: match.walkToBoardMeters,
                rideDistanceMeters: match.rideDistanceMeters,
                stopCount: match.stopCount,
              ),
            ];

      for (var i = 0; i < legs.length; i++) {
        final leg = legs[i];
        final effectiveMode = _effectiveRideModeForLeg(leg);
        final isTrain = effectiveMode == TravelMode.train;
        final isFirst = i == 0;
        final isLast = i == legs.length - 1;

        final boardTitle = isTrain
            ? (isFirst ? 'Board at station' : 'Board connecting train')
            : (isFirst ? 'Board here' : 'Board connecting ride');

        final alightTitle = isTrain
            ? (isLast ? 'Get off at station' : 'Transfer at station')
            : (isLast ? 'Get off here' : 'Transfer get off');

        _markers.addAll({
          Marker(
            markerId: MarkerId('gtfs_board_stop_$i'),
            position: LatLng(leg.boardStopLat, leg.boardStopLon),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isTrain ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: boardTitle,
              snippet: leg.boardStopName,
            ),
          ),
          Marker(
            markerId: MarkerId('gtfs_alight_stop_$i'),
            position: LatLng(leg.alightStopLat, leg.alightStopLon),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isLast ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueYellow,
            ),
            infoWindow: InfoWindow(
              title: alightTitle,
              snippet: leg.alightStopName,
            ),
          ),
        });

        if (!isLast) {
          final nextLeg = legs[i + 1];
          _markers.add(
            Marker(
              markerId: MarkerId('gtfs_transfer_walk_$i'),
              position: LatLng(nextLeg.boardStopLat, nextLeg.boardStopLon),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueCyan,
              ),
              infoWindow: InfoWindow(
                title: _effectiveRideModeForLeg(nextLeg) == TravelMode.train
                    ? 'Next rail station'
                    : 'Next boarding point',
                snippet: nextLeg.boardStopName,
              ),
            ),
          );
        }
      }
    }

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
    final isRoadPublicMode = widget.mode == TravelMode.jeepney ||
        widget.mode == TravelMode.bus ||
        widget.mode == TravelMode.fx;

    if (isRoadPublicMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Road public transport uses HalaPH route guidance. Driving directions are not shown as commute steps.',
          ),
        ),
      );
      return;
    }

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
        _walkingRoutePoints = [];
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

  Future<void> _showWalkingDirectionsForStep(
    Map<String, dynamic> step,
  ) async {
    if (!_isWalkingStep(step) || _loadingWalkingRoute) return;

    final start = _walkingStepStart(step);
    final end = _walkingStepEnd(step);
    if (start == null || end == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walking path is unavailable.')),
      );
      return;
    }

    setState(() {
      _loadingWalkingRoute = true;
      _walkingRoutePoints = [];
      _polylines = _withoutWalkingRoutePolyline(_polylines);
    });

    final directions = await GoogleMapsService.getDirections(
      startLat: start.latitude,
      startLon: start.longitude,
      endLat: end.latitude,
      endLon: end.longitude,
      profile: 'walking',
    );

    if (!mounted) return;

    final polyline = directions?['polyline'] as String? ?? '';
    final points = MapUtils.decodePolyline(polyline);

    if (points.isEmpty) {
      setState(() {
        _loadingWalkingRoute = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load walking path.')),
      );
      return;
    }

    setState(() {
      _loadingWalkingRoute = false;
      _walkingRoutePoints = points;
      _polylines = {
        ..._withoutWalkingRoutePolyline(_polylines),
        Polyline(
          polylineId: const PolylineId('google_walking_segment'),
          points: points,
          color: Colors.blueAccent,
          width: 7,
        ),
      };
    });

    await _fitPoints(points, padding: 72);
  }

  List<Map<String, dynamic>> _effectiveRouteSteps() {
    final match = widget.historicalMatch;
    if (match != null) {
      return _historicalRouteSteps(match);
    }

    if (widget.steps.isNotEmpty) return widget.steps;

    return const [];
  }

  bool _isRoadTransitMode(TravelMode mode) {
    return mode == TravelMode.jeepney ||
        mode == TravelMode.bus ||
        mode == TravelMode.fx;
  }

  TravelMode? _inferRoadModeFromLegText(HistoricalRouteLeg leg) {
    final source = [
      leg.signboard,
      leg.via,
      leg.boardStopName,
      leg.alightStopName,
    ].join(' ').toLowerCase();

    if (RegExp(r'\b(fx|uv|van)\b').hasMatch(source)) {
      return TravelMode.fx;
    }

    if (RegExp(r'\b(jeepney|jeep)\b').hasMatch(source)) {
      return TravelMode.jeepney;
    }

    if (RegExp(r'\b(bus|busway|carousel|p2p)\b').hasMatch(source)) {
      return TravelMode.bus;
    }

    return null;
  }

  TravelMode _effectiveRideModeForLeg(HistoricalRouteLeg leg) {
    if (leg.mode == TravelMode.train) return TravelMode.train;
    if (leg.mode == TravelMode.walking) return TravelMode.walking;

    if (_isRoadTransitMode(widget.mode) && _isRoadTransitMode(leg.mode)) {
      return widget.mode;
    }

    final inferredMode = _inferRoadModeFromLegText(leg);
    if (inferredMode != null) return inferredMode;

    return leg.mode;
  }

  String _boardingAreaLabel(TravelMode mode) {
    switch (mode) {
      case TravelMode.jeepney:
        return 'jeepney boarding area';
      case TravelMode.bus:
        return 'bus stop or bus boarding area';
      case TravelMode.fx:
        return 'FX/UV boarding area';
      case TravelMode.train:
        return 'rail station entrance';
      case TravelMode.walking:
        return 'boarding area';
    }
  }

  TravelMode _accessModeForLeg(HistoricalRouteLeg leg) {
    final accessKm = leg.walkToBoardMeters / 1000.0;
    if (leg.mode == TravelMode.train &&
        accessKm > _stationAccessRideThresholdKm) {
      return TravelMode.jeepney;
    }
    return TravelMode.walking;
  }

  TravelMode _finalAccessModeForLeg(
    HistoricalRouteMatch match,
    HistoricalRouteLeg leg,
  ) {
    final accessKm = match.walkFromAlightMeters / 1000.0;
    if (leg.mode == TravelMode.train &&
        accessKm > _stationAccessRideThresholdKm) {
      return TravelMode.jeepney;
    }
    return TravelMode.walking;
  }

  List<Map<String, dynamic>> _historicalRouteSteps(HistoricalRouteMatch match) {
    Map<String, dynamic> step({
      required String instruction,
      required TravelMode mode,
      required double lat,
      required double lng,
      LatLng? walkingStart,
      LatLng? walkingEnd,
    }) {
      return {
        'html_instructions': instruction,
        'travel_mode': mode.name.toUpperCase(),
        'start_location': {
          'lat': lat,
          'lng': lng,
        },
        if (walkingEnd != null)
          'end_location': {
            'lat': walkingEnd.latitude,
            'lng': walkingEnd.longitude,
          },
        if (walkingStart != null && walkingEnd != null) ...{
          'walking_start_lat': walkingStart.latitude,
          'walking_start_lng': walkingStart.longitude,
          'walking_end_lat': walkingEnd.latitude,
          'walking_end_lng': walkingEnd.longitude,
          'is_historical_walking_step': true,
        },
      };
    }

    final legs = match.legs.isNotEmpty
        ? match.legs
        : <HistoricalRouteLeg>[
            HistoricalRouteLeg(
              route: match.route,
              mode: match.route.mode,
              signboard: match.signboard,
              via: match.via,
              boardStopName: match.boardStopName,
              boardStopLat: match.boardStopLat,
              boardStopLon: match.boardStopLon,
              alightStopName: match.alightStopName,
              alightStopLat: match.alightStopLat,
              alightStopLon: match.alightStopLon,
              walkToBoardMeters: match.walkToBoardMeters,
              rideDistanceMeters: match.rideDistanceMeters,
              stopCount: match.stopCount,
            ),
          ];

    final steps = <Map<String, dynamic>>[];

    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final effectiveMode = _effectiveRideModeForLeg(leg);
      final isFirst = i == 0;
      final isLast = i == legs.length - 1;

      if (isFirst) {
        final boardPoint = LatLng(leg.boardStopLat, leg.boardStopLon);
        steps.add(
          step(
            instruction: leg.mode == TravelMode.train
                ? (leg.walkToBoardMeters / 1000.0 >
                        _stationAccessRideThresholdKm
                    ? 'Take a local ride to rail station: ${leg.boardStopName}. This access ride is included in the fare estimate.'
                    : 'Walk to rail station: ${leg.boardStopName}.')
                : 'Walk to the matched ${_boardingAreaLabel(effectiveMode)} near: ${leg.boardStopName}. Confirm the stop and signboard before boarding.',
            mode: _accessModeForLeg(leg),
            lat: widget.origin.latitude,
            lng: widget.origin.longitude,
            walkingStart: widget.origin,
            walkingEnd: boardPoint,
          ),
        );
      }

      steps.add(
        step(
          instruction: effectiveMode == TravelMode.train
              ? 'Board ${_vehicleLabel(effectiveMode)} at ${leg.boardStopName}. Follow the station signs for: ${leg.signboard}${leg.via.trim().isNotEmpty ? ' (${leg.viaLabel})' : ''}.'
              : 'Board ${_vehicleLabel(effectiveMode)}. Look for this signboard: ${leg.signboard}${leg.via.trim().isNotEmpty ? ' (${leg.viaLabel})' : ''}.',
          mode: effectiveMode,
          lat: leg.boardStopLat,
          lng: leg.boardStopLon,
        ),
      );

      steps.add(
        step(
          instruction: effectiveMode == TravelMode.train
              ? 'Ride for about ${leg.stopCount} station${leg.stopCount == 1 ? '' : 's'}. Get off at ${leg.alightStopName} station.'
              : 'Ride for about ${leg.stopCount} stop${leg.stopCount == 1 ? '' : 's'}. Get off at ${leg.alightStopName}.',
          mode: effectiveMode,
          lat: leg.boardStopLat,
          lng: leg.boardStopLon,
        ),
      );

      if (!isLast) {
        final nextLeg = legs[i + 1];
        final transferStart = LatLng(leg.alightStopLat, leg.alightStopLon);
        final transferEnd = LatLng(nextLeg.boardStopLat, nextLeg.boardStopLon);
        steps.add(
          step(
            instruction: nextLeg.mode == TravelMode.train &&
                    nextLeg.walkToBoardMeters / 1000.0 >
                        _stationAccessRideThresholdKm
                ? 'Transfer: take a local ride from ${leg.alightStopName} to ${nextLeg.boardStopName}. This access ride is included in the fare estimate.'
                : 'Transfer: walk from ${leg.alightStopName} to the matched ${_boardingAreaLabel(_effectiveRideModeForLeg(nextLeg))} near ${nextLeg.boardStopName}.',
            mode: _accessModeForLeg(nextLeg),
            lat: leg.alightStopLat,
            lng: leg.alightStopLon,
            walkingStart: transferStart,
            walkingEnd: transferEnd,
          ),
        );
      }
    }

    final finalWalkStart = LatLng(
      legs.last.alightStopLat,
      legs.last.alightStopLon,
    );
    steps.add(
      step(
        instruction: legs.last.mode == TravelMode.train &&
                match.walkFromAlightMeters / 1000.0 >
                    _stationAccessRideThresholdKm
            ? 'Take a local ride from ${legs.last.alightStopName} station to your destination. This ride is included in the fare estimate.'
            : 'Walk from ${legs.last.alightStopName} to your destination.',
        mode: _finalAccessModeForLeg(match, legs.last),
        lat: legs.last.alightStopLat,
        lng: legs.last.alightStopLon,
        walkingStart: finalWalkStart,
        walkingEnd: widget.destination,
      ),
    );

    return steps;
  }

  String _vehicleLabel(TravelMode mode) {
    switch (mode) {
      case TravelMode.jeepney:
        return 'the jeepney';
      case TravelMode.bus:
        return 'the bus';
      case TravelMode.fx:
        return 'the FX/UV van';
      case TravelMode.train:
        return 'the train';
      case TravelMode.walking:
        return 'the route';
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

  Widget _buildFareBreakdownSummary() {
    final lines = widget.fareBreakdown
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return Text(
        'Fare estimate only. Actual fare may vary.',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fare breakdown',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        ...lines.map(_buildFareBreakdownLine),
      ],
    );
  }

  Widget _buildFareBreakdownLine(String line) {
    final parts = _splitFareBreakdownLine(line);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (parts.amount != null) ...[
            const SizedBox(width: 8),
            Text(
              parts.amount!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _FareBreakdownParts _splitFareBreakdownLine(String line) {
    final amountMatch = RegExp(r'₱\s*\d+(?:\.\d+)?').firstMatch(line);
    if (amountMatch == null) return _FareBreakdownParts(line, null);

    final amount = amountMatch.group(0)!.replaceAll(' ', '');
    final label = line
        .replaceFirst(amountMatch.group(0)!, '')
        .replaceAll(RegExp(r'\s*[-:•]\s*$'), '')
        .trim();

    return _FareBreakdownParts(label.isEmpty ? line : label, amount);
  }

  Widget _buildGuideModeRouteGuide() {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveSteps = _effectiveRouteSteps();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Trip Route Guide'),
        backgroundColor: _getModeColor(),
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Guide Mode Demo',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Walk -> Jeepney -> Train -> Walk',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review where to walk, board, transfer, and alight before checking the fare.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...effectiveSteps.asMap().entries.map(
                (entry) => _buildRouteStepCard(
                  step: entry.value,
                  stepIndex: entry.key,
                  totalSteps: effectiveSteps.length,
                  effectiveSteps: effectiveSteps,
                ),
              ),
          const SizedBox(height: 12),
          if (_guideFareVisible)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.32),
                ),
              ),
              child: _buildFareBreakdownSummary(),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _guideFareVisible
                ? () {
                    GuideModeDemoState.saveIntramurosFavorite();
                    widget.guidePresenterController?.signalSafely(
                      GuidePresenterSignal.destinationSaved,
                    );
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                : () {
                    setState(() => _guideFareVisible = true);
                    GuideModeDemoState.viewFareBreakdown();
                    widget.guidePresenterController?.signalSafely(
                      GuidePresenterSignal.fareBreakdownOpened,
                    );
                  },
            icon: Icon(
              _guideFareVisible
                  ? Icons.favorite_rounded
                  : Icons.payments_rounded,
            ),
            label: Text(
              _guideFareVisible
                  ? 'Save Destination'
                  : 'Continue to Fare Breakdown',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guideModeDemo) {
      return _buildGuideModeRouteGuide();
    }
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
                          widget.historicalMatch != null
                              ? 'Using HalaPH GTFS route guidance. Google driving steps are hidden.'
                              : 'Live directions are unavailable. Using estimated route data.',
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
              final effectiveSteps = _effectiveRouteSteps();
              final hasSteps = effectiveSteps.isNotEmpty;
              final itemCount = hasSteps ? effectiveSteps.length + 3 : 4;

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
                                    iconForTravelMode(widget.mode),
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
                                        widget.mode == TravelMode.walking
                                            ? 'Estimated total fare: ₱0'
                                            : widget.fare > 0
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
                                      '${effectiveSteps.length} steps',
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
                                const SizedBox(height: 10),
                                _buildFareBreakdownSummary(),
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
                                    'Detailed step-by-step directions are unavailable for this route.',
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
                    final step = effectiveSteps[stepIndex];
                    return _buildRouteStepCard(
                      step: step,
                      stepIndex: stepIndex,
                      totalSteps: effectiveSteps.length,
                      effectiveSteps: effectiveSteps,
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

  Widget _buildRouteStepCard({
    required Map<String, dynamic> step,
    required int stepIndex,
    required int totalSteps,
    required List<Map<String, dynamic>> effectiveSteps,
  }) {
    final instruction = _stripHtml(step['html_instructions'] as String? ?? '');
    final isCurrentStep = stepIndex == _currentStep;
    final isWalkingStep = _isWalkingStep(step);
    final stepMode = _travelModeForStep(step);
    final stepColor = colorForTravelMode(context, stepMode);
    final isFirst = stepIndex == 0;
    final isLast = stepIndex == totalSteps - 1;
    final distance = _stepDistanceText(step, stepMode);
    final duration = (step['duration'] as Map?)?['text'] as String? ?? '';
    final fare = _stepFareText(step, stepMode);
    final transitInfo = _stepTransitInfo(step);
    final transferHint = _stepTransferHint(
      step: step,
      instruction: instruction,
      stepIndex: stepIndex,
      effectiveSteps: effectiveSteps,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        isFirst ? 4 : 0,
        18,
        isLast ? 28 : 10,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          setState(() {
            _currentStep = stepIndex;
          });

          if (isWalkingStep) {
            await _showWalkingDirectionsForStep(step);
            return;
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Instruction only. Use the walking steps to show a map path.',
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isCurrentStep
                ? stepColor.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrentStep
                  ? stepColor.withValues(alpha: 0.82)
                  : Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.30),
              width: isCurrentStep ? 1.5 : 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStepTimeline(
                  stepIndex: stepIndex,
                  isFirst: isFirst,
                  isLast: isLast,
                  isCurrentStep: isCurrentStep,
                  stepMode: stepMode,
                  stepColor: stepColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _stepTitle(
                                  step: step,
                                  stepIndex: stepIndex,
                                  totalSteps: totalSteps,
                                  instruction: instruction,
                                  mode: stepMode,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TransportModeChip(mode: stepMode, compact: true),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          instruction.isEmpty
                              ? 'Continue to the next step.'
                              : instruction,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: isCurrentStep
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (transitInfo.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildStepCallout(
                            icon: Icons.confirmation_number_rounded,
                            text: transitInfo,
                            color: stepColor,
                          ),
                        ],
                        if (transferHint.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildStepCallout(
                            icon: Icons.transfer_within_a_station_rounded,
                            text: transferHint,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFF6D58A)
                                    : const Color(0xFFB45309),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            if (distance.isNotEmpty)
                              _buildStepMetaChip(
                                icon: Icons.straighten_rounded,
                                label: distance,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            if (duration.isNotEmpty)
                              _buildStepMetaChip(
                                icon: Icons.schedule_rounded,
                                label: duration,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            if (fare.isNotEmpty)
                              _buildStepMetaChip(
                                icon: Icons.payments_rounded,
                                label: fare,
                                color: stepMode == TravelMode.walking
                                    ? colorForTravelMode(
                                        context,
                                        TravelMode.walking,
                                      )
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                          ],
                        ),
                        if (isWalkingStep) ...[
                          const SizedBox(height: 9),
                          _buildWalkingPathHint(isCurrentStep),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepTimeline({
    required int stepIndex,
    required bool isFirst,
    required bool isLast,
    required bool isCurrentStep,
    required TravelMode stepMode,
    required Color stepColor,
  }) {
    final mutedLine = Theme.of(context).colorScheme.outlineVariant;

    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 2,
              color: isFirst
                  ? Colors.transparent
                  : mutedLine.withValues(alpha: 0.58),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: isCurrentStep
                  ? stepColor.withValues(alpha: 0.16)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(color: stepColor.withValues(alpha: 0.30)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    iconForTravelMode(stepMode),
                    color: stepColor,
                    size: 21,
                  ),
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrentStep
                            ? stepColor.withValues(alpha: 0.46)
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: 2,
              color: isLast
                  ? Colors.transparent
                  : mutedLine.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCallout({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkingPathHint(bool isCurrentStep) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF93C5FD)
        : const Color(0xFF2563EB);

    return _buildStepCallout(
      icon: Icons.map_rounded,
      text: _loadingWalkingRoute && isCurrentStep
          ? 'Loading walking path...'
          : isCurrentStep && _walkingRoutePoints.isNotEmpty
              ? 'Walking path shown on the map.'
              : 'Tap to show the walking path on the map.',
      color: color,
    );
  }

  String _stepTransitInfo(Map<String, dynamic> step) {
    final transitDetails = step['transit_details'] as Map<String, dynamic>?;
    if (transitDetails == null) return '';

    final line = transitDetails['line'] as Map<String, dynamic>?;
    final lineName = (line?['short_name'] ?? line?['name'] ?? '').toString();
    final depStop = transitDetails['departure_stop'] as Map<String, dynamic>?;
    final depStopName = depStop?['name'] ?? '';
    final arrStop = transitDetails['arrival_stop'] as Map<String, dynamic>?;
    final arrStopName = arrStop?['name'] ?? '';
    final depTime = transitDetails['departure_time'] as Map<String, dynamic>?;
    final depTimeText = depTime?['text'] ?? '';
    final arrTime = transitDetails['arrival_time'] as Map<String, dynamic>?;
    final arrTimeText = arrTime?['text'] ?? '';

    var detail = '';
    if (lineName.isNotEmpty) detail += 'Board $lineName';
    if (depStopName.toString().isNotEmpty) {
      detail += '${detail.isEmpty ? '' : ' '}at $depStopName';
    }
    if (depTimeText.toString().isNotEmpty) detail += ' ($depTimeText)';
    if (arrStopName.toString().isNotEmpty) detail += ' to $arrStopName';
    if (arrTimeText.toString().isNotEmpty) detail += ' ($arrTimeText)';
    return detail;
  }

  String _stepTitle({
    required Map<String, dynamic> step,
    required int stepIndex,
    required int totalSteps,
    required String instruction,
    required TravelMode mode,
  }) {
    final lower = instruction.toLowerCase();
    if (lower.contains('transfer')) return 'Transfer';
    if (mode == TravelMode.walking) {
      if (stepIndex == totalSteps - 1 || lower.contains('destination')) {
        return 'Walk to destination';
      }
      if (lower.contains('station')) return 'Walk to station';
      if (lower.contains('boarding')) return 'Walk to boarding point';
      return 'Walk';
    }
    if (lower.contains('get off') || lower.contains('alight')) {
      return mode == TravelMode.train ? 'Alight at station' : 'Get off';
    }
    if (lower.contains('ride for')) return 'Ride';
    if (lower.contains('board')) return 'Board ${labelForTravelMode(mode)}';
    return labelForTravelMode(mode);
  }

  String _stepDistanceText(Map<String, dynamic> step, TravelMode mode) {
    final distance = (step['distance'] as Map?)?['text'] as String? ?? '';
    if (distance.isNotEmpty) return distance;
    if (mode != TravelMode.walking) return '';

    final start = _walkingStepStart(step);
    final end = _walkingStepEnd(step);
    if (start == null || end == null) return '';

    final km = BudgetRoutingService.calculateDistance(start, end);
    if (km <= 0) return '';
    return km < 1
        ? '${(km * 1000).round()}m walk'
        : '${km.toStringAsFixed(1)}km walk';
  }

  String _stepFareText(Map<String, dynamic> step, TravelMode mode) {
    final fare = step['fare'];
    if (fare is num) return '₱${fare.toStringAsFixed(0)}';
    if (fare is String && fare.trim().isNotEmpty) return fare.trim();
    if (mode == TravelMode.walking) return '₱0 fare';
    return '';
  }

  String _stepTransferHint({
    required Map<String, dynamic> step,
    required String instruction,
    required int stepIndex,
    required List<Map<String, dynamic>> effectiveSteps,
  }) {
    final lower = instruction.toLowerCase();
    if (lower.contains('transfer')) {
      final nextMode = stepIndex + 1 < effectiveSteps.length
          ? _travelModeForStep(effectiveSteps[stepIndex + 1])
          : null;
      if (nextMode != null && nextMode != TravelMode.walking) {
        return 'Transfer, then continue by ${labelForTravelMode(nextMode)}.';
      }
      return 'Transfer point. Check the next boarding instruction.';
    }

    if (stepIndex == 0) return '';
    final previousMode = _travelModeForStep(effectiveSteps[stepIndex - 1]);
    final currentMode = _travelModeForStep(step);
    if (previousMode != currentMode && currentMode != TravelMode.walking) {
      return 'New ride after transfer.';
    }

    return '';
  }

  String get _destinationLabel {
    final value = widget.destinationName.trim();
    return value.isEmpty ? 'your destination' : value;
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
    final destination = _destinationLabel;
    final historicalReference = _historicalRouteReference;
    final historicalRouteName = historicalReference?.displayName ?? '';

    switch (widget.mode) {
      case TravelMode.jeepney:
        if (lineName.isNotEmpty) {
          return 'Ride the $lineName route heading toward $destination.';
        }
        if (historicalRouteName.isNotEmpty) {
          return 'Historical GTFS clue: $historicalRouteName. Use it as a signboard clue only, then confirm with the driver before boarding.';
        }
        return 'Look for a jeepney signboard heading toward $destination. Confirm with the driver that it passes your drop-off before boarding.';
      case TravelMode.bus:
        if (lineName.isNotEmpty) {
          return 'Ride the $lineName bus route heading toward $destination.';
        }
        if (historicalRouteName.isNotEmpty) {
          return 'Historical GTFS clue: $historicalRouteName. Use it as a direction clue only, then confirm the active route with the conductor.';
        }
        return 'Look for a bus route heading toward $destination or the nearest terminal. Confirm the drop-off point with the conductor before boarding.';
      case TravelMode.train:
        if (lineName.isNotEmpty) {
          return 'Take $lineName toward the station serving $destination.';
        }
        if (historicalRouteName.isNotEmpty) {
          return 'Historical GTFS rail clue: $historicalRouteName. Confirm the current station direction before boarding.';
        }
        return 'Take the MRT/LRT line toward the station nearest $destination, then use the last-mile ride shown in the fare breakdown.';
      case TravelMode.fx:
        if (lineName.isNotEmpty) {
          return 'Ride the $lineName FX/UV route heading toward $destination.';
        }
        if (historicalRouteName.isNotEmpty) {
          return 'Historical GTFS road-route clue: $historicalRouteName. Confirm the active FX/UV terminal route before boarding.';
        }
        return 'Look for an FX/UV terminal route heading toward $destination. Confirm the terminal and drop-off point before boarding.';
      case TravelMode.walking:
        return 'Walk toward $destination using the map preview and available step list.';
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
    final hasHistoricalReference = _historicalRouteReference != null;

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
                        : hasHistoricalReference
                            ? 'Historical GTFS clue'
                            : 'Route direction to look for',
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

  LatLng? _extractStepLocation(Map<String, dynamic> step) {
    try {
      final startLocation = step['start_location'] as Map?;
      if (startLocation != null) {
        final lat = _asDouble(startLocation['lat']);
        final lng = _asDouble(startLocation['lng']);
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isWalkingStep(Map<String, dynamic> step) {
    return _travelModeForStep(step) == TravelMode.walking;
  }

  TravelMode _travelModeForStep(Map<String, dynamic> step) {
    final travelMode = (step['travel_mode'] ?? '').toString().toUpperCase();

    switch (travelMode) {
      case 'WALKING':
        return TravelMode.walking;
      case 'JEEPNEY':
        return TravelMode.jeepney;
      case 'BUS':
        return TravelMode.bus;
      case 'TRAIN':
        return TravelMode.train;
      case 'FX':
        return TravelMode.fx;
    }

    if (travelMode != 'TRANSIT') return TravelMode.walking;

    final transitDetails = step['transit_details'];
    if (transitDetails is! Map) return widget.mode;

    final line = transitDetails['line'];
    if (line is! Map) return widget.mode;

    final vehicle = line['vehicle'];
    final vehicleType =
        vehicle is Map ? (vehicle['type'] ?? '').toString().toUpperCase() : '';
    final vehicleName =
        vehicle is Map ? (vehicle['name'] ?? '').toString().toUpperCase() : '';

    final lineText = [
      line['name'],
      line['short_name'],
      line['agency'],
      vehicleType,
      vehicleName,
    ].whereType<Object>().join(' ').toUpperCase();

    if (lineText.contains('MRT') ||
        lineText.contains('LRT') ||
        lineText.contains('PNR') ||
        lineText.contains('TRAIN') ||
        lineText.contains('RAIL') ||
        lineText.contains('SUBWAY') ||
        lineText.contains('TRAM') ||
        lineText.contains('METRO')) {
      return TravelMode.train;
    }

    if (lineText.contains('FX') ||
        lineText.contains('UV') ||
        lineText.contains('VAN')) {
      return TravelMode.fx;
    }

    if (lineText.contains('JEEP')) return TravelMode.jeepney;
    if (lineText.contains('BUS') ||
        lineText.contains('BUSWAY') ||
        lineText.contains('CAROUSEL') ||
        lineText.contains('P2P')) {
      return TravelMode.bus;
    }

    return widget.mode;
  }

  LatLng? _walkingStepStart(Map<String, dynamic> step) {
    final historicalLat = _asDouble(step['walking_start_lat']);
    final historicalLng = _asDouble(step['walking_start_lng']);
    if (historicalLat != null && historicalLng != null) {
      return LatLng(historicalLat, historicalLng);
    }
    return _extractStepLocation(step);
  }

  LatLng? _walkingStepEnd(Map<String, dynamic> step) {
    final historicalLat = _asDouble(step['walking_end_lat']);
    final historicalLng = _asDouble(step['walking_end_lng']);
    if (historicalLat != null && historicalLng != null) {
      return LatLng(historicalLat, historicalLng);
    }

    final endLocation = step['end_location'] as Map?;
    if (endLocation == null) return null;

    final lat = _asDouble(endLocation['lat']);
    final lng = _asDouble(endLocation['lng']);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Set<Polyline> _withoutWalkingRoutePolyline(Set<Polyline> polylines) {
    return polylines
        .where(
          (polyline) =>
              polyline.polylineId != const PolylineId('google_walking_segment'),
        )
        .toSet();
  }

  Future<void> _fitPoints(
    List<LatLng> points, {
    double padding = 50,
  }) async {
    final controller = _mapController;
    if (controller == null || points.isEmpty) return;

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
      return;
    }

    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    if (south == north && west == east) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        padding,
      ),
    );
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

class _FareBreakdownParts {
  final String label;
  final String? amount;

  const _FareBreakdownParts(this.label, this.amount);
}
