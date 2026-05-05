import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/utils/dev_mode.dart';
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

  void _openDevModeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => const _DevModeSheetContent(),
    );
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
          IconButton(
            icon: const Icon(Icons.developer_board),
            onPressed: _openDevModeSheet,
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
        _buildDevModeBanner(),
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
              return _buildFareCard(fare, isCheapest);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFareCard(_TransportFare fare, bool isCheapest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
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
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    isCheapest ? Colors.green[100] : Colors.grey[200],
                child: Icon(
                  fare.icon,
                  color: isCheapest ? Colors.green[700] : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          fare.modeName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (isCheapest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'CHEAPEST',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDuration(fare.duration)} • ${_formatDistance(fare.distance)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    // Compute base fare to determine discount percentage.
                    (() {
                      try {
                        final base =
                            FareService.fareBreakdown(fare.mode, fare.distance)
                                .baseFare;
                        final discountPct =
                            base > 0 ? ((base - fare.fare) / base) * 100 : 0.0;
                        return '☑ ${fare.fare > 0 ? '₱${fare.fare.toStringAsFixed(0)}' : 'FREE'}${discountPct > 0 ? ' • ${discountPct.toStringAsFixed(0)}% off' : ''}';
                      } catch (_) {
                        return fare.fare > 0
                            ? '₱${fare.fare.toStringAsFixed(0)}'
                            : 'FREE';
                      }
                    })(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCheapest ? Colors.green[700] : Colors.black87,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Map',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
class _DevModeSheetContent extends StatelessWidget {
  const _DevModeSheetContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_done),
            title: const Text('Online'),
            onTap: () {
              DevModeService.set(DevMode.online);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.offline_bolt),
            title: const Text('Offline'),
            onTap: () {
              DevModeService.set(DevMode.offline);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.router),
            title: const Text('Emulator'),
            onTap: () {
              DevModeService.set(DevMode.emulator);
              Navigator.pop(context);
            },
          ),
          // Dev DB reset (FireStore Emulator) - exposed only in emulator mode
          ListTile(
            leading: const Icon(Icons.delete_forever),
            title: const Text('Reset Dev Firestore Emulator Data'),
            onTap: () async {
              // Only perform if emulator mode is active
              if (DevModeService.current.value == DevMode.emulator) {}
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}

extension DevModeExtensions on DevMode {
  String toShortName() {
    switch (this) {
      case DevMode.online:
        return 'Online';
      case DevMode.offline:
        return 'Offline';
      case DevMode.emulator:
        return 'Emulator';
    }
  }
}

// Banner widget showing current dev mode
Widget _buildDevModeBanner() {
  final mode = DevModeService.current.value;
  final text = mode.toShortName();
  return Container(
    width: double.infinity,
    color: Colors.amber[50],
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.developer_board, size: 14),
        const SizedBox(width: 6),
        Text('Dev mode: $text', style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
