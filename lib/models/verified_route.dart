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

class HistoricalRouteMatch {
  final VerifiedRouteReference route;
  final String signboard;
  final String via;
  final String boardStopName;
  final String alightStopName;
  final double walkToBoardMeters;
  final double rideDistanceMeters;
  final double walkFromAlightMeters;
  final int stopCount;

  const HistoricalRouteMatch({
    required this.route,
    required this.signboard,
    required this.via,
    required this.boardStopName,
    required this.alightStopName,
    required this.walkToBoardMeters,
    required this.rideDistanceMeters,
    required this.walkFromAlightMeters,
    required this.stopCount,
  });

  double get rideDistanceKm => rideDistanceMeters / 1000.0;

  String get sourceWarning =>
      'Historical GTFS reference only. Confirm route status, signboard, and drop-off before riding.';

  String get viaLabel =>
      via.trim().isEmpty ? 'No via point listed' : via.trim();
}
