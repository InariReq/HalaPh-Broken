import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/google_maps_api_service.dart';

// 2026 Philippine Transport Costs - EASY TO UPDATE!
class PhilippineFares {
  // Jeepney Fares (2026 rates)
  static const double traditionalJeepneyBase = 14.0; // Base fare for first 4km
  static const double traditionalJeepneyPerKm = 2.0; // Per km after 4km
  static const double modernJeepneyBase = 17.0; // Modern jeepney base fare
  static const double modernJeepneyPerKm = 2.4; // Per km after 4km

  // Bus Fares (2026 rates)
  static const double ordinaryBusBase = 15.0; // Ordinary bus base fare
  static const double airconBusBase = 18.0; // Aircon bus base fare
  static const double busPerKm = 3.0; // Per km after base distance

  // Train Fares (2026 rates)
  static const double lrt1Base = 15.0;
  static const double lrt2Base = 15.0;
  static const double mrt3Base = 15.0;
  static const double trainPerStation = 1.5;
  static const double trainMax = 35.0;

  // FX/Van Fares (2026 rates)
  static const double fxBase = 30.0; // Estimated minimum fare
  static const double fxPerKm = 2.4; // LTFRB UV Express per-km reference

  // Driving Costs (2026 rates)
  static const double fuelPricePerLiter = 65.0; // Average gasoline price
  static const double vehicleFuelConsumption = 8.0; // km per liter
  static const double parkingRatePerHour = 50.0; // Metro Manila average

  // Toll Fees (Major Expressways - 2026 rates)
  static const Map<String, double> tollFees = {
    'NLEX': 45.0, // North Luzon Expressway
    'SLEX': 35.0, // South Luzon Expressway
    'Skyway': 55.0, // Skyway Stage 1-3
    'NAIA Expressway': 40.0,
    'TPLEX': 30.0, // Tarlac-Pangasinan-La Union Expressway
    'CAVITEX': 40.0, // Cavite Expressway
  };

  // Discounted Fares for Students, PWD, Seniors
  static const double studentDiscount = 0.20; // 20% discount
  static const double pwdDiscount = 0.20; // 20% discount
  static const double seniorDiscount = 0.20; // 20% discount
}

enum TravelMode { driving, jeepney, bus, train, fx, walking }

class BudgetRoute {
  final String id;
  final TravelMode mode;
  final LatLng start;
  final LatLng end;
  final Duration duration;
  final double distance;
  final double cost;
  final List<String> instructions;
  final List<LatLng> polyline;
  final String summary;
  final List<String> tips;
  final FareDetails fareDetails;
  final RouteDetails? routeDetails;

  BudgetRoute({
    required this.id,
    required this.mode,
    required this.start,
    required this.end,
    required this.duration,
    required this.distance,
    required this.cost,
    required this.instructions,
    required this.polyline,
    required this.summary,
    required this.tips,
    required this.fareDetails,
    this.routeDetails,
  });
}

class FareDetails {
  final double regular;
  final double student;
  final double pwd;
  final double senior;

  const FareDetails({
    required this.regular,
    required this.student,
    required this.pwd,
    required this.senior,
  });

  String get regularFare => 'PHP ${regular.toStringAsFixed(0)}';
  String get studentFare => 'PHP ${student.toStringAsFixed(0)}';
  String get pwdFare => 'PHP ${pwd.toStringAsFixed(0)}';
  String get seniorFare => 'PHP ${senior.toStringAsFixed(0)}';
}

class RouteDetails {
  final String routeName;
  final String routeCode;
  final List<String> keyPoints;
  final String description;
  final String boardingInstructions;
  final String? boardingStop;
  final String? dropOffStop;
  final LatLng? boardingLocation;
  final LatLng? dropOffLocation;

  const RouteDetails({
    required this.routeName,
    required this.routeCode,
    required this.keyPoints,
    required this.description,
    required this.boardingInstructions,
    this.boardingStop,
    this.dropOffStop,
    this.boardingLocation,
    this.dropOffLocation,
  });
}

enum RouteType { jeepney, bus, fx }

class PopularRoute {
  final String routeCode;
  final String routeName;
  final List<String> keyPoints;
  final double estimatedFare;
  final String description;
  final RouteType type;

  PopularRoute({
    required this.routeCode,
    required this.routeName,
    required this.keyPoints,
    required this.estimatedFare,
    required this.description,
    required this.type,
  });
}

class _RailStation {
  final String name;
  final LatLng location;

  const _RailStation(this.name, this.location);
}

class _RailLine {
  final String code;
  final String name;
  final String colorHex;
  final List<_RailStation> stations;

  const _RailLine({
    required this.code,
    required this.name,
    required this.colorHex,
    required this.stations,
  });
}

class _RailTransfer {
  final String firstLineCode;
  final String firstStationName;
  final String secondLineCode;
  final String secondStationName;
  final int walkMinutes;

  const _RailTransfer({
    required this.firstLineCode,
    required this.firstStationName,
    required this.secondLineCode,
    required this.secondStationName,
    required this.walkMinutes,
  });
}

class _RailStationMatch {
  final _RailLine line;
  final _RailStation station;
  final int stationIndex;
  final double distanceKm;

  const _RailStationMatch({
    required this.line,
    required this.station,
    required this.stationIndex,
    required this.distanceKm,
  });
}

class _RailSegment {
  final _RailLine line;
  final _RailStation from;
  final _RailStation to;
  final int stopCount;

  const _RailSegment({
    required this.line,
    required this.from,
    required this.to,
    required this.stopCount,
  });
}

class BudgetRoutingService {
  static const List<_RailLine> _railLines = [
    _RailLine(
      code: 'LRT-1',
      name: 'LRT-1',
      colorHex: '#F7931E',
      stations: [
        _RailStation('Fernando Poe Jr.', LatLng(14.6576, 121.0197)),
        _RailStation('Balintawak', LatLng(14.6570, 121.0030)),
        _RailStation('Monumento', LatLng(14.6544, 120.9838)),
        _RailStation('5th Avenue', LatLng(14.6447, 120.9836)),
        _RailStation('R. Papa', LatLng(14.6362, 120.9822)),
        _RailStation('Abad Santos', LatLng(14.6307, 120.9814)),
        _RailStation('Blumentritt', LatLng(14.6226, 120.9829)),
        _RailStation('Tayuman', LatLng(14.6167, 120.9827)),
        _RailStation('Bambang', LatLng(14.6112, 120.9825)),
        _RailStation('Doroteo Jose', LatLng(14.6054, 120.9822)),
        _RailStation('Carriedo', LatLng(14.5991, 120.9813)),
        _RailStation('Central Terminal', LatLng(14.5927, 120.9816)),
        _RailStation('United Nations', LatLng(14.5826, 120.9847)),
        _RailStation('Pedro Gil', LatLng(14.5766, 120.9880)),
        _RailStation('Quirino', LatLng(14.5703, 120.9916)),
        _RailStation('Vito Cruz', LatLng(14.5635, 120.9946)),
        _RailStation('Gil Puyat', LatLng(14.5542, 120.9971)),
        _RailStation('Libertad', LatLng(14.5476, 120.9986)),
        _RailStation('EDSA', LatLng(14.5386, 121.0007)),
        _RailStation('Baclaran', LatLng(14.5342, 120.9984)),
        _RailStation('Redemptorist-Aseana', LatLng(14.5307, 120.9933)),
        _RailStation('MIA', LatLng(14.5208, 120.9938)),
        _RailStation('Asia World', LatLng(14.5160, 120.9905)),
        _RailStation('Ninoy Aquino', LatLng(14.5064, 120.9929)),
        _RailStation('Dr. Santos', LatLng(14.4854, 120.9922)),
      ],
    ),
    _RailLine(
      code: 'LRT-2',
      name: 'LRT-2',
      colorHex: '#662D91',
      stations: [
        _RailStation('Recto', LatLng(14.6038, 120.9831)),
        _RailStation('Legarda', LatLng(14.6009, 120.9925)),
        _RailStation('Pureza', LatLng(14.6017, 121.0053)),
        _RailStation('V. Mapa', LatLng(14.6040, 121.0170)),
        _RailStation('J. Ruiz', LatLng(14.6107, 121.0262)),
        _RailStation('Gilmore', LatLng(14.6137, 121.0349)),
        _RailStation('Betty Go-Belmonte', LatLng(14.6187, 121.0423)),
        _RailStation('Araneta Center-Cubao', LatLng(14.6227, 121.0522)),
        _RailStation('Anonas', LatLng(14.6280, 121.0647)),
        _RailStation('Katipunan', LatLng(14.6313, 121.0722)),
        _RailStation('Santolan', LatLng(14.6223, 121.0865)),
        _RailStation('Marikina-Pasig', LatLng(14.6204, 121.1008)),
        _RailStation('Antipolo', LatLng(14.6258, 121.1216)),
      ],
    ),
    _RailLine(
      code: 'MRT-3',
      name: 'MRT-3',
      colorHex: '#0071BC',
      stations: [
        _RailStation('North Avenue', LatLng(14.6526, 121.0328)),
        _RailStation('Quezon Avenue', LatLng(14.6425, 121.0387)),
        _RailStation('GMA Kamuning', LatLng(14.6350, 121.0433)),
        _RailStation('Araneta Center-Cubao', LatLng(14.6191, 121.0526)),
        _RailStation('Santolan-Annapolis', LatLng(14.6072, 121.0566)),
        _RailStation('Ortigas', LatLng(14.5875, 121.0567)),
        _RailStation('Shaw Boulevard', LatLng(14.5811, 121.0534)),
        _RailStation('Boni', LatLng(14.5738, 121.0481)),
        _RailStation('Guadalupe', LatLng(14.5666, 121.0451)),
        _RailStation('Buendia', LatLng(14.5542, 121.0349)),
        _RailStation('Ayala', LatLng(14.5491, 121.0278)),
        _RailStation('Magallanes', LatLng(14.5411, 121.0198)),
        _RailStation('Taft Avenue', LatLng(14.5376, 121.0014)),
      ],
    ),
  ];

  static const List<_RailTransfer> _railTransfers = [
    _RailTransfer(
      firstLineCode: 'LRT-1',
      firstStationName: 'Doroteo Jose',
      secondLineCode: 'LRT-2',
      secondStationName: 'Recto',
      walkMinutes: 6,
    ),
    _RailTransfer(
      firstLineCode: 'LRT-1',
      firstStationName: 'EDSA',
      secondLineCode: 'MRT-3',
      secondStationName: 'Taft Avenue',
      walkMinutes: 7,
    ),
    _RailTransfer(
      firstLineCode: 'LRT-2',
      firstStationName: 'Araneta Center-Cubao',
      secondLineCode: 'MRT-3',
      secondStationName: 'Araneta Center-Cubao',
      walkMinutes: 8,
    ),
  ];

  // Popular jeepney, bus, and FX routes in Metro Manila
  static final List<PopularRoute> popularRoutes = [
    // Jeepney Routes
    PopularRoute(
      routeCode: 'EDSA-CRTM',
      routeName: 'EDSA Carousel (BGC to Pasay)',
      keyPoints: ['BGC', 'Guadalupe', 'Ortigas', 'Shaw', 'Makati', 'Pasay'],
      estimatedFare: 15.0,
      description: 'Modern bus route along EDSA with dedicated lanes',
      type: RouteType.bus,
    ),
    PopularRoute(
      routeCode: 'QC-CIRCLE',
      routeName: 'Quezon City Circle',
      keyPoints: ['Quezon Ave', 'Philcoa', 'UP Diliman', 'Kamuning', 'Cubao'],
      estimatedFare: 14.0,
      description: 'Traditional jeepney route around QC Circle area',
      type: RouteType.jeepney,
    ),
    PopularRoute(
      routeCode: 'COMMONWEALTH',
      routeName: 'Commonwealth Avenue',
      keyPoints: ['Fairview', 'Batasan', 'Philcoa', 'Quezon Ave'],
      estimatedFare: 16.0,
      description: 'Long route along Commonwealth Avenue',
      type: RouteType.jeepney,
    ),
    PopularRoute(
      routeCode: 'QUIAPO-DIVISORIA',
      routeName: 'Quiapo to Divisoria',
      keyPoints: ['Quiapo', 'Recto', 'Avenida', 'Divisoria'],
      estimatedFare: 12.0,
      description: 'Short route between shopping districts',
      type: RouteType.jeepney,
    ),
    PopularRoute(
      routeCode: 'MAKATI-LOOP',
      routeName: 'Makati Loop',
      keyPoints: ['Ayala', 'Buendia', 'Paseo', 'Magallanes'],
      estimatedFare: 13.0,
      description: 'Loop route around Makati CBD',
      type: RouteType.jeepney,
    ),
    // Bus Routes
    PopularRoute(
      routeCode: 'NOVALICHES-BAYAN',
      routeName: 'Novaliches to Bayan',
      keyPoints: ['Novaliches', 'Fairview', 'Quezon City Hall', 'Bayan'],
      estimatedFare: 18.0,
      description:
          'Major bus route connecting Novaliches to Bayan via major roads',
      type: RouteType.bus,
    ),
    PopularRoute(
      routeCode: 'EDSA-BUS',
      routeName: 'EDSA Bus Route',
      keyPoints: [
        'Monumento',
        'North Avenue',
        'Quezon Ave',
        'Cubao',
        'Ortigas',
        'Makati',
        'Pasay',
      ],
      estimatedFare: 20.0,
      description: 'Express bus service along EDSA corridor',
      type: RouteType.bus,
    ),
    // FX/Van Routes
    PopularRoute(
      routeCode: 'NOVALICHES-FX',
      routeName: 'Novaliches FX/Van',
      keyPoints: [
        'Novaliches',
        'Fairview',
        'Commonwealth',
        'Batasan',
        'Philcoa',
      ],
      estimatedFare: 15.0,
      description: 'FX/van service from Novaliches to QC area',
      type: RouteType.fx,
    ),
    PopularRoute(
      routeCode: 'BAYAN-FX',
      routeName: 'Bayan FX/Van',
      keyPoints: ['Bayan', 'Quezon City Hall', 'Philcoa', 'Commonwealth'],
      estimatedFare: 14.0,
      description: 'FX/van service connecting Bayan to Commonwealth area',
      type: RouteType.fx,
    ),
  ];

  // Main routing method with budget comparison
  static Future<List<BudgetRoute>> calculateBudgetRoutes({
    required LatLng origin,
    required LatLng destination,
    bool preferDriving = false,
  }) async {
    debugPrint('=== BUDGET ROUTING SERVICE ===');
    debugPrint('From: ${origin.latitude}, ${origin.longitude}');
    debugPrint('To: ${destination.latitude}, ${destination.longitude}');

    final routes = <BudgetRoute>[];

    try {
      // 1. Get driving route (for cost comparison)
      final drivingRoute = await _calculateDrivingRoute(origin, destination);
      if (drivingRoute != null) {
        routes.add(drivingRoute);
        debugPrint(
          'Added driving route: ₱${drivingRoute.cost.toStringAsFixed(2)}',
        );
      }

      // 2. Calculate jeepney alternative
      final jeepneyRoute = await _calculateJeepneyRoute(origin, destination);
      if (jeepneyRoute != null) {
        routes.add(jeepneyRoute);
        debugPrint(
          'Added jeepney route: ₱${jeepneyRoute.cost.toStringAsFixed(2)}',
        );
      }

      // 3. Add bus route if longer distance
      final distance = _calculateDistance(origin, destination);
      if (distance > 5) {
        final busRoute = await _calculateBusRoute(origin, destination);
        if (busRoute != null) {
          routes.add(busRoute);
          debugPrint('Added bus route: ₱${busRoute.cost.toStringAsFixed(2)}');
        }
      }

      // 4. Add MRT/LRT route if both endpoints are near rail access
      final trainRoute = _calculateTrainRoute(origin, destination);
      if (trainRoute != null) {
        routes.add(trainRoute);
        debugPrint('Added train route: ₱${trainRoute.cost.toStringAsFixed(2)}');
      }

      // 5. Add FX route if applicable
      final fxRoute = await _calculateFxRoute(origin, destination);
      if (fxRoute != null) {
        routes.add(fxRoute);
        debugPrint('Added FX route: ₱${fxRoute.cost.toStringAsFixed(2)}');
      }

      // 6. Always add walking route
      final walkingRoute = _calculateWalkingRoute(origin, destination);
      routes.add(walkingRoute);
      debugPrint('Added walking route: FREE');

      // Sort by cost (cheapest first) unless driving is preferred
      if (!preferDriving) {
        routes.sort((a, b) => a.cost.compareTo(b.cost));
      }

      debugPrint('=== BUDGET ROUTING RESULTS ===');
      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final savings = route.mode == TravelMode.driving && routes.isNotEmpty
            ? route.cost - routes.first.cost
            : 0.0;
        debugPrint(
          '  ${i + 1}. ${route.mode.name} - ${route.duration.inMinutes}min - ₱${route.cost.toStringAsFixed(2)} ${savings > 0 ? "(Save ₱${savings.toStringAsFixed(2)})" : ""}',
        );
      }

      return routes;
    } catch (e) {
      debugPrint('Budget routing failed: $e');
      return _getFallbackRoutes(origin, destination);
    }
  }

  // Calculate driving route with fuel and toll costs
  static Future<BudgetRoute?> _calculateDrivingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final directions = await GoogleMapsApiService.getDirections(
        origin: origin,
        destination: destination,
        travelMode: 'driving',
      );

      if (directions != null && directions.routes.isNotEmpty) {
        final route = directions.routes.first;
        final distance = route.totalDistance; // Already in km
        final duration = route.totalDuration;

        // Calculate fuel cost
        final fuelCost =
            (distance / PhilippineFares.vehicleFuelConsumption) *
            PhilippineFares.fuelPricePerLiter;

        // Estimate toll cost (check if route uses major expressways)
        final tollCost = _estimateTollCost(route);

        // Estimate parking cost (assume 1 hour parking)
        final parkingCost = PhilippineFares.parkingRatePerHour;

        final totalCost = fuelCost + tollCost + parkingCost;

        // Check for toll warnings
        final tips = <String>[];
        if (tollCost > 0) {
          tips.add(
            '⚠️ Toll road detected! Additional ₱${tollCost.toStringAsFixed(0)} in tolls',
          );
        }
        tips.add('💰 Fuel cost: ₱${fuelCost.toStringAsFixed(0)}');
        tips.add('🅿️ Parking estimate: ₱${parkingCost.toStringAsFixed(0)}');

        return BudgetRoute(
          id: 'driving-${DateTime.now().millisecondsSinceEpoch}',
          mode: TravelMode.driving,
          start: origin,
          end: destination,
          duration: duration,
          distance: distance,
          cost: totalCost,
          instructions: _extractInstructions(route),
          polyline: _extractPolyline(route),
          summary: 'Driving - Fastest but most expensive',
          tips: tips,
          fareDetails: FareDetails(
            regular: totalCost,
            student: totalCost, // No discount for driving
            pwd: totalCost,
            senior: totalCost,
          ),
        );
      }
    } catch (e) {
      debugPrint('Driving route calculation failed: $e');
    }
    return null;
  }

  // Calculate jeepney route with realistic fares
  static Future<BudgetRoute?> _calculateJeepneyRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final distance = _calculateDistance(origin, destination);

      // Use Google Maps for realistic route path
      final directions = await GoogleMapsApiService.getDirections(
        origin: origin,
        destination: destination,
        travelMode: 'driving', // Use driving roads for jeepney path
      );

      // Calculate jeepney fare
      final fareDetails = _calculateJeepneyFare(distance);

      // Estimate duration (jeepneys are slower than cars)
      final estimatedDuration = Duration(
        minutes: (distance / 12 * 60).round(),
      ); // 12 km/h average

      final tips = <String>[];
      tips.add('🚌 Traditional jeepney fare');
      tips.add('💵 Cash payment only');
      tips.add('📢 Say "Bayad po!" when paying');

      if (distance > 10) {
        tips.add('🔄 Long route - expect multiple rides');
      }

      // Try to find a matching popular route
      final nearbyRoutes = getNearbyRoutes(destination);
      final matchingRoute = nearbyRoutes
          .where((r) => r.type == RouteType.jeepney)
          .firstOrNull;

      return BudgetRoute(
        id: 'jeepney-${DateTime.now().millisecondsSinceEpoch}',
        mode: TravelMode.jeepney,
        start: origin,
        end: destination,
        duration: estimatedDuration,
        distance: distance,
        cost: fareDetails.regular,
        instructions: directions != null
            ? _extractInstructions(directions.routes.first)
            : ['Take jeepney to destination'],
        polyline: directions != null
            ? _extractPolyline(directions.routes.first)
            : [origin, destination],
        summary: 'Jeepney - Most affordable option',
        tips: tips,
        fareDetails: fareDetails,
        routeDetails: matchingRoute != null
            ? RouteDetails(
                routeName: matchingRoute.routeName,
                routeCode: matchingRoute.routeCode,
                keyPoints: matchingRoute.keyPoints,
                description: matchingRoute.description,
                boardingInstructions:
                    'Look for jeepneys with "${matchingRoute.routeName}" signage. Board at designated stops.',
              )
            : null,
      );
    } catch (e) {
      debugPrint('Jeepney route calculation failed: $e');
      return null;
    }
  }

  // Calculate bus route
  static Future<BudgetRoute?> _calculateBusRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final distance = _calculateDistance(origin, destination);

      // Use Google Maps for route
      final directions = await GoogleMapsApiService.getDirections(
        origin: origin,
        destination: destination,
        travelMode: 'driving',
      );

      // Calculate bus fare
      final fareDetails = _calculateBusFare(distance);

      // Estimate duration (buses are moderate speed)
      final estimatedDuration = Duration(
        minutes: (distance / 18 * 60).round(),
      ); // 18 km/h average

      final tips = <String>[];
      tips.add('🚐 Air-conditioned bus');
      tips.add('💵 Cash payment only');
      tips.add('🎯 Beep card accepted on some routes');

      // Try to find a matching popular route
      final nearbyRoutes = getNearbyRoutes(destination);
      final matchingRoute = nearbyRoutes
          .where((r) => r.type == RouteType.bus)
          .firstOrNull;

      return BudgetRoute(
        id: 'bus-${DateTime.now().millisecondsSinceEpoch}',
        mode: TravelMode.bus,
        start: origin,
        end: destination,
        duration: estimatedDuration,
        distance: distance,
        cost: fareDetails.regular,
        instructions: directions != null
            ? _extractInstructions(directions.routes.first)
            : ['Take bus to destination'],
        polyline: directions != null
            ? _extractPolyline(directions.routes.first)
            : [origin, destination],
        summary: 'Bus - Comfortable mid-range option',
        tips: tips,
        fareDetails: fareDetails,
        routeDetails: matchingRoute != null
            ? RouteDetails(
                routeName: matchingRoute.routeName,
                routeCode: matchingRoute.routeCode,
                keyPoints: matchingRoute.keyPoints,
                description: matchingRoute.description,
                boardingInstructions:
                    'Board at designated bus stops. Look for buses with "${matchingRoute.routeName}" route.',
              )
            : null,
      );
    } catch (e) {
      debugPrint('Bus route calculation failed: $e');
      return null;
    }
  }

  // Calculate FX route
  static Future<BudgetRoute?> _calculateFxRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final distance = _calculateDistance(origin, destination);

      // UV Express / FX commonly covers city-to-city corridors, but avoid
      // suggesting it for provincial-scale trips where terminals vary widely.
      if (distance > 40) return null;

      // Use Google Maps for route
      final directions = await GoogleMapsApiService.getDirections(
        origin: origin,
        destination: destination,
        travelMode: 'driving',
      );

      // Calculate FX fare
      final fareDetails = _calculateFxFare(distance);

      // Estimate duration (FX are faster than jeepneys)
      final estimatedDuration = Duration(
        minutes: (distance / 20 * 60).round(),
      ); // 20 km/h average

      final tips = <String>[];
      tips.add('🚐 FX/Van service - faster than jeepney');
      tips.add('💵 Cash payment only');
      tips.add('👥 Shared ride with other passengers');
      if (distance > 15) {
        tips.add('🔄 Long route - transfer at a UV Express terminal if needed');
      }

      // Try to find a matching popular route
      final nearbyRoutes = getNearbyRoutes(destination);
      final matchingRoute = nearbyRoutes
          .where((r) => r.type == RouteType.fx)
          .firstOrNull;

      return BudgetRoute(
        id: 'fx-${DateTime.now().millisecondsSinceEpoch}',
        mode: TravelMode.fx,
        start: origin,
        end: destination,
        duration: estimatedDuration,
        distance: distance,
        cost: fareDetails.regular,
        instructions: directions != null
            ? _extractInstructions(directions.routes.first)
            : ['Take FX/van to destination'],
        polyline: directions != null
            ? _extractPolyline(directions.routes.first)
            : [origin, destination],
        summary: 'FX/Van - Fast and affordable',
        tips: tips,
        fareDetails: fareDetails,
        routeDetails: matchingRoute != null
            ? RouteDetails(
                routeName: matchingRoute.routeName,
                routeCode: matchingRoute.routeCode,
                keyPoints: matchingRoute.keyPoints,
                description: matchingRoute.description,
                boardingInstructions:
                    'Look for FX/vans with "${matchingRoute.routeName}" signage at designated pickup points.',
              )
            : null,
      );
    } catch (e) {
      debugPrint('FX route calculation failed: $e');
      return null;
    }
  }

  static BudgetRoute? _calculateTrainRoute(LatLng origin, LatLng destination) {
    try {
      final originStation = _nearestRailStation(origin);
      final destinationStation = _nearestRailStation(destination);
      if (originStation == null || destinationStation == null) return null;

      const maxAccessKm = 2.7;
      const maxEgressKm = 3.2;
      if (originStation.distanceKm > maxAccessKm ||
          destinationStation.distanceKm > maxEgressKm) {
        return null;
      }

      final segments = _buildRailSegments(originStation, destinationStation);
      if (segments.isEmpty) return null;

      final railStopCount = segments.fold<int>(
        0,
        (total, segment) => total + segment.stopCount,
      );
      if (railStopCount == 0 && segments.length == 1) return null;

      final transferMinutes = _transferMinutesForSegments(segments);
      final walkMinutes =
          ((originStation.distanceKm + destinationStation.distanceKm) /
                  4.5 *
                  60)
              .round();
      final trainMinutes = math.max(6, railStopCount * 3);
      final duration = Duration(
        minutes: walkMinutes + trainMinutes + transferMinutes,
      );
      final lineCodes = segments.map((segment) => segment.line.code).toSet();
      final fareDetails = _calculateTrainFare(segments);
      final polyline = _dedupePolylinePoints([
        origin,
        for (final segment in segments) ...[
          segment.from.location,
          segment.to.location,
        ],
        destination,
      ]);
      final keyPoints = _dedupeStrings([
        originStation.station.name,
        for (final segment in segments) ...[segment.from.name, segment.to.name],
        destinationStation.station.name,
      ]);
      final instructions = <String>[
        'Walk to ${originStation.station.name} ${originStation.line.code} station.',
        for (var i = 0; i < segments.length; i++) ...[
          'Ride ${segments[i].line.name} from ${segments[i].from.name} to ${segments[i].to.name}${segments[i].stopCount > 0 ? ' (${segments[i].stopCount} stops)' : ''}.',
          if (i < segments.length - 1)
            'Transfer from ${segments[i].line.code} to ${segments[i + 1].line.code}. Follow station signs before boarding the next train.',
        ],
        'Exit at ${destinationStation.station.name}, then walk to your destination.',
      ];
      final routeName = lineCodes.join(' + ');

      return BudgetRoute(
        id: 'train-${DateTime.now().millisecondsSinceEpoch}',
        mode: TravelMode.train,
        start: origin,
        end: destination,
        duration: duration,
        distance: _calculateDistance(origin, destination),
        cost: fareDetails.regular,
        instructions: instructions,
        polyline: polyline,
        summary: segments.length == 1
            ? 'Train - ${segments.first.line.name}'
            : 'Train - MRT/LRT transfer route',
        tips: [
          'Use a Beep card or single-journey ticket at the station.',
          'Allow extra walking time for station transfers and exits.',
          if (segments.length > 1)
            'This route has ${segments.length - 1} rail transfer${segments.length == 2 ? '' : 's'}.',
        ],
        fareDetails: fareDetails,
        routeDetails: RouteDetails(
          routeName: routeName,
          routeCode: routeName.replaceAll(' + ', '-'),
          keyPoints: keyPoints,
          description:
              'Estimated Manila rail route using nearby MRT/LRT stations.',
          boardingInstructions:
              'Enter ${originStation.station.name} station and board ${segments.first.line.code}.',
          boardingStop: originStation.station.name,
          dropOffStop: destinationStation.station.name,
          boardingLocation: originStation.station.location,
          dropOffLocation: destinationStation.station.location,
        ),
      );
    } catch (e) {
      debugPrint('Train route calculation failed: $e');
      return null;
    }
  }

  static _RailStationMatch? _nearestRailStation(LatLng point) {
    _RailStationMatch? nearest;
    for (final line in _railLines) {
      for (var i = 0; i < line.stations.length; i++) {
        final station = line.stations[i];
        final distance = _calculateDistance(point, station.location);
        if (nearest == null || distance < nearest.distanceKm) {
          nearest = _RailStationMatch(
            line: line,
            station: station,
            stationIndex: i,
            distanceKm: distance,
          );
        }
      }
    }
    return nearest;
  }

  static List<_RailSegment> _buildRailSegments(
    _RailStationMatch origin,
    _RailStationMatch destination,
  ) {
    if (origin.line.code == destination.line.code) {
      return [
        _segmentForStations(origin.line, origin.station, destination.station),
      ];
    }

    final linePath = _railLinePath(origin.line.code, destination.line.code);
    if (linePath.length < 2) return const [];

    final segments = <_RailSegment>[];
    var currentLine = origin.line;
    var currentStation = origin.station;

    for (var i = 1; i < linePath.length; i++) {
      final nextLine = linePath[i];
      final transfer = _transferBetween(currentLine.code, nextLine.code);
      if (transfer == null) return const [];
      final fromTransferStation = _stationForTransfer(transfer, currentLine);
      final toTransferStation = _stationForTransfer(transfer, nextLine);
      if (fromTransferStation == null || toTransferStation == null) {
        return const [];
      }
      final segment = _segmentForStations(
        currentLine,
        currentStation,
        fromTransferStation,
      );
      if (segment.stopCount > 0) segments.add(segment);
      currentLine = nextLine;
      currentStation = toTransferStation;
    }

    final finalSegment = _segmentForStations(
      currentLine,
      currentStation,
      destination.station,
    );
    if (finalSegment.stopCount > 0) segments.add(finalSegment);
    return segments;
  }

  static _RailSegment _segmentForStations(
    _RailLine line,
    _RailStation from,
    _RailStation to,
  ) {
    final fromIndex = _stationIndex(line, from.name);
    final toIndex = _stationIndex(line, to.name);
    return _RailSegment(
      line: line,
      from: from,
      to: to,
      stopCount: (toIndex - fromIndex).abs(),
    );
  }

  static int _stationIndex(_RailLine line, String stationName) {
    return line.stations.indexWhere((station) => station.name == stationName);
  }

  static List<_RailLine> _railLinePath(String fromCode, String toCode) {
    final queue = <List<String>>[
      [fromCode],
    ];
    final visited = <String>{fromCode};

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final current = path.last;
      if (current == toCode) {
        return path
            .map(_railLineByCode)
            .whereType<_RailLine>()
            .toList(growable: false);
      }
      for (final nextCode in _connectedRailLineCodes(current)) {
        if (visited.add(nextCode)) {
          queue.add([...path, nextCode]);
        }
      }
    }

    return const [];
  }

  static Iterable<String> _connectedRailLineCodes(String lineCode) sync* {
    for (final transfer in _railTransfers) {
      if (transfer.firstLineCode == lineCode) {
        yield transfer.secondLineCode;
      } else if (transfer.secondLineCode == lineCode) {
        yield transfer.firstLineCode;
      }
    }
  }

  static _RailLine? _railLineByCode(String code) {
    for (final line in _railLines) {
      if (line.code == code) return line;
    }
    return null;
  }

  static _RailTransfer? _transferBetween(String firstCode, String secondCode) {
    for (final transfer in _railTransfers) {
      final forward =
          transfer.firstLineCode == firstCode &&
          transfer.secondLineCode == secondCode;
      final backward =
          transfer.firstLineCode == secondCode &&
          transfer.secondLineCode == firstCode;
      if (forward || backward) return transfer;
    }
    return null;
  }

  static _RailStation? _stationForTransfer(
    _RailTransfer transfer,
    _RailLine line,
  ) {
    final stationName = transfer.firstLineCode == line.code
        ? transfer.firstStationName
        : transfer.secondStationName;
    for (final station in line.stations) {
      if (station.name == stationName) return station;
    }
    return null;
  }

  static int _transferMinutesForSegments(List<_RailSegment> segments) {
    if (segments.length <= 1) return 0;
    var minutes = 0;
    for (var i = 0; i < segments.length - 1; i++) {
      final transfer = _transferBetween(
        segments[i].line.code,
        segments[i + 1].line.code,
      );
      minutes += transfer?.walkMinutes ?? 8;
    }
    return minutes;
  }

  static FareDetails _calculateTrainFare(List<_RailSegment> segments) {
    final regularFare = segments.fold<double>(0, (total, segment) {
      final baseFare = switch (segment.line.code) {
        'LRT-1' => PhilippineFares.lrt1Base,
        'LRT-2' => PhilippineFares.lrt2Base,
        'MRT-3' => PhilippineFares.mrt3Base,
        _ => PhilippineFares.mrt3Base,
      };
      final segmentFare =
          (baseFare + segment.stopCount * PhilippineFares.trainPerStation)
              .clamp(baseFare, PhilippineFares.trainMax)
              .toDouble();
      return total + segmentFare;
    });

    return FareDetails(
      regular: regularFare,
      student: regularFare * (1 - PhilippineFares.studentDiscount),
      pwd: regularFare * (1 - PhilippineFares.pwdDiscount),
      senior: regularFare * (1 - PhilippineFares.seniorDiscount),
    );
  }

  static List<LatLng> _dedupePolylinePoints(List<LatLng> points) {
    final deduped = <LatLng>[];
    for (final point in points) {
      if (deduped.isEmpty || _calculateDistance(deduped.last, point) > 0.03) {
        deduped.add(point);
      }
    }
    return deduped;
  }

  static List<String> _dedupeStrings(List<String> values) {
    final seen = <String>{};
    final deduped = <String>[];
    for (final value in values) {
      if (seen.add(value)) deduped.add(value);
    }
    return deduped;
  }

  // Calculate walking route
  static BudgetRoute _calculateWalkingRoute(LatLng origin, LatLng destination) {
    final distance = _calculateDistance(origin, destination);
    final duration = Duration(
      minutes: (distance / 5 * 60).round(),
    ); // 5 km/h walking speed

    final tips = <String>[];
    tips.add('🚶‍♂️ Free exercise!');
    tips.add('☀️ Best for short distances');
    if (distance > 2) {
      tips.add('⚠️ Quite far to walk - consider transport');
    }

    return BudgetRoute(
      id: 'walking-${DateTime.now().millisecondsSinceEpoch}',
      mode: TravelMode.walking,
      start: origin,
      end: destination,
      duration: duration,
      distance: distance,
      cost: 0.0,
      instructions: ['Walk to destination (${distance.toStringAsFixed(1)} km)'],
      polyline: [origin, destination],
      summary: 'Walking - Free and healthy',
      tips: tips,
      fareDetails: const FareDetails(
        regular: 0.0,
        student: 0.0,
        pwd: 0.0,
        senior: 0.0,
      ),
    );
  }

  // Calculate jeepney fare with discounts
  static FareDetails _calculateJeepneyFare(double distance) {
    double regularFare;
    if (distance <= 4) {
      regularFare = PhilippineFares.traditionalJeepneyBase;
    } else {
      regularFare =
          PhilippineFares.traditionalJeepneyBase +
          (distance - 4) * PhilippineFares.traditionalJeepneyPerKm;
    }

    return FareDetails(
      regular: regularFare,
      student: regularFare * (1 - PhilippineFares.studentDiscount),
      pwd: regularFare * (1 - PhilippineFares.pwdDiscount),
      senior: regularFare * (1 - PhilippineFares.seniorDiscount),
    );
  }

  // Calculate bus fare with discounts
  static FareDetails _calculateBusFare(double distance) {
    double regularFare;
    if (distance <= 5) {
      regularFare = PhilippineFares.airconBusBase;
    } else {
      regularFare =
          PhilippineFares.airconBusBase +
          (distance - 5) * PhilippineFares.busPerKm;
    }

    return FareDetails(
      regular: regularFare,
      student: regularFare * (1 - PhilippineFares.studentDiscount),
      pwd: regularFare * (1 - PhilippineFares.pwdDiscount),
      senior: regularFare * (1 - PhilippineFares.seniorDiscount),
    );
  }

  // Calculate FX fare with discounts
  static FareDetails _calculateFxFare(double distance) {
    final regularFare = math.max(
      PhilippineFares.fxBase,
      distance * PhilippineFares.fxPerKm,
    );

    return FareDetails(
      regular: regularFare,
      student: regularFare * (1 - PhilippineFares.studentDiscount),
      pwd: regularFare * (1 - PhilippineFares.pwdDiscount),
      senior: regularFare * (1 - PhilippineFares.seniorDiscount),
    );
  }

  // Estimate toll cost based on route
  static double _estimateTollCost(dynamic route) {
    // This is a simplified estimation
    // In a real app, you'd check the route path against known toll roads
    double totalToll = 0.0;

    // Check if route might use major expressways (simplified)
    // This would ideally use the actual route polyline
    for (final entry in PhilippineFares.tollFees.entries) {
      // Simple heuristic: long routes might use expressways
      if (route.totalDistance > 10) {
        // > 10km
        totalToll += entry.value;
        break; // Assume one toll for simplicity
      }
    }

    return totalToll;
  }

  // Get popular routes near destination
  static List<PopularRoute> getNearbyRoutes(LatLng destination) {
    // For now, return all popular routes
    // In a real app, you'd filter by actual proximity
    return popularRoutes;
  }

  // Calculate savings message
  static String calculateSavingsMessage(
    BudgetRoute drivingRoute,
    BudgetRoute alternativeRoute,
  ) {
    if (drivingRoute.mode != TravelMode.driving ||
        alternativeRoute.cost >= drivingRoute.cost) {
      return '';
    }

    final savings = drivingRoute.cost - alternativeRoute.cost;
    return '💰 You can save ₱${savings.toStringAsFixed(0)} by taking ${alternativeRoute.mode.name} instead!';
  }

  // Helper methods
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLngRad =
        (point2.longitude - point1.longitude) * (math.pi / 180);

    double a =
        math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  static List<String> _extractInstructions(dynamic route) {
    final instructions = <String>[];
    try {
      for (final leg in route.legs) {
        for (final step in leg.steps) {
          final cleanInstruction = step.htmlInstructions
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&amp;', '&')
              .replaceAll('&#39;', "'");
          instructions.add(cleanInstruction);
        }
      }
    } catch (e) {
      instructions.add('Follow route to destination');
    }
    return instructions;
  }

  static List<LatLng> _extractPolyline(dynamic route) {
    final polyline = <LatLng>[];
    try {
      for (final leg in route.legs) {
        for (final step in leg.steps) {
          polyline.add(step.startLocation);
          polyline.add(step.endLocation);
        }
      }
    } catch (e) {
      // Return simple line if extraction fails
    }
    return polyline;
  }

  static List<BudgetRoute> _getFallbackRoutes(
    LatLng origin,
    LatLng destination,
  ) {
    final distance = _calculateDistance(origin, destination);

    return [
      BudgetRoute(
        id: 'fallback-walking',
        mode: TravelMode.walking,
        start: origin,
        end: destination,
        duration: Duration(minutes: (distance / 5 * 60).round()),
        distance: distance,
        cost: 0.0,
        instructions: ['Walk to destination'],
        polyline: [origin, destination],
        summary: 'Walking - Free option',
        tips: ['Basic route - no internet connection'],
        fareDetails: const FareDetails(
          regular: 0.0,
          student: 0.0,
          pwd: 0.0,
          senior: 0.0,
        ),
      ),
      BudgetRoute(
        id: 'fallback-jeepney',
        mode: TravelMode.jeepney,
        start: origin,
        end: destination,
        duration: Duration(minutes: (distance / 12 * 60).round()),
        distance: distance,
        cost: _calculateJeepneyFare(distance).regular,
        instructions: ['Take jeepney to destination'],
        polyline: [origin, destination],
        summary: 'Jeepney - Budget option',
        tips: ['Estimated route - check locally'],
        fareDetails: _calculateJeepneyFare(distance),
      ),
      if (distance > 5)
        BudgetRoute(
          id: 'fallback-bus',
          mode: TravelMode.bus,
          start: origin,
          end: destination,
          duration: Duration(minutes: (distance / 18 * 60).round()),
          distance: distance,
          cost: _calculateBusFare(distance).regular,
          instructions: ['Take a bus bound for your destination area'],
          polyline: [origin, destination],
          summary: 'Bus - Estimated public transport option',
          tips: ['Estimated route - confirm signboard before boarding'],
          fareDetails: _calculateBusFare(distance),
        ),
      if (distance <= 15)
        BudgetRoute(
          id: 'fallback-fx',
          mode: TravelMode.fx,
          start: origin,
          end: destination,
          duration: Duration(minutes: (distance / 20 * 60).round()),
          distance: distance,
          cost: _calculateFxFare(distance).regular,
          instructions: [
            'Take UV Express / FX bound for your destination area',
          ],
          polyline: [origin, destination],
          summary: 'UV Express / FX - Estimated van option',
          tips: ['Estimated route - fares vary by terminal and route'],
          fareDetails: _calculateFxFare(distance),
        ),
    ];
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
