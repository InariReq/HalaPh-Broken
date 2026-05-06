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
