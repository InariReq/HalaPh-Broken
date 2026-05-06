import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/google_maps_service.dart';
import 'package:halaph/services/fare_service.dart';
import 'package:halaph/screens/route_map_screen.dart';

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
    _loadFares();
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
            'Traditional Jeepney',
            Icons.directions_bus,
            (double distance) => FareService.estimateFare(
                TravelMode.jeepney, distance,
                type: _passengerType),
            'driving'),
        _ModeData(
            TravelMode.bus,
            'Bus (Ordinary/Aircon)',
            Icons.directions_bus,
            (double distance) => FareService.estimateFare(
                TravelMode.bus, distance,
                type: _passengerType),
            'driving'),
        _ModeData(
            TravelMode.train,
            'Train (LRT/MRT)',
            Icons.train,
            (double distance) => FareService.estimateFare(
                TravelMode.train, distance,
                type: _passengerType),
            'transit'),
        _ModeData(
            TravelMode.fx,
            'FX/Van',
            Icons.airport_shuttle,
            (double distance) => FareService.estimateFare(
                TravelMode.fx, distance,
                type: _passengerType),
            'driving'),
        _ModeData(
            TravelMode.walking,
            'Walking',
            Icons.directions_walk,
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
        final fare = FareService.estimateFare(modeData.mode, distance,
            type: _passengerType);
        final duration =
            BudgetRoutingService.estimateDuration(distance, modeData.mode);

        final directions = await GoogleMapsService.getDirections(
          startLat: origin.latitude,
          startLon: origin.longitude,
          endLat: destination.latitude,
          endLon: destination.longitude,
          profile: modeData.profile,
        );

        final steps =
            (directions?['steps'] as List?)?.cast<Map<String, dynamic>>() ??
                <Map<String, dynamic>>[];
        final polyline = directions?['polyline'] as String? ?? '';
        _directionSteps[modeData.mode.toString()] = steps;

        _fares.add(_TransportFare(
          mode: modeData.mode,
          modeName: modeData.name,
          icon: modeData.icon,
          fare: fare,
          distance: distance,
          duration: duration,
          steps: steps,
          polyline: polyline,
        ));
      }

      _fares.sort((a, b) => a.fare.compareTo(b.fare));

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
        actions: [
          PopupMenuButton<PassengerType>(
            onSelected: (pt) {
              setState(() {
                _passengerType = pt;
              });
              // Recalculate fares for the new passenger type
              _loadFares();
            },
            itemBuilder: (context) => <PopupMenuEntry<PassengerType>>[
              const PopupMenuItem(
                  value: PassengerType.regular, child: Text('Regular')),
              const PopupMenuItem(
                  value: PassengerType.student, child: Text('Student')),
              const PopupMenuItem(
                  value: PassengerType.senior, child: Text('Senior')),
              const PopupMenuItem(value: PassengerType.pwd, child: Text('PWD')),
            ],
            icon: Icon(Icons.person),
          ),
        ],
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFares,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // If there are no fares available, show an empty state instead of crashing
    if (_fares.isEmpty) {
      return Center(child: Text('No routes available at this moment.'));
    }
    final bool mapsConfigured = GoogleMapsService.isConfigured;
    return Column(
      children: [
        _buildAnimatedRouteHeader(),
        if (!mapsConfigured)
          Container(
            width: double.infinity,
            color: Colors.amber[100],
            padding: const EdgeInsets.all(12),
            child: Row(
              children: const [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Google Maps Directions API key not configured. Route estimates are based on distance. Enable MAPS_API_KEY for live directions.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Distance: ${_formatDistance(_fares.first.distance)} • '
                  'Cheapest: ₱${_fares.first.fare.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w500,
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
              final isCheapest = index == 0;
              return _buildFareCard(fare, isCheapest, index);
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
          color: const Color(0xFFEAF5FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBBDEFB)),
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
                child: const Icon(
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
                      color: Colors.blue[900],
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
                      color: Colors.blue[700],
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

  Widget _buildFareCard(_TransportFare fare, bool isCheapest, int index) {
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
              polyline: fare.polyline,
              steps: fare.steps,
              fare: fare.fare,
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
        isCheapest: isCheapest,
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
                    color: isCheapest ? Colors.green[100] : Colors.grey[200],
                    boxShadow: isCheapest
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
                    color: isCheapest ? Colors.green[700] : Colors.grey[700],
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isCheapest) ...[
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
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.20),
                                ),
                              ),
                              child: Text(
                                'CHEAPEST',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[700],
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
                    Text(
                      '${_formatDuration(fare.duration)} • ${_formatDistance(fare.distance)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (fare.steps.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${fare.steps.length} route steps available',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w600,
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
                        try {
                          final base = FareService.fareBreakdown(
                            fare.mode,
                            fare.distance,
                          ).baseFare;
                          final discountPct = base > 0
                              ? ((base - fare.fare) / base) * 100
                              : 0.0;
                          return '☑ ${fare.fare > 0 ? '₱${fare.fare.toStringAsFixed(0)}' : 'FREE'}${discountPct > 0 ? ' • ${discountPct.toStringAsFixed(0)}% off' : ''}';
                        } catch (_) {
                          return fare.fare > 0
                              ? '₱${fare.fare.toStringAsFixed(0)}'
                              : 'FREE';
                        }
                      })(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isCheapest ? Colors.green[700] : Colors.black87,
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
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.map, size: 16, color: Colors.blue),
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
  final bool isCheapest;

  const _RouteOptionPressableCard({
    required this.child,
    required this.onTap,
    required this.isCheapest,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isCheapest
                ? Colors.green.withValues(alpha: 0.28)
                : const Color(0xFFE8E8E8),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isCheapest
                  ? Colors.green.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: widget.isCheapest ? 26 : 18,
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
  final double fare;
  final double distance;
  final Duration duration;
  final List<Map<String, dynamic>> steps;
  final String polyline;

  _TransportFare({
    required this.mode,
    required this.modeName,
    required this.icon,
    required this.fare,
    required this.distance,
    required this.duration,
    this.steps = const [],
    this.polyline = '',
  });
}

// Dev mode sheet widget (in-app)
