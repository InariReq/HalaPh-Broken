import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/destination_service.dart';

// 2026 Philippine Transport Costs
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

  // Walking speed: ~5 km/h
  static const double walkingSpeedKmh = 5.0;
}

enum TravelMode { jeepney, bus, train, fx, walking }

class BudgetRoutingService {
  // Calculate distance between two points
  static double calculateDistance(LatLng start, LatLng end) {
    return DestinationService.calculateDistance(start, end);
  }

  // Get current location
  static Future<LatLng?> getCurrentLocation() async {
    try {
      final location = await DestinationService.getCurrentLocation();
      if (DestinationService.isInvalidLocation(location)) return null;
      return location;
    } catch (_) {
      return null;
    }
  }

  // Check if location is invalid
  static bool isInvalidLocation(LatLng location) {
    return DestinationService.isInvalidLocation(location);
  }

  // Geocode a location name to coordinates
  static Future<LatLng?> geocodeLocation(String locationName) async {
    try {
      final destinations = await DestinationService.searchRealPlaces(
        query: locationName,
        location: null,
      );
      if (destinations.isEmpty) return null;
      return destinations.first.coordinates;
    } catch (_) {
      return null;
    }
  }

  // Calculate Jeepney fare
  static double calculateJeepneyFare(double distanceKm) {
    if (distanceKm <= 0) return 0;
    if (distanceKm <= 4) return PhilippineFares.traditionalJeepneyBase;
    final extraKm = (distanceKm - 4).ceil();
    return PhilippineFares.traditionalJeepneyBase +
        (extraKm * PhilippineFares.traditionalJeepneyPerKm);
  }

  // Calculate Bus fare
  static double calculateBusFare(double distanceKm) {
    if (distanceKm <= 0) return 0;
    if (distanceKm <= 5) return PhilippineFares.ordinaryBusBase;
    final extraKm = (distanceKm - 5).ceil();
    return PhilippineFares.ordinaryBusBase +
        (extraKm * PhilippineFares.busPerKm);
  }

  // Calculate Train fare (simplified - based on distance)
  static double calculateTrainFare(double distanceKm) {
    if (distanceKm <= 0) return 0;
    final stations = (distanceKm / 2).ceil(); // Assume ~2km per station
    final fare = PhilippineFares.lrt1Base +
        ((stations - 1) * PhilippineFares.trainPerStation);
    return fare.clamp(PhilippineFares.lrt1Base, PhilippineFares.trainMax);
  }

  // Calculate FX/Van fare
  static double calculateFXFare(double distanceKm) {
    if (distanceKm <= 0) return 0;
    if (distanceKm <= 4) return PhilippineFares.fxBase;
    final extraKm = (distanceKm - 4).ceil();
    return PhilippineFares.fxBase + (extraKm * PhilippineFares.fxPerKm);
  }

  // Calculate fare for a specific mode
  static double calculateFare(TravelMode mode, double distanceKm) {
    switch (mode) {
      case TravelMode.jeepney:
        return calculateJeepneyFare(distanceKm);
      case TravelMode.bus:
        return calculateBusFare(distanceKm);
      case TravelMode.train:
        return calculateTrainFare(distanceKm);
      case TravelMode.fx:
        return calculateFXFare(distanceKm);
      case TravelMode.walking:
        return 0;
    }
  }

  // Estimate duration for a mode
  static Duration estimateDuration(double distanceKm, TravelMode mode) {
    final speedKmh = _speedForMode(mode);
    final hours = distanceKm / speedKmh;
    return Duration(minutes: (hours * 60).round());
  }

  static double _speedForMode(TravelMode mode) {
    switch (mode) {
      case TravelMode.jeepney:
        return 30.0; // Average city speed
      case TravelMode.bus:
        return 35.0;
      case TravelMode.train:
        return 40.0; // Including stops
      case TravelMode.fx:
        return 45.0;
      case TravelMode.walking:
        return PhilippineFares.walkingSpeedKmh;
    }
  }
}
