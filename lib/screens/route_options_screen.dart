import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/google_maps_service.dart';
import 'package:halaph/services/fare_service.dart';
import 'package:halaph/models/verified_route.dart';
import 'package:halaph/services/verified_route_service.dart';
import 'package:halaph/services/commuter_type_service.dart';
import 'package:halaph/screens/route_map_screen.dart';
import 'package:halaph/widgets/transport_mode_widgets.dart';

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
  bool _isLoading = true;
  String? _errorMessage;
  List<_TransportFare> _fares = [];
  final Map<String, List<Map<String, dynamic>>> _directionSteps = {};
  LatLng? _origin;
  LatLng? _destination;
  PassengerType _passengerType = PassengerType.regular;

  @override
  void initState() {
    super.initState();
    _loadSavedPassengerTypeAndFares();
  }

  Future<void> _loadSavedPassengerTypeAndFares() async {
    final savedType = await CommuterTypeService().loadCommuterType();
    if (!mounted) return;
    setState(() {
      _passengerType = savedType;
    });
    await _loadFares();
  }

  Future<void> _loadFares() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final origin = await BudgetRoutingService.getCurrentLocation();
      if (origin == null || BudgetRoutingService.isInvalidLocation(origin)) {
        throw Exception('Unable to get your current location.');
      }

      LatLng destination;
      if (widget.destination?.coordinates != null) {
        destination = widget.destination!.coordinates!;
      } else {
        destination = await BudgetRoutingService.geocodeLocation(
              widget.destinationName,
            ) ??
            origin;
      }

      final distance =
          BudgetRoutingService.calculateDistance(origin, destination);
      if (distance == 0) {
        throw Exception('Destination is too close or location unavailable.');
      }

      _origin = origin;
      _destination = destination;

      final modes = [
        _ModeData(
            TravelMode.jeepney,
            'Jeepney',
            iconForTravelMode(TravelMode.jeepney),
            (double distance) => FareService.estimateFare(
                TravelMode.jeepney, distance,
                type: _passengerType),
            'driving'),
        _ModeData(
            TravelMode.bus,
            'Bus',
            iconForTravelMode(TravelMode.bus),
            (double distance) => FareService.estimateFare(
                TravelMode.bus, distance,
                type: _passengerType),
            'driving'),
        _ModeData(
            TravelMode.train,
            'Train (LRT/MRT)',
            iconForTravelMode(TravelMode.train),
            (double distance) => FareService.estimateFare(
                TravelMode.train, distance,
                type: _passengerType),
            'transit'),
        _ModeData(
            TravelMode.fx,
            'FX',
            iconForTravelMode(TravelMode.fx),
            (double distance) => FareService.estimateFare(
                TravelMode.fx, distance,
                type: _passengerType),
            'driving'),
        _ModeData(
            TravelMode.walking,
            'Walking',
            iconForTravelMode(TravelMode.walking),
            (double distance) => FareService.estimateFare(
                TravelMode.walking, distance,
                type: _passengerType),
            'walking'),
      ];
      // If there is a meaningful distance, drop walking from the quick options to better reflect discounts
      if (distance > 0) {
        modes.removeWhere((m) => m.mode == TravelMode.walking);
      }
      _fares = [];
      for (final modeData in modes) {
        final exactWalkMeters = _gtfsMatchRadiusForMode(modeData.mode);
        final nearbyDestinationWalkMeters =
            _gtfsNearbyDestinationRadiusForMode(modeData.mode);

        var historicalMatches =
            await VerifiedRouteService.findHistoricalRouteMatches(
          mode: modeData.mode,
          origin: origin,
          destination: destination,
          limit: 1,
          maxWalkMeters: exactWalkMeters,
          destinationMaxWalkMeters: exactWalkMeters,
        );

        if (historicalMatches.isEmpty &&
            nearbyDestinationWalkMeters > exactWalkMeters) {
          historicalMatches =
              await VerifiedRouteService.findHistoricalRouteMatches(
            mode: modeData.mode,
            origin: origin,
            destination: destination,
            limit: 1,
            maxWalkMeters: exactWalkMeters,
            destinationMaxWalkMeters: nearbyDestinationWalkMeters,
          );
        }

        debugPrint(
          'RouteOptions: ${modeData.name} historical matches=${historicalMatches.length}',
        );
        final historicalMatch =
            historicalMatches.isNotEmpty ? historicalMatches.first : null;

        var commuteEstimate = _estimateFareForRoute(
          modeData.mode,
          distance,
          historicalMatch,
          type: _passengerType,
        );
        var regularCommuteEstimate = _estimateFareForRoute(
          modeData.mode,
          distance,
          historicalMatch,
          type: PassengerType.regular,
        );

        var fare = commuteEstimate.totalFare;
        var baseFare = regularCommuteEstimate.totalFare;
        var fareBreakdown = commuteEstimate.displayLines;
        var displayName = _displayNameForHistoricalMatch(
          modeData,
          historicalMatch,
        );

        final duration =
            BudgetRoutingService.estimateDuration(distance, modeData.mode);

        final isRoadPublicMode = modeData.mode == TravelMode.jeepney ||
            modeData.mode == TravelMode.bus ||
            modeData.mode == TravelMode.fx;
        final isRailMode = modeData.mode == TravelMode.train;

        final isPublicTransportMode = isRoadPublicMode || isRailMode;
        final googleProfile =
            isPublicTransportMode ? 'transit' : modeData.profile;

        final shouldCallGoogleDirections =
            isPublicTransportMode || historicalMatch == null;

        final directionCandidates = shouldCallGoogleDirections
            ? isPublicTransportMode
                ? await GoogleMapsService.getDirectionAlternatives(
                    startLat: origin.latitude,
                    startLon: origin.longitude,
                    endLat: destination.latitude,
                    endLon: destination.longitude,
                    profile: googleProfile,
                  )
                : [
                    if (await GoogleMapsService.getDirections(
                      startLat: origin.latitude,
                      startLon: origin.longitude,
                      endLat: destination.latitude,
                      endLon: destination.longitude,
                      profile: googleProfile,
                    )
                        case final route?)
                      route,
                  ]
            : const <Map<String, dynamic>>[];

        final directions = isPublicTransportMode
            ? _bestLiveDirectionsForMode(
                modeData.mode,
                directionCandidates,
                type: _passengerType,
              )
            : directionCandidates.isNotEmpty
                ? directionCandidates.first
                : null;

        if (!shouldCallGoogleDirections) {
          debugPrint(
            'RouteOptions: skipped Google directions for ${modeData.name}; using GTFS match.',
          );
        }

        final rawSteps =
            (directions?['steps'] as List?)?.cast<Map<String, dynamic>>() ??
                <Map<String, dynamic>>[];
        final rawPolyline = directions?['polyline'] as String? ?? '';

        final rawStepsMatchSelectedMode = _liveStepsContainSelectedMode(
          modeData.mode,
          rawSteps,
        );

        final steps =
            rawStepsMatchSelectedMode ? rawSteps : <Map<String, dynamic>>[];
        final polyline = rawStepsMatchSelectedMode ? rawPolyline : '';

        if (rawSteps.isNotEmpty && !rawStepsMatchSelectedMode) {
          final unsupported = _liveStepsUseUnsupportedPaidTransit(rawSteps);
          debugPrint(
            unsupported
                ? 'RouteOptions: ignored live transit steps for ${modeData.name}; unsupported paid transit mode found.'
                : 'RouteOptions: ignored live transit steps for ${modeData.name}; steps do not include selected mode.',
          );
        }

        final hasRouteShape = steps.isNotEmpty || polyline.trim().isNotEmpty;
        final hasLiveTransitStep = _hasLiveTransitStep(steps);
        final hasLiveRailTransitStep = _hasLiveRailTransitStep(steps);
        final hasHistoricalMatch = historicalMatch != null;

        if (hasLiveTransitStep) {
          commuteEstimate = _estimateFareForLiveSteps(
            steps,
            type: _passengerType,
          );
          regularCommuteEstimate = _estimateFareForLiveSteps(
            steps,
            type: PassengerType.regular,
          );
          fare = commuteEstimate.totalFare;
          baseFare = regularCommuteEstimate.totalFare;
          fareBreakdown = commuteEstimate.displayLines;
          displayName = _displayNameForLiveSteps(modeData, steps);
        }

        if (!hasRouteShape && !hasHistoricalMatch) {
          debugPrint(
            'RouteOptions: skipped ${modeData.name}, no live public transport steps or verified GTFS match.',
          );
          continue;
        }

        if (isRoadPublicMode && !hasHistoricalMatch && !hasLiveTransitStep) {
          debugPrint(
            'RouteOptions: skipped ${modeData.name}, no verified public transport route match or live transit steps.',
          );
          continue;
        }

        if (isRailMode && !hasLiveRailTransitStep && !hasHistoricalMatch) {
          debugPrint(
            'RouteOptions: skipped ${modeData.name}, no live rail or historical rail route match.',
          );
          continue;
        }

        final confidenceLabel = hasLiveTransitStep
            ? 'Verified live transit route'
            : hasHistoricalMatch
                ? historicalMatch.hasTransfer
                    ? 'Historical route match, 1 transfer'
                    : 'Historical route match'
                : 'Live map route';

        final displayHistoricalMatch =
            hasLiveTransitStep ? null : historicalMatch;
        final modeSequence = hasLiveTransitStep
            ? _liveModeSequenceWithWalking(steps)
            : displayHistoricalMatch != null
                ? _historicalModeSequence(modeData.mode, displayHistoricalMatch)
                : <TravelMode>[modeData.mode];
        final isNearbyDropOff = displayHistoricalMatch != null &&
            _isNearbyDropOff(displayHistoricalMatch);
        final confidenceDetail = hasLiveTransitStep
            ? 'Google returned public transport step data with route or stop details.'
            : hasHistoricalMatch
                ? 'Matched against historical GTFS route data. Driving directions are hidden because they are not public transport instructions.'
                : 'Google returned route geometry, but no public transport vehicle details.';

        _directionSteps[modeData.mode.toString()] = steps;

        _fares.add(_TransportFare(
          mode: modeData.mode,
          modeName: displayName,
          icon: modeData.icon,
          modeSequence: modeSequence,
          fare: fare,
          baseFare: baseFare,
          distance: distance,
          duration: duration,
          steps: steps,
          polyline: polyline,
          fareBreakdown: fareBreakdown,
          confidenceLabel: confidenceLabel,
          confidenceDetail: isNearbyDropOff
              ? '$confidenceDetail Nearby route: get off at the listed verified stop, then walk to the destination.'
              : confidenceDetail,
          isVerifiedTransit: hasLiveTransitStep || hasHistoricalMatch,
          historicalMatch: displayHistoricalMatch,
          routeScore: _routeScore(
            mode: modeData.mode,
            fare: fare,
            duration: duration,
            distanceKm: distance,
            historicalMatch: displayHistoricalMatch,
            hasLiveTransitStep: hasLiveTransitStep,
            hasLiveRailTransitStep: hasLiveRailTransitStep,
          ),
        ));
      }

      _fares.sort((a, b) => a.routeScore.compareTo(b.routeScore));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Route to ${widget.destinationName}'),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFares,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // If there are no fares available, show an empty state instead of crashing
    if (_fares.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No verified public transportation route found for the listed vehicle types. HalaPH will not invent jeepney, bus, FX/UV, or train routes when no supported route match exists.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      );
    }
    final bool mapsConfigured = GoogleMapsService.isConfigured;
    return Column(
      children: [
        _buildAnimatedRouteHeader(),
        if (!mapsConfigured)
          Container(
            width: double.infinity,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF332711)
                : Colors.amber[100],
            padding: const EdgeInsets.all(12),
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
                    'Google Maps Directions API key not configured. Route estimates are based on distance. Enable MAPS_API_KEY for live directions.',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFF0C2)
                          : Colors.amber[900],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.blue[50],
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Distance: ${_formatDistance(_fares.first.distance)} • '
                  'Fare type: ${CommuterTypeService.labelFor(_passengerType)} • '
                  'Best option: ₱${_fares.first.fare.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFBFDBFE)
                        : Colors.blue[800],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _fares.length,
            itemBuilder: (context, index) {
              final fare = _fares[index];
              final isBestOption = index == 0;
              return _buildFareCard(fare, isBestOption, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedRouteHeader() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -26 * (1 - value)),
            child: Transform.scale(
              scale: 0.94 + (0.06 * value),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : const Color(0xFFEAF5FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.28)
                : const Color(0xFFBBDEFB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Route options ready',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.blue[900],
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the best way to ${widget.destinationName}.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Colors.blue[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutBack,
              builder: (context, turns, child) {
                return Transform.rotate(
                  angle: turns * 0.35,
                  child: child,
                );
              },
              child: Icon(
                Icons.swipe_up_rounded,
                color: Colors.blue[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareCard(_TransportFare fare, bool isBestOption, int index) {
    debugPrint('ROUTE OPTIONS CARD ANIMATION: ${fare.modeName} index=$index');
    final entranceDuration = Duration(
      milliseconds: 520 + (index * 140).clamp(0, 560),
    );

    void openRouteMap() {
      if (_origin != null && _destination != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RouteMapScreen(
              mode: fare.mode,
              modeName: fare.modeName,
              origin: _origin!,
              destination: _destination!,
              destinationName: widget.destinationName,
              polyline: fare.polyline,
              steps: fare.steps,
              fare: fare.fare,
              fareBreakdown: fare.fareBreakdown,
              historicalMatch: fare.historicalMatch,
            ),
          ),
        );
      }
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: entranceDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 64 * (1 - value)),
            child: Transform.scale(
              scale: 0.90 + (0.10 * value),
              child: child,
            ),
          ),
        );
      },
      child: _RouteOptionPressableCard(
        onTap: openRouteMap,
        isBestOption: isBestOption,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.45, end: 1),
                duration: const Duration(milliseconds: 620),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isBestOption
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF16351F)
                            : Colors.green[100])
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    boxShadow: isBestOption
                        ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    fare.icon,
                    color: isBestOption
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.green[300]
                            : Colors.green[700])
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fare.modeName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isBestOption) ...[
                          const SizedBox(width: 8),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.30, end: 1),
                            duration: const Duration(milliseconds: 760),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF16351F)
                                    : Colors.green[100],
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.20),
                                ),
                              ),
                              child: Text(
                                'BEST OPTION',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.green[200]
                                      : Colors.green[700],
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    TransportModeSequence(
                      modes: fare.modeSequence,
                      compact: true,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${_formatDuration(fare.duration)} • ${_formatDistance(fare.distance)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      fare.confidenceLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: fare.isVerifiedTransit
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.green[300]
                                : Colors.green[700])
                            : (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFF6D58A)
                                : const Color(0xFFB45309)),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fare.confidenceDetail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (fare.historicalMatch != null) ...[
                      const SizedBox(height: 8),
                      _buildHistoricalMatchSummary(fare.historicalMatch!),
                    ],
                    if (fare.steps.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${fare.steps.length} route steps available',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF93C5FD)
                              : Colors.blue[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (fare.fareBreakdown.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...fare.fareBreakdown.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.payments_rounded,
                                size: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  line,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.60, end: 1),
                    duration: const Duration(milliseconds: 620),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Text(
                      (() {
                        final discountPct = fare.baseFare > 0
                            ? ((fare.baseFare - fare.fare) / fare.baseFare) *
                                100
                            : 0.0;
                        return '☑ ${fare.fare > 0 ? '₱${fare.fare.toStringAsFixed(0)}' : 'FREE'}${discountPct > 0 ? ' • ${discountPct.toStringAsFixed(0)}% off' : ''}';
                      })(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isBestOption
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.green[300]
                                : Colors.green[700])
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Map',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.map, size: 16, color: Colors.blue),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoricalMatchSummary(HistoricalRouteMatch match) {
    final firstLeg = match.legs.isNotEmpty ? match.legs.first : null;
    final lastLeg = match.legs.isNotEmpty ? match.legs.last : null;

    final signboard = firstLeg?.signboard ?? match.signboard;
    final boardStop = firstLeg?.boardStopName ?? match.boardStopName;
    final alightStop = lastLeg?.alightStopName ?? match.alightStopName;
    final isNearbyDropOff = _isNearbyDropOff(match);

    Widget row(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label: $value',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Icons.directions_bus_filled_rounded, 'Signboard', signboard),
          row(Icons.location_on_rounded, 'Board at', boardStop),
          row(
            Icons.flag_rounded,
            isNearbyDropOff ? 'Get off near' : 'Get off at',
            alightStop,
          ),
          if (isNearbyDropOff)
            row(
              Icons.directions_walk_rounded,
              'Walk to destination',
              'About ${_formatDistance(match.walkFromAlightMeters / 1000.0)}',
            ),
          if (match.hasTransfer && match.legs.length >= 2)
            row(
              Icons.transfer_within_a_station_rounded,
              'Transfer',
              '${match.legs.first.alightStopName} → ${match.legs[1].boardStopName}',
            ),
        ],
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)}m';
    return '${km.toStringAsFixed(1)}km';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    return '${duration.inMinutes}m';
  }
}

class _RouteOptionPressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isBestOption;

  const _RouteOptionPressableCard({
    required this.child,
    required this.onTap,
    required this.isBestOption,
  });

  @override
  State<_RouteOptionPressableCard> createState() =>
      _RouteOptionPressableCardState();
}

class _RouteOptionPressableCardState extends State<_RouteOptionPressableCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1,
      duration: Duration(milliseconds: _pressed ? 80 : 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isBestOption
                ? Colors.green.withValues(alpha: 0.28)
                : Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isBestOption
                  ? Colors.green.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: widget.isBestOption ? 26 : 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

double _gtfsMatchRadiusForMode(TravelMode mode) {
  switch (mode) {
    case TravelMode.jeepney:
      return 1400;
    case TravelMode.bus:
      return 1800;
    case TravelMode.fx:
      return 1800;
    case TravelMode.train:
      return 1600;
    case TravelMode.walking:
      return 0;
  }
}

double _routeScore({
  required TravelMode mode,
  required double fare,
  required Duration duration,
  required double distanceKm,
  required HistoricalRouteMatch? historicalMatch,
  required bool hasLiveTransitStep,
  required bool hasLiveRailTransitStep,
}) {
  var score = 0.0;

  score += fare * 2.0;
  score += duration.inMinutes * 0.8;
  score += distanceKm * 1.5;

  if (historicalMatch != null) {
    final legWalkMeters = historicalMatch.legs.fold<double>(
      0,
      (total, leg) => total + leg.walkToBoardMeters,
    );
    final totalWalkMeters = historicalMatch.legs.isEmpty
        ? historicalMatch.walkToBoardMeters +
            historicalMatch.walkFromAlightMeters
        : legWalkMeters + historicalMatch.walkFromAlightMeters;

    score += (totalWalkMeters / 1000.0) * 12.0;
    score += historicalMatch.rideDistanceKm * 1.2;
    score += historicalMatch.totalStopCount * 0.8;
    score += historicalMatch.transferCount * 18.0;
    score -= 30.0;
  } else {
    score += 80.0;
  }

  if (hasLiveTransitStep) score -= 20.0;
  if (mode == TravelMode.train && hasLiveRailTransitStep) score -= 25.0;

  if (mode == TravelMode.walking) score += 100.0;

  return score;
}

double _gtfsNearbyDestinationRadiusForMode(TravelMode mode) {
  switch (mode) {
    case TravelMode.jeepney:
    case TravelMode.bus:
    case TravelMode.fx:
      return 1200;
    case TravelMode.train:
      return 1500;
    case TravelMode.walking:
      return 0;
  }
}

bool _isNearbyDropOff(HistoricalRouteMatch match) {
  return match.walkFromAlightMeters > _gtfsMatchRadiusForMode(match.route.mode);
}

const double _stationAccessRideThresholdKm = 0.80;

bool _isRoadTransitMode(TravelMode mode) {
  return mode == TravelMode.jeepney ||
      mode == TravelMode.bus ||
      mode == TravelMode.fx;
}

TravelMode? _inferRoadModeFromLegText(HistoricalRouteLeg leg) {
  final text = [
    leg.signboard,
    leg.via,
    leg.boardStopName,
    leg.alightStopName,
  ].join(' ').toLowerCase();

  if (RegExp(r'\b(fx|uv|van)\b').hasMatch(text)) {
    return TravelMode.fx;
  }

  if (RegExp(r'\b(jeepney|jeep)\b').hasMatch(text)) {
    return TravelMode.jeepney;
  }

  if (RegExp(r'\b(bus|busway|carousel|p2p)\b').hasMatch(text)) {
    return TravelMode.bus;
  }

  return null;
}

TravelMode _effectiveRideModeForLeg(
  TravelMode selectedMode,
  HistoricalRouteLeg leg,
) {
  if (leg.mode == TravelMode.train) return TravelMode.train;
  if (leg.mode == TravelMode.walking) return TravelMode.walking;

  final inferredMode = _inferRoadModeFromLegText(leg);
  if (inferredMode != null) return inferredMode;

  if (_isRoadTransitMode(selectedMode) && _isRoadTransitMode(leg.mode)) {
    return selectedMode;
  }

  return leg.mode;
}

bool _liveStepUsesUnsupportedPaidTransit(Map<String, dynamic> step) {
  final travelMode = (step['travel_mode'] ?? '').toString().toUpperCase();

  if (travelMode == 'WALKING') return false;
  if (travelMode != 'TRANSIT') return false;

  final transitDetails = step['transit_details'];
  if (transitDetails is! Map) return true;

  final line = transitDetails['line'];
  if (line is! Map) return true;

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

  final supported = lineText.contains('MRT') ||
      lineText.contains('LRT') ||
      lineText.contains('PNR') ||
      lineText.contains('TRAIN') ||
      lineText.contains('RAIL') ||
      lineText.contains('SUBWAY') ||
      lineText.contains('TRAM') ||
      lineText.contains('METRO') ||
      lineText.contains('BUS') ||
      lineText.contains('BUSWAY') ||
      lineText.contains('CAROUSEL') ||
      lineText.contains('P2P') ||
      lineText.contains('JEEP') ||
      lineText.contains('FX') ||
      lineText.contains('UV') ||
      lineText.contains('VAN');

  if (supported) return false;

  final explicitlyUnsupported = lineText.contains('FERRY') ||
      lineText.contains('BOAT') ||
      lineText.contains('SHIP') ||
      lineText.contains('WATER') ||
      lineText.contains('PIER') ||
      lineText.contains('PORT') ||
      lineText.contains('TRICYCLE') ||
      lineText.contains('TRIKE') ||
      lineText.contains('MOTORCYCLE') ||
      lineText.contains('TAXI') ||
      lineText.contains('RIDESHARE') ||
      lineText.contains('RIDE SHARE');

  return explicitlyUnsupported || !supported;
}

bool _liveStepsUseUnsupportedPaidTransit(List<Map<String, dynamic>> steps) {
  for (final step in steps) {
    if (_liveStepUsesUnsupportedPaidTransit(step)) return true;
  }

  return false;
}

TravelMode _travelModeForLiveStep(Map<String, dynamic> step) {
  final travelMode = (step['travel_mode'] ?? '').toString().toUpperCase();

  if (travelMode == 'WALKING') return TravelMode.walking;
  if (travelMode != 'TRANSIT') return TravelMode.walking;

  final transitDetails = step['transit_details'];
  if (transitDetails is! Map) return TravelMode.walking;

  final line = transitDetails['line'];
  if (line is! Map) return TravelMode.walking;

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

  if (lineText.contains('JEEP')) {
    return TravelMode.jeepney;
  }

  return TravelMode.bus;
}

double _distanceKmForLiveStep(Map<String, dynamic> step) {
  final distance = step['distance'];

  if (distance is Map) {
    final value = distance['value'];
    if (value is num) return value.toDouble() / 1000.0;

    final text = (distance['text'] ?? '').toString().toLowerCase();

    final km = RegExp(r'([\d.]+)\s*km').firstMatch(text);
    if (km != null) return double.tryParse(km.group(1) ?? '') ?? 0.0;

    final meters = RegExp(r'([\d.]+)\s*m').firstMatch(text);
    if (meters != null) {
      return (double.tryParse(meters.group(1) ?? '') ?? 0.0) / 1000.0;
    }
  }

  return 0.0;
}

bool _liveStepsContainSelectedMode(
  TravelMode selectedMode,
  List<Map<String, dynamic>> steps,
) {
  if (selectedMode == TravelMode.walking) return false;

  for (final step in steps) {
    final mode = _travelModeForLiveStep(step);
    if (mode == selectedMode) return true;
  }

  return false;
}

List<TravelMode> _liveModeSequence(List<Map<String, dynamic>> steps) {
  final sequence = <TravelMode>[];

  for (final step in steps) {
    final mode = _travelModeForLiveStep(step);
    if (mode == TravelMode.walking) continue;
    if (sequence.isNotEmpty && sequence.last == mode) continue;
    sequence.add(mode);
  }

  return sequence;
}

List<TravelMode> _liveModeSequenceWithWalking(
    List<Map<String, dynamic>> steps) {
  final sequence = <TravelMode>[];

  for (final step in steps) {
    _appendMode(sequence, _travelModeForLiveStep(step));
  }

  return sequence;
}

List<TravelMode> _historicalModeSequence(
  TravelMode selectedMode,
  HistoricalRouteMatch match,
) {
  final legs = _historicalFareLegs(match);
  if (legs.isEmpty) return [selectedMode];

  final sequence = <TravelMode>[];
  for (var i = 0; i < legs.length; i++) {
    final leg = legs[i];
    final accessKm = leg.walkToBoardMeters / 1000.0;
    final needsLocalRideToStation = leg.mode == TravelMode.train &&
        accessKm > _stationAccessRideThresholdKm;

    if (accessKm > 0) {
      _appendMode(
        sequence,
        needsLocalRideToStation ? TravelMode.jeepney : TravelMode.walking,
      );
    }

    _appendMode(sequence, _effectiveRideModeForLeg(selectedMode, leg));
  }

  final finalWalkKm = match.walkFromAlightMeters / 1000.0;
  final lastLeg = legs.last;
  final needsLocalRideFromStation = lastLeg.mode == TravelMode.train &&
      finalWalkKm > _stationAccessRideThresholdKm;
  if (finalWalkKm > 0) {
    _appendMode(
      sequence,
      needsLocalRideFromStation ? TravelMode.jeepney : TravelMode.walking,
    );
  }

  return sequence.isEmpty ? [selectedMode] : sequence;
}

void _appendMode(List<TravelMode> sequence, TravelMode mode) {
  if (sequence.isNotEmpty && sequence.last == mode) return;
  sequence.add(mode);
}

double _totalDistanceKmForLiveSteps(List<Map<String, dynamic>> steps) {
  return steps.fold<double>(
    0,
    (total, step) => total + _distanceKmForLiveStep(step),
  );
}

double _walkDistanceKmForLiveSteps(List<Map<String, dynamic>> steps) {
  return steps.fold<double>(0, (total, step) {
    final mode = _travelModeForLiveStep(step);
    if (mode != TravelMode.walking) return total;
    return total + _distanceKmForLiveStep(step);
  });
}

double _durationMinutesForDirections(Map<String, dynamic> directions) {
  final duration = directions['duration'];
  if (duration is num) return duration.toDouble() / 60.0;
  return 0;
}

Map<String, dynamic>? _bestLiveDirectionsForMode(
  TravelMode selectedMode,
  List<Map<String, dynamic>> candidates, {
  required PassengerType type,
}) {
  Map<String, dynamic>? best;
  var bestScore = double.infinity;

  for (final candidate in candidates) {
    final steps = (candidate['steps'] as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];

    if (steps.isEmpty) continue;
    if (!_hasLiveTransitStep(steps)) continue;
    if (_liveStepsUseUnsupportedPaidTransit(steps)) continue;
    if (!_liveStepsContainSelectedMode(selectedMode, steps)) continue;

    final sequence = _liveModeSequence(steps);
    if (sequence.isEmpty) continue;

    final estimate = _estimateFareForLiveSteps(steps, type: type);
    final fare = estimate.totalFare;
    final durationMinutes = _durationMinutesForDirections(candidate);
    final walkKm = _walkDistanceKmForLiveSteps(steps);
    final totalKm = _totalDistanceKmForLiveSteps(steps);
    final transfers = sequence.length > 1 ? sequence.length - 1 : 0;
    final includesTrain = sequence.contains(TravelMode.train);

    var score = 0.0;
    score += fare * 1.4;
    score += durationMinutes * 0.65;
    score += walkKm * 18.0;
    score += transfers * 8.0;

    if (includesTrain && totalKm >= 8) {
      score -= 18.0;
    }

    if (selectedMode == TravelMode.train && includesTrain) {
      score -= 16.0;
    }

    if (score < bestScore) {
      bestScore = score;
      best = candidate;
    }
  }

  return best;
}

String _displayNameForLiveSteps(
  _ModeData modeData,
  List<Map<String, dynamic>> steps,
) {
  final sequence = _liveModeSequence(steps);
  if (sequence.isEmpty) return modeData.name;
  return sequence.map(_vehicleTitleForMode).join(' + ');
}

String _liveStepLabelForMode(TravelMode mode) {
  switch (mode) {
    case TravelMode.jeepney:
      return 'Jeepney ride';
    case TravelMode.bus:
      return 'Bus ride';
    case TravelMode.train:
      return 'MRT/LRT ride';
    case TravelMode.fx:
      return 'FX ride';
    case TravelMode.walking:
      return 'Walk';
  }
}

MultiSegmentFareEstimate _estimateFareForLiveSteps(
  List<Map<String, dynamic>> steps, {
  required PassengerType type,
}) {
  final segments = <FareSegment>[];

  for (final step in steps) {
    final mode = _travelModeForLiveStep(step);
    final distanceKm = _distanceKmForLiveStep(step);

    if (mode == TravelMode.walking) {
      segments.add(
        FareSegment(
          label: 'Walk',
          mode: TravelMode.walking,
          distanceKm: distanceKm,
          fare: 0,
        ),
      );
      continue;
    }

    segments.add(
      FareSegment(
        label: _liveStepLabelForMode(mode),
        mode: mode,
        distanceKm: distanceKm,
        fare: FareService.estimateFare(mode, distanceKm, type: type),
      ),
    );
  }

  return MultiSegmentFareEstimate(segments: segments);
}

String _displayNameForHistoricalMatch(
  _ModeData modeData,
  HistoricalRouteMatch? historicalMatch,
) {
  if (historicalMatch == null) return modeData.name;

  final legs = _historicalFareLegs(historicalMatch);
  if (legs.isEmpty) return modeData.name;

  final sequence = <TravelMode>[];
  for (final leg in legs) {
    final needsLocalRideToStation = leg.mode == TravelMode.train &&
        leg.walkToBoardMeters / 1000.0 > _stationAccessRideThresholdKm;
    if (needsLocalRideToStation) {
      sequence.add(TravelMode.jeepney);
    }
    sequence.add(_effectiveRideModeForLeg(modeData.mode, leg));
  }

  final lastLeg = legs.last;
  final needsLocalRideFromStation = lastLeg.mode == TravelMode.train &&
      historicalMatch.walkFromAlightMeters / 1000.0 >
          _stationAccessRideThresholdKm;
  if (needsLocalRideFromStation) {
    sequence.add(TravelMode.jeepney);
  }

  final deduped = <TravelMode>[];
  for (final mode in sequence) {
    if (mode == TravelMode.walking) continue;
    if (deduped.isNotEmpty && deduped.last == mode) continue;
    deduped.add(mode);
  }

  if (deduped.isEmpty) return modeData.name;
  return deduped.map(_vehicleTitleForMode).join(' + ');
}

List<HistoricalRouteLeg> _historicalFareLegs(HistoricalRouteMatch match) {
  if (match.legs.isNotEmpty) return match.legs;

  return [
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
}

String _vehicleTitleForMode(TravelMode mode) {
  switch (mode) {
    case TravelMode.jeepney:
      return 'Jeepney';
    case TravelMode.bus:
      return 'Bus';
    case TravelMode.train:
      return 'Train';
    case TravelMode.fx:
      return 'FX';
    case TravelMode.walking:
      return 'Walking';
  }
}

String _rideFareLabelForMode(TravelMode mode) {
  switch (mode) {
    case TravelMode.jeepney:
      return 'Jeepney ride';
    case TravelMode.bus:
      return 'Bus ride';
    case TravelMode.train:
      return 'Train ride';
    case TravelMode.fx:
      return 'FX ride';
    case TravelMode.walking:
      return 'Walk';
  }
}

FareSegment _accessSegmentForLeg(
  HistoricalRouteLeg leg,
  PassengerType type, {
  required bool isFirstLeg,
}) {
  final distanceKm = leg.walkToBoardMeters / 1000.0;
  final isTrain = leg.mode == TravelMode.train;
  final needsLocalRide = isTrain && distanceKm > _stationAccessRideThresholdKm;

  if (needsLocalRide) {
    return FareSegment(
      label: isFirstLeg
          ? 'Estimated local jeepney ride to MRT/LRT station'
          : 'Estimated local jeepney ride to connecting station',
      mode: TravelMode.jeepney,
      distanceKm: distanceKm,
      fare: FareService.estimateFare(
        TravelMode.jeepney,
        distanceKm,
        type: type,
      ),
    );
  }

  return FareSegment(
    label: isTrain
        ? (isFirstLeg
            ? 'Walk to MRT/LRT station'
            : 'Walk to connecting station')
        : (isFirstLeg ? 'Walk to first boarding point' : 'Transfer walk'),
    mode: TravelMode.walking,
    distanceKm: distanceKm,
    fare: 0,
  );
}

FareSegment _finalAccessSegmentForMatch(
  HistoricalRouteMatch match,
  PassengerType type,
) {
  final distanceKm = match.walkFromAlightMeters / 1000.0;
  final legs = _historicalFareLegs(match);
  final isTrain = legs.isNotEmpty && legs.last.mode == TravelMode.train;
  final needsLocalRide = isTrain && distanceKm > _stationAccessRideThresholdKm;

  if (needsLocalRide) {
    return FareSegment(
      label: 'Estimated local jeepney ride from MRT/LRT station',
      mode: TravelMode.jeepney,
      distanceKm: distanceKm,
      fare: FareService.estimateFare(
        TravelMode.jeepney,
        distanceKm,
        type: type,
      ),
    );
  }

  return FareSegment(
    label: isTrain ? 'Walk from MRT/LRT station' : 'Walk from final drop-off',
    mode: TravelMode.walking,
    distanceKm: distanceKm,
    fare: 0,
  );
}

MultiSegmentFareEstimate _estimateFareForRoute(
  TravelMode mode,
  double fullDistanceKm,
  HistoricalRouteMatch? historicalMatch, {
  required PassengerType type,
}) {
  if (historicalMatch == null || historicalMatch.rideDistanceKm <= 0) {
    return FareService.estimateCommuteTotal(
      mode,
      fullDistanceKm,
      type: type,
    );
  }

  final legs = _historicalFareLegs(historicalMatch);
  final segments = <FareSegment>[];

  for (var i = 0; i < legs.length; i++) {
    final leg = legs[i];
    final rideKm = leg.rideDistanceKm;
    final effectiveMode = _effectiveRideModeForLeg(mode, leg);
    segments.add(
      _accessSegmentForLeg(
        leg,
        type,
        isFirstLeg: i == 0,
      ),
    );
    segments.add(
      FareSegment(
        label: _rideFareLabelForMode(effectiveMode),
        mode: effectiveMode,
        distanceKm: rideKm,
        fare: FareService.estimateFare(effectiveMode, rideKm, type: type),
      ),
    );
  }

  segments.add(_finalAccessSegmentForMatch(historicalMatch, type));

  return MultiSegmentFareEstimate(segments: segments);
}

class _ModeData {
  final TravelMode mode;
  final String name;
  final IconData icon;
  final double Function(double) fareFn;
  final String profile;

  _ModeData(this.mode, this.name, this.icon, this.fareFn, this.profile);
}

class _TransportFare {
  final TravelMode mode;
  final String modeName;
  final IconData icon;
  final List<TravelMode> modeSequence;
  final double fare;
  final double baseFare;
  final double distance;
  final Duration duration;
  final List<Map<String, dynamic>> steps;
  final String polyline;
  final List<String> fareBreakdown;
  final HistoricalRouteMatch? historicalMatch;
  final String confidenceLabel;
  final String confidenceDetail;
  final bool isVerifiedTransit;
  final double routeScore;

  _TransportFare({
    required this.mode,
    required this.modeName,
    required this.icon,
    required this.modeSequence,
    required this.fare,
    required this.baseFare,
    required this.distance,
    required this.duration,
    this.steps = const [],
    this.polyline = '',
    this.fareBreakdown = const [],
    required this.historicalMatch,
    required this.confidenceLabel,
    required this.confidenceDetail,
    required this.isVerifiedTransit,
    required this.routeScore,
  });
}

bool _hasLiveTransitStep(List<Map<String, dynamic>> steps) {
  for (final step in steps) {
    final travelMode = (step['travel_mode'] ?? '').toString().toUpperCase();
    final transitDetails = step['transit_details'];
    if (travelMode == 'TRANSIT' && transitDetails is Map) {
      return true;
    }
  }
  return false;
}

bool _hasLiveRailTransitStep(List<Map<String, dynamic>> steps) {
  for (final step in steps) {
    final travelMode = (step['travel_mode'] ?? '').toString().toUpperCase();
    final transitDetails = step['transit_details'];
    if (travelMode != 'TRANSIT' || transitDetails is! Map) continue;

    final line = transitDetails['line'];
    if (line is! Map) continue;

    final vehicle = line['vehicle'];
    if (vehicle is! Map) continue;

    final type = (vehicle['type'] ?? '').toString().toUpperCase();
    final name = (vehicle['name'] ?? '').toString().toLowerCase();

    if (type.contains('RAIL') ||
        type == 'SUBWAY' ||
        type == 'TRAIN' ||
        type == 'TRAM' ||
        name.contains('rail') ||
        name.contains('train') ||
        name.contains('lrt') ||
        name.contains('mrt')) {
      return true;
    }
  }
  return false;
}

// Dev mode sheet widget (in-app)
