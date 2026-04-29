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
    final publicRoutes = _routes
        .where((route) => route.mode != TravelMode.driving)
        .toList();
    if (_preferredMode == null) return publicRoutes;
    return publicRoutes.where((route) => route.mode == _preferredMode).toList();
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
          if (converted.mode == TravelMode.driving) {
            continue;
          }
          final signature =
              '${converted.mode.name}|${converted.summary}|'
              '${converted.boardStop}|${converted.dropOffStop}|${converted.routeLabel}';
          if (seenSignatures.add(signature)) {
            routes.add(converted);
          }
        }
      }

      final estimatedRoutes = await BudgetRoutingService.calculateBudgetRoutes(
        origin: origin,
        destination: destination,
      );
      for (final estimatedRoute in estimatedRoutes) {
        if (!_shouldAddEstimatedRoute(routes, estimatedRoute.mode)) {
          continue;
        }
        final converted = await _convertBudgetRoute(estimatedRoute, origin);
        final signature =
            '${converted.mode.name}|estimated|${converted.routeLabel}|'
            '${converted.boardStop}|${converted.dropOffStop}';
        if (seenSignatures.add(signature)) {
          routes.add(converted);
        }
      }

      if (routes.isEmpty) {
        throw Exception('No route options were produced.');
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
      destination ??= await DestinationService.getDestination(
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

  bool _shouldAddEstimatedRoute(List<_RouteViewModel> routes, TravelMode mode) {
    if (mode == TravelMode.driving) return false;
    if (mode == TravelMode.train ||
        mode == TravelMode.fx ||
        mode == TravelMode.jeepney) {
      return true;
    }
    final hasSameMode = routes.any((route) => route.mode == mode);
    return !hasSameMode;
  }

  Future<_RouteViewModel> _convertBudgetRoute(
    BudgetRoute route,
    LatLng origin,
  ) async {
    final routeDetails =
        route.routeDetails ??
        _localRouteDetailsForMode(route.mode) ??
        _genericRouteDetailsForMode(route.mode);
    final boardingPoint =
        routeDetails != null && routeDetails.boardingLocation == null
        ? await _findNearbyBoardingPoint(route.mode, origin)
        : null;
    final boardStop = routeDetails == null
        ? null
        : routeDetails.boardingStop ??
              boardingPoint?.name ??
              _fallbackBoardingStop(route.mode);
    final boardLocation = routeDetails == null
        ? null
        : routeDetails.boardingLocation ?? boardingPoint?.location ?? origin;
    final dropOffStop = routeDetails == null
        ? null
        : routeDetails.dropOffStop ?? 'Near ${widget.destinationName}';
    final estimatedGuide = _buildEstimatedGuide(
      route: route,
      details: routeDetails,
      boardStop: boardStop,
      boardLocation: boardLocation,
      dropOffStop: dropOffStop,
    );
    final tips = [
      ...route.tips,
      if (estimatedGuide.transferPoints.isNotEmpty)
        'This is a multi-ride guide. Confirm each signboard before boarding.',
      if (route.mode == TravelMode.jeepney ||
          route.mode == TravelMode.bus ||
          route.mode == TravelMode.fx ||
          route.mode == TravelMode.train)
        'Student, PWD, and senior fares use the standard 20% discount.',
    ];

    return _RouteViewModel(
      id: route.id,
      mode: route.mode,
      duration: route.duration,
      distanceKm: route.distance,
      cost: estimatedGuide.totalCost,
      fareLabel: estimatedGuide.totalCost <= 0.0
          ? 'Free'
          : estimatedGuide.fareDetails.regularFare,
      fareIsConfirmed: false,
      summary: route.summary,
      tips: tips,
      instructions: estimatedGuide.instructions,
      transitLegs: estimatedGuide.transitLegs,
      guideLegs: estimatedGuide.guideLegs,
      routeLabel: estimatedGuide.routeLabel ?? routeDetails?.routeName,
      polyline: route.polyline,
      boardStop: estimatedGuide.boardStop,
      dropOffStop: estimatedGuide.dropOffStop,
      boardLocation: estimatedGuide.boardLocation,
      dropOffLocation: estimatedGuide.dropOffLocation,
      transferPoints: estimatedGuide.transferPoints,
      fareDetails: estimatedGuide.fareDetails,
      routeDetails: routeDetails,
    );
  }

  _EstimatedGuide _buildEstimatedGuide({
    required BudgetRoute route,
    required RouteDetails? details,
    required String? boardStop,
    required LatLng? boardLocation,
    required String? dropOffStop,
  }) {
    final destination = _destinationLocation ?? route.end;
    if (details == null ||
        route.mode == TravelMode.walking ||
        route.mode == TravelMode.driving) {
      return _EstimatedGuide(
        instructions: route.instructions,
        guideLegs: const [],
        transitLegs: const [],
        transferPoints: const [],
        boardStop: boardStop,
        dropOffStop: dropOffStop,
        boardLocation: boardLocation,
        dropOffLocation: route.mode == TravelMode.walking ? null : destination,
        fareDetails: route.fareDetails,
        totalCost: route.cost,
      );
    }

    if (route.mode == TravelMode.train) {
      final firstBoardStop =
          boardStop ??
          details.boardingStop ??
          _fallbackBoardingStop(route.mode);
      final firstBoardLocation =
          boardLocation ?? details.boardingLocation ?? route.start;
      final finalDropStop =
          dropOffStop ??
          details.dropOffStop ??
          'near ${widget.destinationName}';
      final finalDropLocation = details.dropOffLocation ?? destination;
      final railStart = details.keyPoints.isNotEmpty
          ? details.keyPoints.first
          : firstBoardStop;
      final railEnd = details.keyPoints.isNotEmpty
          ? details.keyPoints.last
          : finalDropStop;

      return _EstimatedGuide(
        instructions: route.instructions,
        guideLegs: [
          _GuideLegViewModel(
            mode: TravelMode.walking,
            title: 'Walk to station',
            from: 'Your location',
            to: firstBoardStop,
            instruction: 'Go to $firstBoardStop station.',
          ),
          _GuideLegViewModel(
            mode: TravelMode.train,
            title: 'Ride ${details.routeName}',
            from: railStart,
            to: railEnd,
            instruction:
                'Board ${details.routeName} and follow station signs for any transfers.',
            routeSign: details.routeName,
            fare: route.fareDetails.regularFare,
          ),
          _GuideLegViewModel(
            mode: TravelMode.walking,
            title: 'Walk to destination',
            from: finalDropStop,
            to: widget.destinationName,
            instruction:
                'Exit at $finalDropStop, then walk to ${widget.destinationName}.',
          ),
        ],
        transitLegs: const [],
        transferPoints: const [],
        routeLabel: details.routeName,
        boardStop: firstBoardStop,
        dropOffStop: finalDropStop,
        boardLocation: firstBoardLocation,
        dropOffLocation: finalDropLocation,
        fareDetails: route.fareDetails,
        totalCost: route.cost,
      );
    }

    final firstBoardStop = boardStop ?? _fallbackBoardingStop(route.mode);
    final firstBoardLocation = boardLocation ?? route.start;
    final finalDropStop = dropOffStop ?? 'near ${widget.destinationName}';
    final vehicleLegs = _estimatedVehicleLegs(
      route: route,
      details: details,
      firstBoardStop: firstBoardStop,
      firstBoardLocation: firstBoardLocation,
      finalDropStop: finalDropStop,
      destination: destination,
    );

    final fareDetails = _sumFareDetails(
      vehicleLegs.map((leg) => leg.fareDetails).toList(),
    );
    final routeLabel = vehicleLegs
        .where((leg) => leg.signboard.trim().isNotEmpty)
        .map((leg) => leg.signboard)
        .join(' + ');
    final guideLegs = <_GuideLegViewModel>[
      _GuideLegViewModel(
        mode: TravelMode.walking,
        title: 'Walk to boarding point',
        from: 'Your location',
        to: firstBoardStop,
        instruction: 'Go to $firstBoardStop.',
      ),
      for (final leg in vehicleLegs)
        _GuideLegViewModel(
          mode: route.mode,
          title: 'Ride ${_modeName(route.mode)}',
          from: leg.fromName,
          to: leg.toName,
          instruction:
              'Board ${_modeName(route.mode).toLowerCase()} marked "${leg.signboard}". '
              'Tell the driver/conductor you are getting off at ${leg.toName}.',
          routeSign: leg.signboard,
          fare: leg.fareDetails.regularFare,
          stopCount: leg.stopCount,
        ),
      _GuideLegViewModel(
        mode: TravelMode.walking,
        title: 'Walk to destination',
        from: finalDropStop,
        to: widget.destinationName,
        instruction:
            'After getting off at $finalDropStop, walk to ${widget.destinationName}.',
      ),
    ];
    final transitLegs = vehicleLegs
        .map(
          (leg) => _TransitLegViewModel(
            vehicleLabel: _modeName(route.mode),
            lineLabel: leg.signboard,
            headsign: leg.headsign,
            departureStop: leg.fromName,
            arrivalStop: leg.toName,
            departureTime: '',
            arrivalTime: '',
            stopCount: leg.stopCount,
            departureLocation: leg.fromLocation,
            arrivalLocation: leg.toLocation,
          ),
        )
        .toList();
    final instructions = <String>[
      'Go to $firstBoardStop.',
      details.boardingInstructions,
      for (final leg in vehicleLegs)
        'Ride ${_modeName(route.mode).toLowerCase()} marked "${leg.signboard}" from ${leg.fromName} to ${leg.toName}${leg.stopCount > 0 ? ' (${leg.stopCount} estimated stops)' : ''}.',
      'Get off at $finalDropStop and walk to ${widget.destinationName}.',
      'Ask the driver/conductor before boarding if the vehicle passes your drop-off point.',
    ];

    return _EstimatedGuide(
      instructions: instructions,
      guideLegs: guideLegs,
      transitLegs: transitLegs,
      transferPoints: vehicleLegs
          .skip(1)
          .map(
            (leg) => _TransferPoint(
              name: leg.fromName,
              location: leg.fromLocation,
              note: 'Transfer here to ${leg.signboard}',
            ),
          )
          .toList(),
      routeLabel: routeLabel.isEmpty ? details.routeName : routeLabel,
      boardStop: firstBoardStop,
      dropOffStop: finalDropStop,
      boardLocation: firstBoardLocation,
      dropOffLocation: destination,
      fareDetails: fareDetails,
      totalCost: fareDetails.regular,
    );
  }

  List<_EstimatedVehicleLeg> _estimatedVehicleLegs({
    required BudgetRoute route,
    required RouteDetails details,
    required String firstBoardStop,
    required LatLng firstBoardLocation,
    required String finalDropStop,
    required LatLng destination,
  }) {
    final distance = route.distance;
    final transferHubs = _transferHubsForRoute(route, details);
    final stops = <_NamedPoint>[
      _NamedPoint(firstBoardStop, firstBoardLocation),
      ...transferHubs,
      _NamedPoint(finalDropStop, destination),
    ];

    final legs = <_EstimatedVehicleLeg>[];
    for (var i = 0; i < stops.length - 1; i++) {
      final from = stops[i];
      final to = stops[i + 1];
      final legDistance = _distanceBetween(from.location, to.location);
      final normalizedDistance = legDistance.isFinite && legDistance > 0
          ? legDistance
          : distance / (stops.length - 1);
      final isLastVehicleLeg = i == stops.length - 2;
      final signboard = isLastVehicleLeg
          ? details.routeName
          : _connectorSignboard(route.mode, to.name);
      legs.add(
        _EstimatedVehicleLeg(
          fromName: from.name,
          fromLocation: from.location,
          toName: to.name,
          toLocation: to.location,
          signboard: signboard,
          headsign: isLastVehicleLeg ? widget.destinationName : to.name,
          stopCount: _estimateStopCount(normalizedDistance, route.mode),
          fareDetails: _getFareDetailsForMode(route.mode, normalizedDistance),
        ),
      );
    }
    return legs;
  }

  List<_NamedPoint> _transferHubsForRoute(
    BudgetRoute route,
    RouteDetails details,
  ) {
    if (route.distance < 7) return const [];

    final destination = _destinationLocation ?? route.end;
    final destinationHub = _destinationHub(details, destination);
    final originHub = _nearestHub(route.start);
    final hubs = <_NamedPoint>[];

    if (route.distance >= 18 &&
        _distanceBetween(route.start, originHub.location) > 2.5) {
      hubs.add(originHub);
    }

    if (_distanceBetween(destination, destinationHub.location) > 1.5) {
      hubs.add(destinationHub);
    } else if (route.distance >= 12) {
      hubs.add(_midpointHub(route.start, destination));
    }

    return _dedupeHubs(hubs, destination);
  }

  _NamedPoint _destinationHub(RouteDetails details, LatLng destination) {
    final text =
        '${details.routeName} ${details.description} ${details.keyPoints.join(" ")} ${widget.destinationName} ${widget.destination?.location ?? ''}'
            .toLowerCase();
    if (text.contains('novaliches') ||
        text.contains('fairview') ||
        text.contains('commonwealth') ||
        text.contains('philcoa')) {
      return const _NamedPoint(
        'Philcoa / Commonwealth transfer stop',
        LatLng(14.6537, 121.0523),
      );
    }
    if (text.contains('quiapo') ||
        text.contains('lawton') ||
        text.contains('intramuros') ||
        text.contains('divisoria') ||
        text.contains('manila')) {
      return const _NamedPoint(
        'Lawton / Quiapo transfer stop',
        LatLng(14.5946, 120.9818),
      );
    }
    if (text.contains('bgc') ||
        text.contains('taguig') ||
        text.contains('ayala') ||
        text.contains('makati')) {
      return const _NamedPoint(
        'Ayala / Guadalupe transfer stop',
        LatLng(14.5566, 121.0232),
      );
    }
    return _nearestHub(destination);
  }

  _NamedPoint _nearestHub(LatLng point) {
    return _metroTransitHubs.reduce((best, hub) {
      final bestDistance = _distanceBetween(point, best.location);
      final candidateDistance = _distanceBetween(point, hub.location);
      return candidateDistance < bestDistance ? hub : best;
    });
  }

  _NamedPoint _midpointHub(LatLng origin, LatLng destination) {
    final midpoint = LatLng(
      (origin.latitude + destination.latitude) / 2,
      (origin.longitude + destination.longitude) / 2,
    );
    return _nearestHub(midpoint);
  }

  List<_NamedPoint> _dedupeHubs(List<_NamedPoint> hubs, LatLng destination) {
    final deduped = <_NamedPoint>[];
    for (final hub in hubs) {
      final isDuplicate = deduped.any(
        (existing) => _distanceBetween(existing.location, hub.location) < 0.8,
      );
      final isTooCloseToDestination =
          _distanceBetween(hub.location, destination) < 0.8;
      if (!isDuplicate && !isTooCloseToDestination) {
        deduped.add(hub);
      }
    }
    return deduped.take(2).toList();
  }

  String _connectorSignboard(TravelMode mode, String target) {
    return switch (mode) {
      TravelMode.jeepney => '$target jeepney',
      TravelMode.bus => '$target city bus / EDSA Carousel',
      TravelMode.fx => '$target UV Express / FX',
      TravelMode.train => '$target train connection',
      TravelMode.driving || TravelMode.walking => target,
    };
  }

  int _estimateStopCount(double distanceKm, TravelMode mode) {
    final kmPerStop = switch (mode) {
      TravelMode.jeepney => 0.7,
      TravelMode.bus => 1.3,
      TravelMode.fx => 1.8,
      TravelMode.train => 1.4,
      TravelMode.driving || TravelMode.walking => 0.8,
    };
    return math.max(1, (distanceKm / kmPerStop).round());
  }

  FareDetails _sumFareDetails(List<FareDetails> fares) {
    if (fares.isEmpty) {
      return const FareDetails(regular: 0, student: 0, pwd: 0, senior: 0);
    }
    return FareDetails(
      regular: fares.fold(0.0, (total, fare) => total + fare.regular),
      student: fares.fold(0.0, (total, fare) => total + fare.student),
      pwd: fares.fold(0.0, (total, fare) => total + fare.pwd),
      senior: fares.fold(0.0, (total, fare) => total + fare.senior),
    );
  }

  double _distanceBetween(LatLng point1, LatLng point2) {
    const earthRadius = 6371.0;
    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);
    final a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    final c = 2 * math.asin(math.sqrt(a).clamp(0.0, 1.0));
    return earthRadius * c;
  }

  RouteDetails? _localRouteDetailsForMode(TravelMode mode) {
    if (mode == TravelMode.walking || mode == TravelMode.driving) return null;

    final text =
        '${widget.destinationName} ${widget.destination?.location ?? ''}'
            .toLowerCase();
    final isNorthQuezonCity =
        text.contains('novaliches') ||
        text.contains('fairview') ||
        text.contains('commonwealth') ||
        text.contains('batasan') ||
        text.contains('philcoa');
    final isManilaCore =
        text.contains('manila') ||
        text.contains('intramuros') ||
        text.contains('quiapo') ||
        text.contains('recto') ||
        text.contains('divisoria');
    final isMakatiOrBgc =
        text.contains('makati') ||
        text.contains('ayala') ||
        text.contains('bgc') ||
        text.contains('taguig');

    if (isNorthQuezonCity) {
      return switch (mode) {
        TravelMode.jeepney => const RouteDetails(
          routeName: 'Novaliches Bayan / SM Fairview via Commonwealth',
          routeCode: 'NOV-BAYAN-JEEP',
          keyPoints: [
            'Novaliches Bayan',
            'Fairview',
            'Commonwealth',
            'Philcoa',
          ],
          description: 'Common North Quezon City jeepney corridor.',
          boardingInstructions:
              'Board a jeepney bound for Novaliches Bayan, SM Fairview, or Philcoa/Commonwealth, depending on your direction.',
        ),
        TravelMode.bus => const RouteDetails(
          routeName: 'Novaliches Bayan / Fairview city bus',
          routeCode: 'NOV-BAYAN-BUS',
          keyPoints: [
            'Novaliches Bayan',
            'Fairview',
            'Commonwealth',
            'Quezon Ave',
          ],
          description:
              'Bus corridor serving Novaliches, Fairview, and Commonwealth.',
          boardingInstructions:
              'Board a city bus with Novaliches Bayan, Fairview, or Commonwealth on the signboard.',
        ),
        TravelMode.fx => const RouteDetails(
          routeName: 'Novaliches Bayan / Fairview UV Express',
          routeCode: 'NOV-BAYAN-FX',
          keyPoints: ['UV Express terminal', 'Novaliches Bayan', 'Fairview'],
          description:
              'UV Express / FX vans commonly load at terminals and mall bays.',
          boardingInstructions:
              'Go to the nearest UV Express terminal and look for vans marked Novaliches Bayan or Fairview.',
        ),
        _ => null,
      };
    }

    if (isManilaCore) {
      return switch (mode) {
        TravelMode.jeepney => const RouteDetails(
          routeName: 'Quiapo / Divisoria / Pier jeepney',
          routeCode: 'MNL-CORE-JEEP',
          keyPoints: ['Quiapo', 'Recto', 'Divisoria', 'Lawton', 'Pier'],
          description: 'Common Manila jeepney signboards for the city core.',
          boardingInstructions:
              'Board a jeepney marked Quiapo, Divisoria, Lawton, or Pier based on the nearest terminal.',
        ),
        TravelMode.bus => const RouteDetails(
          routeName: 'Lawton / PITX / Manila city bus',
          routeCode: 'MNL-CORE-BUS',
          keyPoints: ['Lawton', 'Taft', 'PITX', 'Manila City Hall'],
          description:
              'City bus options for central Manila and transfer points.',
          boardingInstructions:
              'Board a bus marked Lawton, PITX, or Manila and confirm it passes your destination.',
        ),
        TravelMode.fx => const RouteDetails(
          routeName: 'Lawton / Quiapo UV Express',
          routeCode: 'MNL-CORE-FX',
          keyPoints: ['UV Express terminal', 'Lawton', 'Quiapo'],
          description:
              'UV Express vans toward Manila load at designated terminals.',
          boardingInstructions:
              'Use the nearest UV Express terminal and choose a van marked Lawton or Quiapo.',
        ),
        _ => null,
      };
    }

    if (isMakatiOrBgc) {
      return switch (mode) {
        TravelMode.jeepney => const RouteDetails(
          routeName: 'Ayala / Guadalupe / BGC jeepney',
          routeCode: 'MKT-BGC-JEEP',
          keyPoints: ['Ayala', 'Guadalupe', 'Market Market', 'BGC'],
          description:
              'Common jeepney connections around Makati, Guadalupe, and BGC.',
          boardingInstructions:
              'Board a jeepney marked Ayala, Guadalupe, Market Market, or BGC depending on the nearest route.',
        ),
        TravelMode.bus => const RouteDetails(
          routeName: 'EDSA Carousel / Ayala / BGC bus',
          routeCode: 'MKT-BGC-BUS',
          keyPoints: ['EDSA Carousel', 'Guadalupe', 'Ayala', 'BGC'],
          description:
              'Bus options along EDSA with connections to Makati and BGC.',
          boardingInstructions:
              'Use the nearest EDSA Carousel or city bus stop and choose buses toward Ayala, Guadalupe, or BGC.',
        ),
        TravelMode.fx => const RouteDetails(
          routeName: 'Ayala / BGC UV Express',
          routeCode: 'MKT-BGC-FX',
          keyPoints: ['UV Express terminal', 'Ayala', 'BGC'],
          description:
              'UV Express vans to Makati and BGC usually load from terminals.',
          boardingInstructions:
              'Go to the nearest UV Express terminal and look for vans marked Ayala or BGC.',
        ),
        _ => null,
      };
    }

    return null;
  }

  RouteDetails? _genericRouteDetailsForMode(TravelMode mode) {
    return switch (mode) {
      TravelMode.jeepney => RouteDetails(
        routeName: '${widget.destinationName} jeepney signboard',
        routeCode: 'LOCAL-JEEP',
        keyPoints: ['Nearest jeepney stop', widget.destinationName],
        description: 'Estimated jeepney guidance using your destination area.',
        boardingInstructions:
            'Go to the nearest jeepney stop or terminal and ask for jeepneys bound for ${widget.destinationName}.',
      ),
      TravelMode.bus => RouteDetails(
        routeName: '${widget.destinationName} bus signboard',
        routeCode: 'LOCAL-BUS',
        keyPoints: ['Nearest bus stop', widget.destinationName],
        description: 'Estimated bus guidance using your destination area.',
        boardingInstructions:
            'Go to the nearest bus stop or terminal and look for buses bound for ${widget.destinationName}.',
      ),
      TravelMode.fx => RouteDetails(
        routeName: '${widget.destinationName} UV Express / FX',
        routeCode: 'LOCAL-FX',
        keyPoints: ['Nearest UV Express terminal', widget.destinationName],
        description:
            'Estimated UV Express / FX guidance using your destination area.',
        boardingInstructions:
            'Go to the nearest UV Express or FX terminal and ask for vans bound for ${widget.destinationName}.',
      ),
      TravelMode.train => RouteDetails(
        routeName: '${widget.destinationName} train connection',
        routeCode: 'LOCAL-TRAIN',
        keyPoints: ['Nearest train station', widget.destinationName],
        description: 'Estimated train transfer guidance.',
        boardingInstructions:
            'Go to the nearest train station and use the line that gets closest to ${widget.destinationName}.',
      ),
      TravelMode.driving || TravelMode.walking => null,
    };
  }

  String _fallbackBoardingStop(TravelMode mode) {
    return switch (mode) {
      TravelMode.jeepney => 'the nearest jeepney stop or terminal',
      TravelMode.bus => 'the nearest bus stop or terminal',
      TravelMode.fx => 'the nearest UV Express / FX terminal',
      TravelMode.train => 'the nearest train station',
      TravelMode.driving => 'your current location',
      TravelMode.walking => 'your current location',
    };
  }

  Future<_BoardingPoint?> _findNearbyBoardingPoint(
    TravelMode mode,
    LatLng origin,
  ) async {
    final placeTypes = switch (mode) {
      TravelMode.train => const ['train_station', 'transit_station'],
      TravelMode.bus => const ['bus_station', 'transit_station'],
      TravelMode.fx => const ['transit_station', 'bus_station'],
      TravelMode.jeepney => const ['transit_station', 'bus_station'],
      TravelMode.driving || TravelMode.walking => const <String>[],
    };

    for (final placeType in placeTypes) {
      final places = await GoogleMapsApiService.findNearbyPlaces(
        location: origin,
        placeType: placeType,
        radius: 1200,
      );
      if (places.isNotEmpty) {
        final place = places.first;
        return _BoardingPoint(place.name, place.location);
      }
    }
    return null;
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
    final guideLegs = <_GuideLegViewModel>[];

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
          departureLocation: td.departureStop.location,
          arrivalLocation: td.arrivalStop.location,
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
        guideLegs.add(
          _GuideLegViewModel(
            mode: _modeFromTransitLine(td.line),
            title: 'Ride ${leg.vehicleLabel}',
            from: leg.departureStop,
            to: leg.arrivalStop,
            instruction:
                'Board ${leg.vehicleLabel} ${leg.lineLabel} toward ${leg.headsign.isEmpty ? widget.destinationName : leg.headsign}.',
            routeSign: leg.routeLabel,
            fare: route.fare?.text,
            stopCount: leg.stopCount,
          ),
        );
      } else {
        final text = _cleanInstruction(step.htmlInstructions);
        if (text.isNotEmpty) {
          instructions.add(text);
          guideLegs.add(
            _GuideLegViewModel(
              mode: _modeFromGoogleStep(step),
              title: _titleForGoogleStep(step),
              from: '',
              to: '',
              instruction: text,
            ),
          );
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
    final routeDetails = transitLegs.isNotEmpty
        ? _routeDetailsFromTransitLeg(transitLegs.first)
        : _localRouteDetailsForMode(mode);

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
      guideLegs: guideLegs,
      routeLabel: routeLabel,
      polyline: polyline.isNotEmpty ? polyline : [origin, destination],
      boardStop: boardStop,
      dropOffStop: dropOffStop,
      boardLocation: boardLocation,
      dropOffLocation: dropOffLocation,
      transferPoints: _transferPointsFromTransitLegs(transitLegs),
      fareDetails: fareIsConfirmed
          ? _fareDetailsFromRegular(mode, cost)
          : _getFareDetailsForMode(mode, distanceKm),
      routeDetails: routeDetails,
    );
  }

  RouteDetails _routeDetailsFromTransitLeg(_TransitLegViewModel leg) {
    final headsignText = leg.headsign.trim().isEmpty
        ? widget.destinationName
        : leg.headsign.trim();
    return RouteDetails(
      routeName: leg.routeLabel,
      routeCode: leg.lineLabel,
      keyPoints: [leg.departureStop, leg.arrivalStop],
      description: '${leg.vehicleLabel} route toward $headsignText.',
      boardingInstructions:
          'Go to ${leg.departureStop} and board ${leg.vehicleLabel} ${leg.lineLabel} toward $headsignText.',
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

  TravelMode _modeFromGoogleStep(GoogleStep step) {
    final mode = step.travelMode.toUpperCase();
    if (mode == 'DRIVING') return TravelMode.driving;
    if (mode == 'WALKING') return TravelMode.walking;
    if (step.transitDetails != null) {
      return _modeFromTransitLine(step.transitDetails!.line);
    }
    return TravelMode.walking;
  }

  TravelMode _modeFromTransitLine(GoogleTransitLine line) {
    final vehicleType = line.vehicleType.toUpperCase();
    if (vehicleType.contains('RAIL') ||
        vehicleType.contains('SUBWAY') ||
        vehicleType.contains('TRAIN') ||
        vehicleType.contains('TRAM')) {
      return TravelMode.train;
    }
    if (vehicleType.contains('BUS')) return TravelMode.bus;
    return TravelMode.jeepney;
  }

  String _titleForGoogleStep(GoogleStep step) {
    return switch (_modeFromGoogleStep(step)) {
      TravelMode.walking => 'Walk',
      TravelMode.driving => 'Drive',
      TravelMode.jeepney => 'Ride jeepney',
      TravelMode.bus => 'Ride bus',
      TravelMode.fx => 'Ride UV / FX',
      TravelMode.train => 'Ride train',
    };
  }

  List<_TransferPoint> _transferPointsFromTransitLegs(
    List<_TransitLegViewModel> legs,
  ) {
    if (legs.length <= 1) return const [];
    return legs.skip(1).where((leg) => leg.departureLocation != null).map((
      leg,
    ) {
      return _TransferPoint(
        name: leg.departureStop,
        location: leg.departureLocation!,
        note: 'Transfer to ${leg.routeLabel}',
      );
    }).toList();
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
      case TravelMode.fx:
        return math.max(
          PhilippineFares.fxBase,
          distanceKm * PhilippineFares.fxPerKm,
        );
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
        mode == TravelMode.jeepney ||
        mode == TravelMode.fx) {
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
      case TravelMode.fx:
        return 'UV Express / FX route';
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

  FareDetails _getFareDetailsForMode(TravelMode mode, double distance) {
    switch (mode) {
      case TravelMode.jeepney:
        return _calculateJeepneyFare(distance);
      case TravelMode.bus:
        return _calculateBusFare(distance);
      case TravelMode.fx:
        return _calculateFxFare(distance);
      case TravelMode.driving:
        final cost = _estimateCost(mode, distance);
        return _fareDetailsFromRegular(mode, cost);
      case TravelMode.train:
        final cost = _estimateCost(mode, distance);
        return _fareDetailsFromRegular(mode, cost);
      case TravelMode.walking:
        return const FareDetails(regular: 0, student: 0, pwd: 0, senior: 0);
    }
  }

  FareDetails _fareDetailsFromRegular(TravelMode mode, double regularFare) {
    if (mode == TravelMode.walking || mode == TravelMode.driving) {
      return FareDetails(
        regular: regularFare,
        student: regularFare,
        pwd: regularFare,
        senior: regularFare,
      );
    }

    return FareDetails(
      regular: regularFare,
      student: regularFare * (1 - PhilippineFares.studentDiscount),
      pwd: regularFare * (1 - PhilippineFares.pwdDiscount),
      senior: regularFare * (1 - PhilippineFares.seniorDiscount),
    );
  }

  FareDetails _calculateJeepneyFare(double distance) {
    double regularFare;
    if (distance <= 4) {
      regularFare = PhilippineFares.traditionalJeepneyBase;
    } else {
      regularFare =
          PhilippineFares.traditionalJeepneyBase +
          (distance - 4) * PhilippineFares.traditionalJeepneyPerKm;
    }

    return _fareDetailsFromRegular(TravelMode.jeepney, regularFare);
  }

  FareDetails _calculateBusFare(double distance) {
    double regularFare;
    if (distance <= 5) {
      regularFare = PhilippineFares.airconBusBase;
    } else {
      regularFare =
          PhilippineFares.airconBusBase +
          (distance - 5) * PhilippineFares.busPerKm;
    }

    return _fareDetailsFromRegular(TravelMode.bus, regularFare);
  }

  FareDetails _calculateFxFare(double distance) {
    final regularFare = math.max(
      PhilippineFares.fxBase,
      distance * PhilippineFares.fxPerKm,
    );

    return _fareDetailsFromRegular(TravelMode.fx, regularFare);
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

    try {
      while (index < encoded.length) {
        int shift = 0;
        int result = 0;
        int byte;

        do {
          if (index >= encoded.length) return points;
          byte = encoded.codeUnitAt(index++) - 63;
          result |= (byte & 0x1f) << shift;
          shift += 5;
        } while (byte >= 0x20);
        final deltaLat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
        lat += deltaLat;

        shift = 0;
        result = 0;
        do {
          if (index >= encoded.length) return points;
          byte = encoded.codeUnitAt(index++) - 63;
          result |= (byte & 0x1f) << shift;
          shift += 5;
        } while (byte >= 0x20);
        final deltaLng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
        lng += deltaLng;

        points.add(LatLng(lat / 1e5, lng / 1e5));
      }
    } catch (_) {
      return points;
    }
    return points;
  }

  void _refreshMapOverlays() {
    final origin = _currentLocation;
    final destination = _destinationLocation;
    final route = _selectedRoute;
    if (!mounted || origin == null || destination == null) return;

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
    if (route != null) {
      for (var i = 0; i < route.transferPoints.length; i++) {
        final transfer = route.transferPoints[i];
        markers.add(
          Marker(
            markerId: MarkerId('transfer_$i'),
            position: transfer.location,
            infoWindow: InfoWindow(
              title: 'Transfer',
              snippet: '${transfer.name} • ${transfer.note}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow,
            ),
          ),
        );
      }
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

    if (!mounted) return;
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
      case TravelMode.fx:
        return const Color(0xFF00897B);
      case TravelMode.train:
        return const Color(0xFF8E24AA);
    }
  }

  Future<void> _fitMapToRoute() async {
    final controller = _mapController;
    final route = _selectedRoute;
    if (!mounted ||
        controller == null ||
        route == null ||
        route.polyline.isEmpty) {
      return;
    }

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

    if ((maxLat - minLat).abs() < 0.0005) {
      maxLat += 0.0005;
      minLat -= 0.0005;
    }
    if ((maxLng - minLng).abs() < 0.0005) {
      maxLng += 0.0005;
      minLng -= 0.0005;
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
      case TravelMode.fx:
        return 'UV / FX';
      case TravelMode.train:
        return 'Train';
    }
  }

  IconData _modeIcon(TravelMode mode) {
    switch (mode) {
      case TravelMode.walking:
        return Icons.directions_walk;
      case TravelMode.driving:
        return Icons.directions_car;
      case TravelMode.jeepney:
        return Icons.local_taxi;
      case TravelMode.bus:
        return Icons.directions_bus;
      case TravelMode.fx:
        return Icons.airport_shuttle;
      case TravelMode.train:
        return Icons.train;
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
      TravelMode.fx,
      TravelMode.train,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        route.fareDetails.regularFare,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (route.mode != TravelMode.walking &&
                          route.mode != TravelMode.driving)
                        Text(
                          'Student: ${route.fareDetails.studentFare}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
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

  Widget _buildFareRow(String label, String fare) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            fare,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
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
          // Fare Details
          if (route.mode != TravelMode.walking) ...[
            const Text(
              'Fare Details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFADD8E6)),
              ),
              child: Column(
                children: [
                  _buildFareRow('Regular', route.fareDetails.regularFare),
                  if (route.mode != TravelMode.driving) ...[
                    _buildFareRow(
                      'Student (20% off)',
                      route.fareDetails.studentFare,
                    ),
                    _buildFareRow('PWD (20% off)', route.fareDetails.pwdFare),
                    _buildFareRow(
                      'Senior (20% off)',
                      route.fareDetails.seniorFare,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Route Details
          if (route.routeDetails != null) ...[
            const Text(
              'Route Information',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8DC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD700)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.routeDetails!.routeName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(route.routeDetails!.description),
                  const SizedBox(height: 8),
                  Text(
                    'Key Points: ${route.routeDetails!.keyPoints.join(" → ")}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    route.routeDetails!.boardingInstructions,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
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
          if (route.guideLegs.isNotEmpty) ...[
            const Text(
              'Full Ride Plan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...route.guideLegs.asMap().entries.map(_buildGuideLegCard),
            const SizedBox(height: 4),
          ] else if (route.transitLegs.isNotEmpty) ...[
            const Text(
              'Ride Plan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...route.transitLegs.asMap().entries.map(_buildTransitLegCard),
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

  Widget _buildGuideLegCard(MapEntry<int, _GuideLegViewModel> entry) {
    final leg = entry.value;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE7FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _modeColor(leg.mode).withValues(alpha: 0.12),
            child: Icon(
              _modeIcon(leg.mode),
              size: 16,
              color: _modeColor(leg.mode),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.key + 1}. ${leg.title}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (leg.from.isNotEmpty || leg.to.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      leg.from,
                      leg.to,
                    ].where((value) => value.isNotEmpty).join(' → '),
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
                const SizedBox(height: 4),
                Text(leg.instruction),
                if (leg.routeSign != null && leg.routeSign!.isNotEmpty)
                  Text(
                    'Signboard: ${leg.routeSign}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                if (leg.stopCount != null && leg.stopCount! > 0)
                  Text('Estimated stops: ${leg.stopCount}'),
                if (leg.fare != null && leg.fare!.isNotEmpty)
                  Text('Fare: ${leg.fare}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitLegCard(MapEntry<int, _TransitLegViewModel> entry) {
    return Container(
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
    );
  }
}

const List<_NamedPoint> _metroTransitHubs = [
  _NamedPoint('Cubao transfer stop', LatLng(14.6196, 121.0510)),
  _NamedPoint(
    'North Avenue / SM North transfer stop',
    LatLng(14.6526, 121.0328),
  ),
  _NamedPoint(
    'Philcoa / Commonwealth transfer stop',
    LatLng(14.6537, 121.0523),
  ),
  _NamedPoint('Monumento transfer stop', LatLng(14.6570, 120.9846)),
  _NamedPoint('Lawton / Quiapo transfer stop', LatLng(14.5946, 120.9818)),
  _NamedPoint('Ayala transfer stop', LatLng(14.5566, 121.0232)),
  _NamedPoint('Guadalupe transfer stop', LatLng(14.5666, 121.0459)),
  _NamedPoint('PITX transfer terminal', LatLng(14.5107, 120.9914)),
];

class _NamedPoint {
  final String name;
  final LatLng location;

  const _NamedPoint(this.name, this.location);
}

class _BoardingPoint {
  final String name;
  final LatLng location;

  const _BoardingPoint(this.name, this.location);
}

class _TransferPoint {
  final String name;
  final LatLng location;
  final String note;

  const _TransferPoint({
    required this.name,
    required this.location,
    required this.note,
  });
}

class _EstimatedVehicleLeg {
  final String fromName;
  final LatLng fromLocation;
  final String toName;
  final LatLng toLocation;
  final String signboard;
  final String headsign;
  final int stopCount;
  final FareDetails fareDetails;

  const _EstimatedVehicleLeg({
    required this.fromName,
    required this.fromLocation,
    required this.toName,
    required this.toLocation,
    required this.signboard,
    required this.headsign,
    required this.stopCount,
    required this.fareDetails,
  });
}

class _EstimatedGuide {
  final List<String> instructions;
  final List<_GuideLegViewModel> guideLegs;
  final List<_TransitLegViewModel> transitLegs;
  final List<_TransferPoint> transferPoints;
  final String? routeLabel;
  final String? boardStop;
  final String? dropOffStop;
  final LatLng? boardLocation;
  final LatLng? dropOffLocation;
  final FareDetails fareDetails;
  final double totalCost;

  const _EstimatedGuide({
    required this.instructions,
    required this.guideLegs,
    required this.transitLegs,
    required this.transferPoints,
    this.routeLabel,
    this.boardStop,
    this.dropOffStop,
    this.boardLocation,
    this.dropOffLocation,
    required this.fareDetails,
    required this.totalCost,
  });
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
  final List<_GuideLegViewModel> guideLegs;
  final String? routeLabel;
  final List<LatLng> polyline;
  final String? boardStop;
  final String? dropOffStop;
  final LatLng? boardLocation;
  final LatLng? dropOffLocation;
  final List<_TransferPoint> transferPoints;
  final FareDetails fareDetails;
  final RouteDetails? routeDetails;

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
    required this.guideLegs,
    required this.routeLabel,
    required this.polyline,
    required this.boardStop,
    required this.dropOffStop,
    required this.boardLocation,
    required this.dropOffLocation,
    required this.transferPoints,
    required this.fareDetails,
    this.routeDetails,
  });
}

class _GuideLegViewModel {
  final TravelMode mode;
  final String title;
  final String from;
  final String to;
  final String instruction;
  final String? routeSign;
  final String? fare;
  final int? stopCount;

  const _GuideLegViewModel({
    required this.mode,
    required this.title,
    required this.from,
    required this.to,
    required this.instruction,
    this.routeSign,
    this.fare,
    this.stopCount,
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
  final LatLng? departureLocation;
  final LatLng? arrivalLocation;

  _TransitLegViewModel({
    required this.vehicleLabel,
    required this.lineLabel,
    required this.headsign,
    required this.departureStop,
    required this.arrivalStop,
    required this.departureTime,
    required this.arrivalTime,
    required this.stopCount,
    this.departureLocation,
    this.arrivalLocation,
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
