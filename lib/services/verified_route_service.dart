import 'package:flutter/services.dart';
import 'package:halaph/models/verified_route.dart';
import 'package:halaph/services/budget_routing_service.dart';

class VerifiedRouteService {
  static const String _routesAssetPath =
      'lib/Assets/gtfs-master/gtfs-master/routes.txt';

  static List<VerifiedRouteReference>? _cachedRoutes;

  static Future<List<VerifiedRouteReference>> loadHistoricalGtfsRoutes() async {
    if (_cachedRoutes != null) return _cachedRoutes!;

    try {
      final csvText = await rootBundle.loadString(_routesAssetPath);
      final rows = _parseCsv(csvText);
      if (rows.isEmpty) {
        _cachedRoutes = const [];
        return _cachedRoutes!;
      }

      final headers = rows.first;
      final dataRows = rows.skip(1);

      String value(List<String> row, String header) {
        final index = headers.indexOf(header);
        if (index < 0 || index >= row.length) return '';
        return row[index].trim();
      }

      final routes = <VerifiedRouteReference>[];

      for (final row in dataRows) {
        final routeShortName = value(row, 'route_short_name');
        final routeLongName = value(row, 'route_long_name');
        final routeDesc = value(row, 'route_desc');
        final routeType = value(row, 'route_type');
        final routeId = value(row, 'route_id');
        final agencyId = value(row, 'agency_id');

        final routeName =
            routeShortName.isNotEmpty ? routeShortName : routeLongName;

        if (routeName.trim().isEmpty && routeDesc.trim().isEmpty) continue;

        final mode = _modeForGtfsRouteType(routeType);
        if (mode == null) continue;

        routes.add(
          VerifiedRouteReference(
            routeName: routeName,
            routeDescription: routeDesc,
            mode: mode,
            sourceLabel: 'Historical GTFS reference, confirm before riding',
            sourceType: VerifiedRouteSourceType.historicalGtfs,
            sourceDetail:
                'Sakay.ph GTFS entry. Agency: $agencyId. Route ID: $routeId. Calendar data ends 2020-06-30. Use only as a route clue, not current operating proof.',
            lastVerifiedAt: DateTime(2020, 6, 30),
          ),
        );
      }

      _cachedRoutes = routes;
      return routes;
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
    if (requestedMode == routeMode) return true;

    // Historical GTFS route_type 3 covers road public transport. Keep this
    // shared for jeepney, bus, and FX/UV, but label it as historical reference.
    if (routeMode == TravelMode.bus &&
        (requestedMode == TravelMode.jeepney ||
            requestedMode == TravelMode.bus ||
            requestedMode == TravelMode.fx)) {
      return true;
    }

    return false;
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
