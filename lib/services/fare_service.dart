import 'package:halaph/services/budget_routing_service.dart';

// Simple fare estimator with rail-shipper-like integration.
// This delegates to BudgetRoutingService for base fare calculation and
// applies passenger-type discounts for UX. In production, substitute
// with official fare data sources.
enum PassengerType { regular, adult, student, senior, pwd }

class FareBreakdown {
  final double baseFare;
  final double regularFare;
  final double studentFare;
  final double seniorFare;
  final double pwdFare;

  const FareBreakdown({
    required this.baseFare,
    required this.regularFare,
    required this.studentFare,
    required this.seniorFare,
    required this.pwdFare,
  });
}

class FareSegment {
  final String label;
  final TravelMode mode;
  final double distanceKm;
  final double fare;

  const FareSegment({
    required this.label,
    required this.mode,
    required this.distanceKm,
    required this.fare,
  });
}

class MultiSegmentFareEstimate {
  final List<FareSegment> segments;

  const MultiSegmentFareEstimate({required this.segments});

  double get totalFare {
    return segments.fold<double>(0, (total, segment) => total + segment.fare);
  }

  double get totalDistanceKm {
    return segments.fold<double>(
      0,
      (total, segment) => total + segment.distanceKm,
    );
  }

  List<String> get displayLines {
    return segments.map((segment) {
      final distance = segment.distanceKm < 1
          ? '${(segment.distanceKm * 1000).toStringAsFixed(0)}m'
          : '${segment.distanceKm.toStringAsFixed(1)}km';
      final fareText =
          segment.fare > 0 ? '₱${segment.fare.toStringAsFixed(0)}' : '₱0';
      return '${segment.label}: $fareText • $distance';
    }).toList();
  }
}

class FareService {
  static double estimateFare(TravelMode mode, double distanceKm,
      {PassengerType type = PassengerType.regular}) {
    if (mode == TravelMode.walking) return 0.0;

    // Base fare from budget routing provider (already distance-aware)
    final baseFare = BudgetRoutingService.calculateFare(mode, distanceKm);
    final fare = _applyDiscount(baseFare, type);

    // Ensure non-negative
    return fare < 0 ? 0 : fare;
  }

  static FareBreakdown fareBreakdown(TravelMode mode, double distanceKm) {
    final baseFare = mode == TravelMode.walking
        ? 0.0
        : BudgetRoutingService.calculateFare(mode, distanceKm);
    return FareBreakdown(
      baseFare: baseFare,
      regularFare: _applyDiscount(baseFare, PassengerType.regular),
      studentFare: _applyDiscount(baseFare, PassengerType.student),
      seniorFare: _applyDiscount(baseFare, PassengerType.senior),
      pwdFare: _applyDiscount(baseFare, PassengerType.pwd),
    );
  }

  static MultiSegmentFareEstimate estimateCommuteTotal(
    TravelMode mode,
    double distanceKm, {
    PassengerType type = PassengerType.regular,
  }) {
    final totalDistance = distanceKm <= 0 ? 0.0 : distanceKm;

    if (mode == TravelMode.walking || totalDistance == 0) {
      return MultiSegmentFareEstimate(
        segments: [
          FareSegment(
            label: 'Walk to destination',
            mode: TravelMode.walking,
            distanceKm: totalDistance,
            fare: 0,
          ),
        ],
      );
    }

    switch (mode) {
      case TravelMode.jeepney:
        return _estimateStreetPickupCommute(
          mainMode: TravelMode.jeepney,
          mainLabel: 'Jeepney ride',
          accessLabel: 'Walk to jeepney pickup',
          lastMileLabel: 'Walk from jeepney drop-off',
          totalDistance: totalDistance,
          type: type,
        );
      case TravelMode.bus:
        return _estimateTerminalBasedCommute(
          mainMode: TravelMode.bus,
          mainLabel: 'Bus ride',
          accessLabel: 'Jeep/tricycle to bus stop',
          lastMileLabel: 'Last-mile jeep/tricycle estimate',
          totalDistance: totalDistance,
          type: type,
        );
      case TravelMode.train:
        return _estimateTerminalBasedCommute(
          mainMode: TravelMode.train,
          mainLabel: 'MRT/LRT ride',
          accessLabel: 'Jeep/bus to MRT/LRT station',
          lastMileLabel: 'Last-mile jeep/bus/tricycle estimate',
          totalDistance: totalDistance,
          type: type,
        );
      case TravelMode.fx:
        return _estimateTerminalBasedCommute(
          mainMode: TravelMode.fx,
          mainLabel: 'FX/Van ride',
          accessLabel: 'Jeep/tricycle to FX/UV terminal',
          lastMileLabel: 'Last-mile jeep/tricycle estimate',
          totalDistance: totalDistance,
          type: type,
        );
      case TravelMode.walking:
        return MultiSegmentFareEstimate(
          segments: [
            FareSegment(
              label: 'Walk to destination',
              mode: TravelMode.walking,
              distanceKm: totalDistance,
              fare: 0,
            ),
          ],
        );
    }
  }

  static MultiSegmentFareEstimate _estimateStreetPickupCommute({
    required TravelMode mainMode,
    required String mainLabel,
    required String accessLabel,
    required String lastMileLabel,
    required double totalDistance,
    required PassengerType type,
  }) {
    final accessWalk = _boundedSegmentDistance(
      totalDistance * 0.06,
      minimum: 0.10,
      maximum: 0.45,
      totalDistance: totalDistance,
    );
    final lastWalk = _boundedSegmentDistance(
      totalDistance * 0.06,
      minimum: 0.10,
      maximum: 0.45,
      totalDistance: totalDistance,
    );
    final mainDistance = (totalDistance - accessWalk - lastWalk)
        .clamp(totalDistance * 0.60, totalDistance)
        .toDouble();

    return MultiSegmentFareEstimate(
      segments: [
        FareSegment(
          label: accessLabel,
          mode: TravelMode.walking,
          distanceKm: accessWalk,
          fare: 0,
        ),
        FareSegment(
          label: mainLabel,
          mode: mainMode,
          distanceKm: mainDistance,
          fare: estimateFare(mainMode, mainDistance, type: type),
        ),
        FareSegment(
          label: lastMileLabel,
          mode: TravelMode.walking,
          distanceKm: lastWalk,
          fare: 0,
        ),
      ],
    );
  }

  static MultiSegmentFareEstimate _estimateTerminalBasedCommute({
    required TravelMode mainMode,
    required String mainLabel,
    required String accessLabel,
    required String lastMileLabel,
    required double totalDistance,
    required PassengerType type,
  }) {
    double accessDistance = _boundedSegmentDistance(
      totalDistance * 0.16,
      minimum: 0.60,
      maximum: 3.00,
      totalDistance: totalDistance,
    );
    double lastMileDistance = _boundedSegmentDistance(
      totalDistance * 0.14,
      minimum: 0.50,
      maximum: 2.50,
      totalDistance: totalDistance,
    );
    double mainDistance = totalDistance - accessDistance - lastMileDistance;

    if (mainDistance < totalDistance * 0.40) {
      accessDistance = totalDistance * 0.20;
      mainDistance = totalDistance * 0.60;
      lastMileDistance = totalDistance * 0.20;
    }

    return MultiSegmentFareEstimate(
      segments: [
        FareSegment(
          label: accessLabel,
          mode: TravelMode.jeepney,
          distanceKm: accessDistance,
          fare: estimateFare(
            TravelMode.jeepney,
            accessDistance,
            type: type,
          ),
        ),
        FareSegment(
          label: mainLabel,
          mode: mainMode,
          distanceKm: mainDistance,
          fare: estimateFare(mainMode, mainDistance, type: type),
        ),
        FareSegment(
          label: lastMileLabel,
          mode: TravelMode.jeepney,
          distanceKm: lastMileDistance,
          fare: estimateFare(
            TravelMode.jeepney,
            lastMileDistance,
            type: type,
          ),
        ),
      ],
    );
  }

  static double _boundedSegmentDistance(
    double value, {
    required double minimum,
    required double maximum,
    required double totalDistance,
  }) {
    if (totalDistance <= minimum) return totalDistance * 0.30;
    final capped = value.clamp(minimum, maximum).toDouble();
    final maxAllowed = totalDistance * 0.40;
    return capped > maxAllowed ? maxAllowed : capped;
  }

  static double _applyDiscount(double baseFare, PassengerType type) {
    switch (type) {
      case PassengerType.student:
      case PassengerType.senior:
      case PassengerType.pwd:
        return baseFare * 0.8;
      case PassengerType.regular:
      case PassengerType.adult:
        return baseFare;
    }
  }
}
