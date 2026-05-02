import 'dart:io';
import 'package:flutter/foundation.dart';

/// Tracks Google API usage to monitor $300 credit consumption.
/// Logs to file in app documents directory (no Firebase writes = no extra costs).
/// DOES NOT block API calls - only tracks and warns (important for demos).
class ApiUsageTracker {
  static const String _logFileName = 'api_usage.log';
  static const int _maxLogLines = 500;

  // Approximate costs (USD per 1000 requests)
  static const double _placeSearchCostPer1k = 17.0; // Text Search
  static const double _placeDetailsCostPer1k = 17.0; // Place Details
  static const double _autocompleteCostPer1k = 2.83; // Autocomplete

  // WARNING ONLY - no blocking (for demo purposes)
  static const double _highSpendWarningUSD = 250.0;

  static int _placeSearches = 0;
  static int _placeDetails = 0;
  static int _autocompleteCalls = 0;
  static DateTime _sessionStart = DateTime.now();
  // _totalSpent removed - using per-call calculation in _printCreditsUsed()

  static void logPlaceSearch(String query, {bool fromCache = false}) {
    if (fromCache) return;
    _placeSearches++;
    _log('PLACES_SEARCH', 'query="$query" (total: $_placeSearches)');
    _printCreditsUsed();
  }

  static void logPlaceDetails(String placeId, {bool fromCache = false}) {
    if (fromCache) return;
    _placeDetails++;
    _log('PLACE_DETAILS', 'id="$placeId" (total: $_placeDetails)');
    _printCreditsUsed();
  }

  static void logAutocomplete(String input, {bool fromCache = false}) {
    if (fromCache) return;
    _autocompleteCalls++;
    _log('AUTOCOMPLETE', 'input="$input" (total: $_autocompleteCalls)');
    _printCreditsUsed();
  }

  static void _printCreditsUsed() {
    final searchCost = (_placeSearches / 1000) * _placeSearchCostPer1k;
    final detailsCost = (_placeDetails / 1000) * _placeDetailsCostPer1k;
    final autoCost = (_autocompleteCalls / 1000) * _autocompleteCostPer1k;
    final total = searchCost + detailsCost + autoCost;
    final runtime = DateTime.now().difference(_sessionStart).inMinutes;

    debugPrint('💰 API COSTS (session: ${runtime}min):');
    debugPrint('  Place Searches: $_placeSearches (\$${searchCost.toStringAsFixed(2)})');
    debugPrint('  Place Details:  $_placeDetails (\$${detailsCost.toStringAsFixed(2)})');
    debugPrint('  Autocomplete:   $_autocompleteCalls (\$${autoCost.toStringAsFixed(2)})');
    debugPrint('  TOTAL ESTIMATED: \$${total.toStringAsFixed(2)}');
    debugPrint('  REMAINING CREDITS: \$${(300.0 - total).toStringAsFixed(2)}');

    if (total > _highSpendWarningUSD) {
      debugPrint('⚠️ WARNING: Over \$$_highSpendWarningUSD spent! \$${300.0 - total} remaining.');
    }
  }

  static void _log(String type, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] $type: $message\n';
    
    try {
      final file = File(_logFileName);
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        if (lines.length >= _maxLogLines) {
          // Keep only last 400 lines
          final kept = lines.skip(lines.length - 400).join('\n');
          file.writeAsStringSync('$kept\n');
        }
      }
      file.writeAsStringSync(logLine, mode: FileMode.append);
    } catch (_) {
      // Fail silently - don't crash app over logging
    }
  }

  static Map<String, dynamic> getUsageSummary() {
    final searchCost = (_placeSearches / 1000) * _placeSearchCostPer1k;
    final detailsCost = (_placeDetails / 1000) * _placeDetailsCostPer1k;
    final autoCost = (_autocompleteCalls / 1000) * _autocompleteCostPer1k;
    final total = searchCost + detailsCost + autoCost;

    return {
      'placeSearches': _placeSearches,
      'placeDetails': _placeDetails,
      'autocompleteCalls': _autocompleteCalls,
      'estimatedCostUSD': double.parse(total.toStringAsFixed(2)),
      'remainingCredits': double.parse((300.0 - total).toStringAsFixed(2)),
      'sessionMinutes': DateTime.now().difference(_sessionStart).inMinutes,
    };
  }

  static void resetSession() {
    _placeSearches = 0;
    _placeDetails = 0;
    _autocompleteCalls = 0;
    _sessionStart = DateTime.now();
    debugPrint('📊 API Usage Tracker: Session reset');
  }
}
