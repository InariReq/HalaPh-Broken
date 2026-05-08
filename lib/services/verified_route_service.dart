import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/verified_route.dart';
import 'package:halaph/services/budget_routing_service.dart';

class VerifiedRouteService {
  static const String _routesAssetPath =
      'lib/Assets/gtfs-master/gtfs-master/routes.txt';
  static const String _stopsAssetPath =
      'lib/Assets/gtfs-master/gtfs-master/stops.txt';
  static const String _tripsAssetPath =
      'lib/Assets/gtfs-master/gtfs-master/trips.txt';
  static const String _stopTimesAssetPath =
      'lib/Assets/gtfs-master/gtfs-master/stop_times.txt';

  static List<VerifiedRouteReference>? _cachedRoutes;
  static _GtfsIndex? _cachedIndex;

  static Future<List<VerifiedRouteReference>> loadHistoricalGtfsRoutes() async {
    if (_cachedRoutes != null) return _cachedRoutes!;

    try {
      final index = await _loadGtfsIndex();
      _cachedRoutes = index.routes.values
          .map(
            (route) => VerifiedRouteReference(
              routeName: route.displayName,
              routeDescription: route.description,
              mode: route.mode,
              sourceLabel: 'Historical GTFS reference, confirm before riding',
              sourceType: VerifiedRouteSourceType.historicalGtfs,
              sourceDetail:
                  'Sakay.ph/LTFRB GTFS route entry. Agency: ${route.agencyId}. Route ID: ${route.routeId}. Calendar data may be historical. Use only as a route clue, not current operating proof.',
              lastVerifiedAt: DateTime(2020, 6, 30),
            ),
          )
          .toList(growable: false);
      return _cachedRoutes!;
    } catch (_) {
      _cachedRoutes = const [];
      return _cachedRoutes!;
    }
  }

  static Future<VerifiedRouteReference?> findHistoricalRouteReference({
    required TravelMode mode,
    required String destinationName,
  }) async {
    final routes = await loadHistoricalGtfsRoutes();
    if (routes.isEmpty) return null;

    final destination = _normalize(destinationName);
    if (destination.isEmpty) return null;

    final destinationTokens = _tokens(destination)
        .where((token) => token.length >= 4)
        .where((token) => !_stopWords.contains(token))
        .toSet();

    if (destinationTokens.isEmpty) return null;

    VerifiedRouteReference? best;
    int bestScore = 0;

    for (final route in routes) {
      if (!_modeMatches(mode, route.mode)) continue;

      final routeText = _normalize(
        '${route.routeName} ${route.routeDescription}',
      );
      if (routeText.isEmpty) continue;

      int score = 0;

      if (routeText.contains(destination)) {
        score += 8;
      }

      for (final token in destinationTokens) {
        if (routeText.contains(token)) {
          score += token.length >= 6 ? 3 : 2;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = route;
      }
    }

    if (bestScore < 3) return null;
    return best;
  }

  static Future<List<HistoricalRouteMatch>> findHistoricalRouteMatches({
    required TravelMode mode,
    required LatLng origin,
    required LatLng destination,
    int limit = 6,
    double maxWalkMeters = 900,
  }) async {
    final index = await _loadGtfsIndex();

    final candidateStops = mode == TravelMode.train
        ? index.stops.values.where(_isRailStop)
        : index.stops.values;

    final originStops = _nearestStops(
      candidateStops,
      origin,
      maxWalkMeters,
      limit: 30,
    );
    final destinationStops = _nearestStops(
      candidateStops,
      destination,
      maxWalkMeters,
      limit: 30,
    );

    if (originStops.isEmpty || destinationStops.isEmpty) return const [];

    final originStopIds = originStops.map((item) => item.stop.stopId).toSet();
    final destinationStopIds =
        destinationStops.map((item) => item.stop.stopId).toSet();

    final originDistanceByStop = {
      for (final item in originStops) item.stop.stopId: item.distanceMeters,
    };
    final destinationDistanceByStop = {
      for (final item in destinationStops)
        item.stop.stopId: item.distanceMeters,
    };

    final matchesByRoute = <String, HistoricalRouteMatch>{};

    for (final trip in index.trips.values) {
      final route = index.routes[trip.routeId];
      if (route == null || !_modeMatches(mode, route.mode)) continue;

      final stopTimes = index.stopTimesByTripId[trip.tripId] ?? const [];
      if (stopTimes.length < 2) continue;

      _GtfsStopTime? boardTime;
      _GtfsStopTime? alightTime;

      for (final stopTime in stopTimes) {
        if (boardTime == null && originStopIds.contains(stopTime.stopId)) {
          boardTime = stopTime;
          continue;
        }

        if (boardTime != null &&
            stopTime.sequence > boardTime.sequence &&
            destinationStopIds.contains(stopTime.stopId)) {
          alightTime = stopTime;
          break;
        }
      }

      if (boardTime == null || alightTime == null) continue;

      final boardStop = index.stops[boardTime.stopId];
      final alightStop = index.stops[alightTime.stopId];
      if (boardStop == null || alightStop == null) continue;

      final walkToBoard = originDistanceByStop[boardStop.stopId] ?? 0;
      final walkFromAlight = destinationDistanceByStop[alightStop.stopId] ?? 0;
      final stopCount = (alightTime.sequence - boardTime.sequence).abs();

      final reference = VerifiedRouteReference(
        routeName: route.displayName,
        routeDescription: route.description,
        mode: route.mode,
        sourceLabel: 'Historical GTFS reference, confirm before riding',
        sourceType: VerifiedRouteSourceType.historicalGtfs,
        sourceDetail:
            'Sakay.ph/LTFRB GTFS match. Agency: ${route.agencyId}. Route ID: ${route.routeId}. Use as a route clue only, not current operating proof.',
        lastVerifiedAt: DateTime(2020, 6, 30),
      );

      final rideDistance = _distanceMeters(
        boardStop.latitude,
        boardStop.longitude,
        alightStop.latitude,
        alightStop.longitude,
      );

      final leg = HistoricalRouteLeg(
        route: reference,
        mode: route.mode,
        signboard: route.displayName,
        via: _extractVia(route.displayName, route.description),
        boardStopName: boardStop.name,
        boardStopLat: boardStop.latitude,
        boardStopLon: boardStop.longitude,
        alightStopName: alightStop.name,
        alightStopLat: alightStop.latitude,
        alightStopLon: alightStop.longitude,
        walkToBoardMeters: walkToBoard,
        rideDistanceMeters: rideDistance,
        stopCount: stopCount,
      );

      final match = HistoricalRouteMatch(
        route: reference,
        signboard: leg.signboard,
        via: leg.via,
        boardStopName: leg.boardStopName,
        boardStopLat: leg.boardStopLat,
        boardStopLon: leg.boardStopLon,
        alightStopName: leg.alightStopName,
        alightStopLat: leg.alightStopLat,
        alightStopLon: leg.alightStopLon,
        walkToBoardMeters: walkToBoard,
        rideDistanceMeters: rideDistance,
        walkFromAlightMeters: walkFromAlight,
        stopCount: stopCount,
        legs: [leg],
      );

      final previous = matchesByRoute[route.routeId];
      if (previous == null ||
          (match.walkToBoardMeters + match.walkFromAlightMeters) <
              (previous.walkToBoardMeters + previous.walkFromAlightMeters)) {
        matchesByRoute[route.routeId] = match;
      }
    }

    final matches = matchesByRoute.values.toList()
      ..sort(
        (a, b) {
          final aWalk = a.walkToBoardMeters + a.walkFromAlightMeters;
          final bWalk = b.walkToBoardMeters + b.walkFromAlightMeters;
          final byWalk = aWalk.compareTo(bWalk);
          if (byWalk != 0) return byWalk;
          return a.stopCount.compareTo(b.stopCount);
        },
      );

    return matches.take(limit).toList(growable: false);
  }

  static Future<_GtfsIndex> _loadGtfsIndex() async {
    if (_cachedIndex != null) return _cachedIndex!;

    final routesRows = _parseCsv(await rootBundle.loadString(_routesAssetPath));
    final stopsRows = _parseCsv(await rootBundle.loadString(_stopsAssetPath));
    final tripsRows = _parseCsv(await rootBundle.loadString(_tripsAssetPath));
    final stopTimeRows =
        _parseCsv(await rootBundle.loadString(_stopTimesAssetPath));

    final routes = <String, _GtfsRoute>{};
    for (final row in _rowsWithHeaders(routesRows)) {
      final mode = _modeForGtfsRouteType(row['route_type'] ?? '');
      if (mode == null) continue;
      final routeId = (row['route_id'] ?? '').trim();
      if (routeId.isEmpty) continue;
      routes[routeId] = _GtfsRoute(
        routeId: routeId,
        agencyId: (row['agency_id'] ?? '').trim(),
        shortName: (row['route_short_name'] ?? '').trim(),
        longName: (row['route_long_name'] ?? '').trim(),
        description: (row['route_desc'] ?? '').trim(),
        mode: mode,
      );
    }

    final stops = <String, _GtfsStop>{};
    for (final row in _rowsWithHeaders(stopsRows)) {
      final stopId = (row['stop_id'] ?? '').trim();
      final name = (row['stop_name'] ?? '').trim();
      final lat = double.tryParse((row['stop_lat'] ?? '').trim());
      final lon = double.tryParse((row['stop_lon'] ?? '').trim());
      if (stopId.isEmpty || name.isEmpty || lat == null || lon == null) {
        continue;
      }
      stops[stopId] = _GtfsStop(
        stopId: stopId,
        name: name,
        latitude: lat,
        longitude: lon,
      );
    }

    final trips = <String, _GtfsTrip>{};
    for (final row in _rowsWithHeaders(tripsRows)) {
      final tripId = (row['trip_id'] ?? '').trim();
      final routeId = (row['route_id'] ?? '').trim();
      if (tripId.isEmpty || routeId.isEmpty || !routes.containsKey(routeId)) {
        continue;
      }
      trips[tripId] = _GtfsTrip(
        tripId: tripId,
        routeId: routeId,
        headsign: (row['trip_headsign'] ?? '').trim(),
        shapeId: (row['shape_id'] ?? '').trim(),
      );
    }

    final stopTimesByTripId = <String, List<_GtfsStopTime>>{};
    for (final row in _rowsWithHeaders(stopTimeRows)) {
      final tripId = (row['trip_id'] ?? '').trim();
      final stopId = (row['stop_id'] ?? '').trim().replaceAll('"', '');
      final sequence = int.tryParse((row['stop_sequence'] ?? '').trim());
      if (tripId.isEmpty ||
          stopId.isEmpty ||
          sequence == null ||
          !trips.containsKey(tripId) ||
          !stops.containsKey(stopId)) {
        continue;
      }
      stopTimesByTripId
          .putIfAbsent(tripId, () => <_GtfsStopTime>[])
          .add(_GtfsStopTime(
            tripId: tripId,
            stopId: stopId,
            sequence: sequence,
          ));
    }

    for (final times in stopTimesByTripId.values) {
      times.sort((a, b) => a.sequence.compareTo(b.sequence));
    }

    _cachedIndex = _GtfsIndex(
      routes: routes,
      stops: stops,
      trips: trips,
      stopTimesByTripId: stopTimesByTripId,
    );
    return _cachedIndex!;
  }

  static Iterable<Map<String, String>> _rowsWithHeaders(
      List<List<String>> rows) sync* {
    if (rows.isEmpty) return;

    final headers = rows.first.map((header) => header.trim()).toList();
    for (final row in rows.skip(1)) {
      final map = <String, String>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i].trim();
      }
      yield map;
    }
  }

  static List<_NearestStop> _nearestStops(
    Iterable<_GtfsStop> stops,
    LatLng point,
    double maxMeters, {
    required int limit,
  }) {
    final nearest = <_NearestStop>[];

    for (final stop in stops) {
      final distance = _distanceMeters(
        point.latitude,
        point.longitude,
        stop.latitude,
        stop.longitude,
      );
      if (distance <= maxMeters) {
        nearest.add(_NearestStop(stop: stop, distanceMeters: distance));
      }
    }

    nearest.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return nearest.take(limit).toList(growable: false);
  }

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  static String _extractVia(String routeName, String routeDescription) {
    final source = '$routeName $routeDescription';
    final match =
        RegExp(r'\bvia\s+(.+)$', caseSensitive: false).firstMatch(source);
    if (match == null) return '';

    return (match.group(1) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static TravelMode? _modeForGtfsRouteType(String routeType) {
    switch (routeType.trim()) {
      case '2':
        return TravelMode.train;
      case '3':
        return TravelMode.bus;
      default:
        return null;
    }
  }

  static bool _modeMatches(TravelMode requestedMode, TravelMode routeMode) {
    if (requestedMode == TravelMode.train) {
      return routeMode == TravelMode.train;
    }

    if (requestedMode == routeMode) return true;

    if (routeMode == TravelMode.bus &&
        (requestedMode == TravelMode.jeepney ||
            requestedMode == TravelMode.bus ||
            requestedMode == TravelMode.fx)) {
      return true;
    }

    return false;
  }

  static bool _isRailStop(_GtfsStop stop) {
    final name = stop.name.toLowerCase();
    return name.contains('lrt') ||
        name.contains('mrt') ||
        name.contains('station');
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Set<String> _tokens(String value) {
    return _normalize(value)
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();
  }

  static const Set<String> _stopWords = {
    'city',
    'mall',
    'station',
    'terminal',
    'market',
    'center',
    'centre',
    'north',
    'south',
    'east',
    'west',
    'road',
    'avenue',
    'street',
    'branch',
    'building',
    'plaza',
  };

  static List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    var currentValue = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];

      if (char == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          currentValue.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (char == ',' && !inQuotes) {
        currentRow.add(currentValue.toString());
        currentValue = StringBuffer();
        continue;
      }

      if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        currentRow.add(currentValue.toString());
        currentValue = StringBuffer();

        if (currentRow.any((cell) => cell.trim().isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = <String>[];
        continue;
      }

      currentValue.write(char);
    }

    if (currentValue.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentValue.toString());
      if (currentRow.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }
}

class _GtfsIndex {
  final Map<String, _GtfsRoute> routes;
  final Map<String, _GtfsStop> stops;
  final Map<String, _GtfsTrip> trips;
  final Map<String, List<_GtfsStopTime>> stopTimesByTripId;

  const _GtfsIndex({
    required this.routes,
    required this.stops,
    required this.trips,
    required this.stopTimesByTripId,
  });
}

class _GtfsRoute {
  final String routeId;
  final String agencyId;
  final String shortName;
  final String longName;
  final String description;
  final TravelMode mode;

  const _GtfsRoute({
    required this.routeId,
    required this.agencyId,
    required this.shortName,
    required this.longName,
    required this.description,
    required this.mode,
  });

  String get displayName {
    if (shortName.trim().isNotEmpty) return shortName.trim();
    if (longName.trim().isNotEmpty) return longName.trim();
    return description.trim();
  }
}

class _GtfsStop {
  final String stopId;
  final String name;
  final double latitude;
  final double longitude;

  const _GtfsStop({
    required this.stopId,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class _GtfsTrip {
  final String tripId;
  final String routeId;
  final String headsign;
  final String shapeId;

  const _GtfsTrip({
    required this.tripId,
    required this.routeId,
    required this.headsign,
    required this.shapeId,
  });
}

class _GtfsStopTime {
  final String tripId;
  final String stopId;
  final int sequence;

  const _GtfsStopTime({
    required this.tripId,
    required this.stopId,
    required this.sequence,
  });
}

class _NearestStop {
  final _GtfsStop stop;
  final double distanceMeters;

  const _NearestStop({
    required this.stop,
    required this.distanceMeters,
  });
}
