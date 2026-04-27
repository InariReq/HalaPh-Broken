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

  const RouteDetails({
    required this.routeName,
    required this.routeCode,
    required this.keyPoints,
    required this.description,
    required this.boardingInstructions,
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

class BudgetRoutingService {
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

      // 4. Add FX route if applicable
      final fxRoute = await _calculateFxRoute(origin, destination);
      if (fxRoute != null) {
        routes.add(fxRoute);
        debugPrint('Added FX route: ₱${fxRoute.cost.toStringAsFixed(2)}');
      }

      // 5. Always add walking route
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
