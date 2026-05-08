import 'package:halaph/services/budget_routing_service.dart';

enum VerifiedRouteSourceType {
  historicalGtfs,
  liveTransitStep,
  fallbackGuidance,
}

class VerifiedRouteReference {
  final String routeName;
  final String routeDescription;
  final TravelMode mode;
  final String sourceLabel;
  final VerifiedRouteSourceType sourceType;
  final String sourceDetail;
  final DateTime? lastVerifiedAt;

  const VerifiedRouteReference({
    required this.routeName,
    required this.routeDescription,
    required this.mode,
    required this.sourceLabel,
    required this.sourceType,
    required this.sourceDetail,
    this.lastVerifiedAt,
  });

  bool get isHistorical => sourceType == VerifiedRouteSourceType.historicalGtfs;

  String get displayName {
    if (routeName.trim().isNotEmpty) return routeName.trim();
    return routeDescription.trim();
  }
}

class HistoricalRouteLeg {
  final VerifiedRouteReference route;
  final TravelMode mode;
  final String signboard;
  final String via;
  final String boardStopName;
  final double boardStopLat;
  final double boardStopLon;
  final String alightStopName;
  final double alightStopLat;
  final double alightStopLon;
  final double walkToBoardMeters;
  final double rideDistanceMeters;
  final int stopCount;

  const HistoricalRouteLeg({
    required this.route,
    required this.mode,
    required this.signboard,
    required this.via,
    required this.boardStopName,
    required this.boardStopLat,
    required this.boardStopLon,
    required this.alightStopName,
    required this.alightStopLat,
    required this.alightStopLon,
    required this.walkToBoardMeters,
    required this.rideDistanceMeters,
    required this.stopCount,
  });

  double get rideDistanceKm => rideDistanceMeters / 1000.0;

  String get viaLabel =>
      via.trim().isEmpty ? 'No via point listed' : via.trim();
}

class HistoricalRouteMatch {
  final VerifiedRouteReference route;
  final String signboard;
  final String via;
  final String boardStopName;
  final double boardStopLat;
  final double boardStopLon;
  final String alightStopName;
  final double alightStopLat;
  final double alightStopLon;
  final double walkToBoardMeters;
  final double rideDistanceMeters;
  final double walkFromAlightMeters;
  final int stopCount;
  final List<HistoricalRouteLeg> legs;

  const HistoricalRouteMatch({
    required this.route,
    required this.signboard,
    required this.via,
    required this.boardStopName,
    required this.boardStopLat,
    required this.boardStopLon,
    required this.alightStopName,
    required this.alightStopLat,
    required this.alightStopLon,
    required this.walkToBoardMeters,
    required this.rideDistanceMeters,
    required this.walkFromAlightMeters,
    required this.stopCount,
    this.legs = const [],
  });

  bool get hasTransfer => legs.length > 1;

  int get transferCount => legs.length <= 1 ? 0 : legs.length - 1;

  double get totalRideDistanceMeters {
    if (legs.isEmpty) return rideDistanceMeters;
    return legs.fold<double>(
      0,
      (total, leg) => total + leg.rideDistanceMeters,
    );
  }

  double get totalWalkMeters {
    if (legs.isEmpty) return walkToBoardMeters + walkFromAlightMeters;
    return walkToBoardMeters + walkFromAlightMeters;
  }

  int get totalStopCount {
    if (legs.isEmpty) return stopCount;
    return legs.fold<int>(0, (total, leg) => total + leg.stopCount);
  }

  double get rideDistanceKm => totalRideDistanceMeters / 1000.0;

  String get sourceWarning =>
      'Historical GTFS reference only. Confirm route status, signboard, and drop-off before riding.';

  String get viaLabel =>
      via.trim().isEmpty ? 'No via point listed' : via.trim();
}
