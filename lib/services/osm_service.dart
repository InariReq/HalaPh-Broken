import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:halaph/models/destination.dart';

class OSMService {
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _overpassBase = 'https://overpass-api.de/api/interpreter';
  static const _osrmBase = 'https://router.project-osrm.org';

  // Get places near a location using Nominatim (FREE, no billing)
  static Future<List<Destination>> searchNearbyPlaces({
    required double lat,
    required double lon,
    String? query,
    double radius = 5000, // meters
    int limit = 20,
  }) async {
    try {
      debugPrint('🌍 OSM: Searching near $lat, $lon (FREE)');

      // Use Overpass API to query OSM data
      final queryStr = query ?? 'tourist_attraction';
      final overpassQuery = '''
        [out:json][timeout:25];
        (
          node["tourism"](around:$radius,$lat,$lon);
          way["tourism"](around:$radius,$lat,$lon);
          node["amenity"="restaurant"](around:$radius,$lat,$lon);
          node["amenity"="cafe"](around:$radius,$lat,$lon);
          node["amenity"="bar"](around:$radius,$lat,$lon);
          node["shop"](around:$radius,$lat,$lon);
          node["leisure"="park"](around:$radius,$lat,$lon);
        );
        out body;
        >;
        out skel qt;
      ''';

      final uri = Uri.parse(_overpassBase);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'HalaPh App (halaph.app)',
        },
        body: 'data=${Uri.encodeComponent(overpassQuery)}',
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List? ?? [];
        
        debugPrint('🌍 OSM: Got ${elements.length} elements from Overpass');
        
        final places = <Destination>[];
        for (final element in elements) {
          try {
            final destination = _convertOSMElementToDestination(element);
            if (destination != null) {
              places.add(destination);
            }
          } catch (e) {
            debugPrint('🌍 OSM: Error converting element: $e');
          }
        }

        // Remove duplicates and sort by distance
        final unique = <String, Destination>{};
        for (final place in places) {
          unique[place.id] = place;
        }

        return unique.values.toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
      } else {
        debugPrint('🌍 OSM: Overpass API failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🌍 OSM: Error searching places: $e');
    }

    return [];
  }

  // Search places by text using Nominatim (FREE)
  static Future<List<Destination>> searchPlacesByText({
    required String query,
    double? lat,
    double? lon,
    int limit = 10,
  }) async {
    try {
      debugPrint('🌍 OSM: Text search for "$query" (FREE)');

      final params = {
        'q': '$query Philippines',
        'format': 'json',
        'limit': limit.toString(),
        'addressdetails': '1',
        'namedetails': '1',
        if (lat != null && lon != null) ...{
          'lat': lat.toString(),
          'lon': lon.toString(),
        },
      };

      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        params,
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'HalaPh App (halaph.app)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        debugPrint('🌍 OSM: Got ${data.length} results from Nominatim');

        return data.map((item) {
          return _convertNominatimToDestination(item);
        }).toList();
      }
    } catch (e) {
      debugPrint('🌍 OSM: Nominatim search error: $e');
    }

    return [];
  }

  // Get directions using OSRM (FREE, no billing)
  static Future<Map<String, dynamic>?> getDirections({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String profile = 'driving', // driving, walking, cycling
  }) async {
    try {
      debugPrint('🌍 OSRM: Getting $profile directions (FREE)');

      final url = '$_osrmBase/route/v1/$profile/$startLon,$startLat;$endLon,$endLat';
      final uri = Uri.parse('$url?overview=full&geometries=geojson');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok') {
          final route = data['routes'][0];
          return {
            'distance': route['distance'], // meters
            'duration': route['duration'], // seconds
            'geometry': route['geometry'],
          };
        }
      }
    } catch (e) {
      debugPrint('🌍 OSRM: Directions error: $e');
    }

    return null;
  }

  static Destination? _convertOSMElementToDestination(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final id = 'osm_${element['id']}';
    final name = tags['name'] ?? tags['name:en'] ?? 'Unnamed Place';
    final type = tags['tourism'] ?? tags['amenity'] ?? tags['shop'] ?? 'attraction';
    
    final lat = element['lat']?.toDouble();
    final lon = element['lon']?.toDouble();
    if (lat == null || lon == null) return null;

    return Destination(
      id: id,
      name: name,
      description: _generateDescription(name, type),
      location: tags['addr:full'] ?? 
                   '${tags['addr:city'] ?? 'Philippines'}',
      imageUrl: '', // OSM doesn't provide images
      coordinates: LatLng(lat, lon),
      category: _mapOSMCategory(type),
      rating: 4.0, // Default rating
      tags: [type, ...tags['tourism'] != null ? ['tourism'] : []],
      budget: BudgetInfo(minCost: 0, maxCost: 500, currency: 'PHP'),
    );
  }

  static Destination _convertNominatimToDestination(Map<String, dynamic> item) {
    final id = 'nominatim_${item['place_id']}';
    final name = item['display_name']?.split(',').first ?? 'Unknown Place';
    final lat = double.parse(item['lat']);
    final lon = double.parse(item['lon']);
    final type = item['type'] ?? 'place';

    return Destination(
      id: id,
      name: name,
      description: _generateDescription(name, type),
      location: item['display_name'] ?? 'Philippines',
      imageUrl: '',
      coordinates: LatLng(lat, lon),
      category: _mapOSMCategory(type),
      rating: 4.0,
      tags: [type],
      budget: BudgetInfo(minCost: 0, maxCost: 500, currency: 'PHP'),
    );
  }

  static DestinationCategory _mapOSMCategory(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('restaurant') || lower.contains('cafe') || lower.contains('bar')) {
      return DestinationCategory.food;
    } else if (lower.contains('park') || lower.contains('leisure')) {
      return DestinationCategory.park;
    } else if (lower.contains('museum') || lower.contains('gallery')) {
      return DestinationCategory.museum;
    } else if (lower.contains('shop') || lower.contains('market')) {
      return DestinationCategory.market;
    } else if (lower.contains('tourist') || lower.contains('attraction')) {
      return DestinationCategory.landmark;
    }
    return DestinationCategory.activities;
  }

  static String _generateDescription(String name, String type) {
    return 'A popular $type called $name. Great for visitors looking to explore the area.';
  }
}
