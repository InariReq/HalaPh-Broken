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
  static const double _maxTransferWalkMeters = 450;
  static const int _directStopCandidateLimit = 30;
  static const int _transferStopCandidateLimit = 20;
  static const int _segmentCandidateLimit = 80;
  static const int _rawSegmentCandidateLimit = _segmentCandidateLimit * 4;

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
      limit: _directStopCandidateLimit,
    );
    final destinationStops = _nearestStops(
      candidateStops,
      destination,
      maxWalkMeters,
      limit: _directStopCandidateLimit,
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

    final directMatchesByRoute = <String, HistoricalRouteMatch>{};

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
      final leg = _buildHistoricalRouteLeg(
        route: route,
        boardStop: boardStop,
        alightStop: alightStop,
        boardSequence: boardTime.sequence,
        alightSequence: alightTime.sequence,
        walkToBoardMeters: walkToBoard,
      );
      final match = _buildHistoricalRouteMatch(
        legs: [leg],
        walkFromFinalAlightMeters: walkFromAlight,
      );

      final previous = directMatchesByRoute[route.routeId];
      if (previous == null ||
          _matchSortScore(match) < _matchSortScore(previous)) {
        directMatchesByRoute[route.routeId] = match;
      }
    }

    final transferMatches = _findOneTransferMatches(
      index: index,
      mode: mode,
      candidateStops: candidateStops,
      origin: origin,
      destination: destination,
      maxWalkMeters: maxWalkMeters,
    );

    final matches = [
      ...directMatchesByRoute.values,
      ...transferMatches,
    ]..sort(_compareHistoricalMatches);

    return matches.take(limit).toList(growable: false);
  }

  static List<HistoricalRouteMatch> _findOneTransferMatches({
    required _GtfsIndex index,
    required TravelMode mode,
    required Iterable<_GtfsStop> candidateStops,
    required LatLng origin,
    required LatLng destination,
    required double maxWalkMeters,
  }) {
    final originStops = _nearestStops(
      candidateStops,
      origin,
      maxWalkMeters,
      limit: _transferStopCandidateLimit,
    );
    final destinationStops = _nearestStops(
      candidateStops,
      destination,
      maxWalkMeters,
      limit: _transferStopCandidateLimit,
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

    final firstLegs = <_GtfsSegmentCandidate>[];
    final secondLegs = <_GtfsSegmentCandidate>[];

    for (final trip in index.trips.values) {
      final route = index.routes[trip.routeId];
      if (route == null || !_modeMatches(mode, route.mode)) continue;

      final stopTimes = index.stopTimesByTripId[trip.tripId] ?? const [];
      if (stopTimes.length < 2) continue;

      _GtfsStopTime? firstBoardTime;
      for (final stopTime in stopTimes) {
        if (firstBoardTime == null && originStopIds.contains(stopTime.stopId)) {
          firstBoardTime = stopTime;
          continue;
        }

        if (firstBoardTime != null &&
            stopTime.sequence > firstBoardTime.sequence) {
          final boardStop = index.stops[firstBoardTime.stopId];
          final alightStop = index.stops[stopTime.stopId];
          if (boardStop == null || alightStop == null) continue;
          if (mode == TravelMode.train && !_isRailStop(alightStop)) continue;
          _addCappedSegmentCandidate(
            firstLegs,
            _GtfsSegmentCandidate(
              route: route,
              boardStop: boardStop,
              alightStop: alightStop,
              boardSequence: firstBoardTime.sequence,
              alightSequence: stopTime.sequence,
              walkToBoardMeters:
                  originDistanceByStop[firstBoardTime.stopId] ?? 0,
            ),
          );
        }
      }

      for (final boardTime in stopTimes) {
        if (!destinationStopIds.contains(boardTime.stopId)) {
          _GtfsStopTime? alightTime;
          for (final stopTime in stopTimes) {
            if (stopTime.sequence > boardTime.sequence &&
                destinationStopIds.contains(stopTime.stopId)) {
              alightTime = stopTime;
              break;
            }
          }
          if (alightTime == null) continue;

          final boardStop = index.stops[boardTime.stopId];
          final alightStop = index.stops[alightTime.stopId];
          if (boardStop == null || alightStop == null) continue;
          if (mode == TravelMode.train && !_isRailStop(boardStop)) continue;
          _addCappedSegmentCandidate(
            secondLegs,
            _GtfsSegmentCandidate(
              route: route,
              boardStop: boardStop,
              alightStop: alightStop,
              boardSequence: boardTime.sequence,
              alightSequence: alightTime.sequence,
              walkToBoardMeters: 0,
              walkFromAlightMeters:
                  destinationDistanceByStop[alightTime.stopId] ?? 0,
            ),
          );
        }
      }
    }

    firstLegs.sort((a, b) => a.score.compareTo(b.score));
    secondLegs.sort((a, b) => a.score.compareTo(b.score));

    final cappedFirstLegs = firstLegs.take(_segmentCandidateLimit);
    final cappedSecondLegs = secondLegs.take(_segmentCandidateLimit).toList();
    final matchesByTransfer = <String, HistoricalRouteMatch>{};

    for (final first in cappedFirstLegs) {
      for (final second in cappedSecondLegs) {
        if (first.route.routeId == second.route.routeId) continue;

        final transferWalk = _distanceMeters(
          first.alightStop.latitude,
          first.alightStop.longitude,
          second.boardStop.latitude,
          second.boardStop.longitude,
        );
        if (transferWalk > _maxTransferWalkMeters) continue;

        final firstLeg = _buildHistoricalRouteLeg(
          route: first.route,
          boardStop: first.boardStop,
          alightStop: first.alightStop,
          boardSequence: first.boardSequence,
          alightSequence: first.alightSequence,
          walkToBoardMeters: first.walkToBoardMeters,
        );
        final secondLeg = _buildHistoricalRouteLeg(
          route: second.route,
          boardStop: second.boardStop,
          alightStop: second.alightStop,
          boardSequence: second.boardSequence,
          alightSequence: second.alightSequence,
          walkToBoardMeters: transferWalk,
        );
        final match = _buildHistoricalRouteMatch(
          legs: [firstLeg, secondLeg],
          walkFromFinalAlightMeters: second.walkFromAlightMeters,
        );
        final key = [
          first.route.routeId,
          first.boardStop.stopId,
          first.alightStop.stopId,
          second.route.routeId,
          second.boardStop.stopId,
          second.alightStop.stopId,
        ].join('|');
        final previous = matchesByTransfer[key];
        if (previous == null ||
            _matchSortScore(match) < _matchSortScore(previous)) {
          matchesByTransfer[key] = match;
        }
      }
    }

    final matches = matchesByTransfer.values.toList()
      ..sort(_compareHistoricalMatches);
    return matches.take(_segmentCandidateLimit).toList(growable: false);
  }

  static void _addCappedSegmentCandidate(
    List<_GtfsSegmentCandidate> candidates,
    _GtfsSegmentCandidate candidate,
  ) {
    candidates.add(candidate);
    if (candidates.length <= _rawSegmentCandidateLimit) return;

    candidates.sort((a, b) => a.score.compareTo(b.score));
    candidates.removeRange(_rawSegmentCandidateLimit, candidates.length);
  }

  static HistoricalRouteLeg _buildHistoricalRouteLeg({
    required _GtfsRoute route,
    required _GtfsStop boardStop,
    required _GtfsStop alightStop,
    required int boardSequence,
    required int alightSequence,
    required double walkToBoardMeters,
  }) {
    final reference = _buildHistoricalRouteReference(route);
    final rideDistance = _distanceMeters(
      boardStop.latitude,
      boardStop.longitude,
      alightStop.latitude,
      alightStop.longitude,
    );

    return HistoricalRouteLeg(
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
      walkToBoardMeters: walkToBoardMeters,
      rideDistanceMeters: rideDistance,
      stopCount: (alightSequence - boardSequence).abs(),
    );
  }

  static HistoricalRouteMatch _buildHistoricalRouteMatch({
    required List<HistoricalRouteLeg> legs,
    required double walkFromFinalAlightMeters,
  }) {
    final firstLeg = legs.first;
    final lastLeg = legs.last;
    final totalRideDistance = legs.fold<double>(
      0,
      (total, leg) => total + leg.rideDistanceMeters,
    );
    final totalStopCount = legs.fold<int>(
      0,
      (total, leg) => total + leg.stopCount,
    );

    return HistoricalRouteMatch(
      route: firstLeg.route,
      signboard: firstLeg.signboard,
      via: firstLeg.via,
      boardStopName: firstLeg.boardStopName,
      boardStopLat: firstLeg.boardStopLat,
      boardStopLon: firstLeg.boardStopLon,
      alightStopName: lastLeg.alightStopName,
      alightStopLat: lastLeg.alightStopLat,
      alightStopLon: lastLeg.alightStopLon,
      walkToBoardMeters: firstLeg.walkToBoardMeters,
      rideDistanceMeters: totalRideDistance,
      walkFromAlightMeters: walkFromFinalAlightMeters,
      stopCount: totalStopCount,
      legs: legs,
    );
  }

  static VerifiedRouteReference _buildHistoricalRouteReference(
    _GtfsRoute route,
  ) {
    return VerifiedRouteReference(
      routeName: route.displayName,
      routeDescription: route.description,
      mode: route.mode,
      sourceLabel: 'Historical GTFS reference, confirm before riding',
      sourceType: VerifiedRouteSourceType.historicalGtfs,
      sourceDetail:
          'Sakay.ph/LTFRB GTFS match. Agency: ${route.agencyId}. Route ID: ${route.routeId}. Use as a route clue only, not current operating proof.',
      lastVerifiedAt: DateTime(2020, 6, 30),
    );
  }

  static int _compareHistoricalMatches(
    HistoricalRouteMatch a,
    HistoricalRouteMatch b,
  ) {
    final byScore = _matchSortScore(a).compareTo(_matchSortScore(b));
    if (byScore != 0) return byScore;
    return a.transferCount.compareTo(b.transferCount);
  }

  static double _matchSortScore(HistoricalRouteMatch match) {
    final legWalkMeters = match.legs.fold<double>(
      0,
      (total, leg) => total + leg.walkToBoardMeters,
    );
    final totalWalkMeters = match.legs.isEmpty
        ? match.walkToBoardMeters + match.walkFromAlightMeters
        : legWalkMeters + match.walkFromAlightMeters;

    return (match.transferCount * 800) +
        (totalWalkMeters * 1.4) +
        (match.totalStopCount * 45) +
        (match.totalRideDistanceMeters * 0.08);
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
    final normalized = _normalize(stop.name);

    final rejectedRoadTerms = {
      'hall',
      'terminal',
      'bus',
      'jeep',
      'market',
      'mall',
      'avenue',
      'ave',
      'road',
      'street',
      'st',
      'corner',
      'barangay',
      'brgy',
      'city hall',
      'qc hall',
    };

    if (rejectedRoadTerms.any(normalized.contains)) {
      return false;
    }

    final railKeywords = {
      'lrt',
      'mrt',
      'pnr',
      'rail',
    };

    if (railKeywords.any(normalized.contains)) {
      return true;
    }

    final knownRailStations = {
      // MRT-3
      'north avenue',
      'quezon avenue',
      'gma kamuning',
      'araneta center cubao',
      'cubao',
      'santolan annapolis',
      'ortigas',
      'shaw boulevard',
      'boni',
      'guadalupe',
      'buendia',
      'ayala',
      'magallanes',
      'taft avenue',

      // LRT-1
      'baclaran',
      'edsa',
      'libertad',
      'gil puyat',
      'vito cruz',
      'quirino',
      'pedro gil',
      'un avenue',
      'central terminal',
      'central',
      'carriedo',
      'doroteo jose',
      'bambang',
      'tayuman',
      'blumentritt',
      'abad santos',
      'r papa',
      '5th avenue',
      'monumento',
      'balintawak',
      'roosevelt',
      'fpj',

      // LRT-2
      'recto',
      'legarda',
      'pureza',
      'v mapa',
      'j ruiz',
      'gilmore',
      'betty go belmonte',
      'anonas',
      'katipunan',
      'santolan',
      'marikina pasig',
      'antipolo',
    };

    return knownRailStations.any((station) {
      return normalized == station ||
          normalized.startsWith('$station ') ||
          normalized.endsWith(' $station') ||
          normalized.contains('$station station');
    });
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

class _GtfsSegmentCandidate {
  final _GtfsRoute route;
  final _GtfsStop boardStop;
  final _GtfsStop alightStop;
  final int boardSequence;
  final int alightSequence;
  final double walkToBoardMeters;
  final double walkFromAlightMeters;

  const _GtfsSegmentCandidate({
    required this.route,
    required this.boardStop,
    required this.alightStop,
    required this.boardSequence,
    required this.alightSequence,
    required this.walkToBoardMeters,
    this.walkFromAlightMeters = 0,
  });

  double get score {
    return walkToBoardMeters +
        walkFromAlightMeters +
        ((alightSequence - boardSequence).abs() * 40);
  }
}
