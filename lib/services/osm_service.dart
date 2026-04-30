import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:halaph/models/destination.dart';

class OSMService {
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _overpassBase = 'https://overpass-api.de/api/interpreter';
  static const _osrmBase = 'https://router.project-osrm.org';
  static const _wikidataBase = 'https://www.wikidata.org';
  static const _commonsFilePath =
      'https://commons.wikimedia.org/wiki/Special:FilePath';
  static const _headers = {'User-Agent': 'HalaPh App (halaph.app)'};

  // Get places near a location using Nominatim (FREE, no billing)
  static Future<List<Destination>> searchNearbyPlaces({
    required double lat,
    required double lon,
    String? query,
    double radius = 5000, // meters
    int limit = 20,
  }) async {
    try {
      debugPrint('🌍 OSM: Searching near $lat, $lon for "$query" (FREE)');
      final normalizedQuery = query?.toLowerCase().trim() ?? '';
      final focusedOverpass = _overpassFiltersForQuery(
        normalizedQuery,
        radius,
        lat,
        lon,
      );

      // Use Overpass API to query OSM data
      final overpassQuery =
          '''
        [out:json][timeout:25];
        (
          $focusedOverpass
        );
        out center tags;
      ''';

      final uri = Uri.parse(_overpassBase);
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              ..._headers,
            },
            body: 'data=${Uri.encodeComponent(overpassQuery)}',
          )
          .timeout(const Duration(seconds: 15));

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

        return unique.values.take(limit).toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
      } else {
        debugPrint('🌍 OSM: Overpass API failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🌍 OSM: Error searching places: $e');
    }

    return [];
  }

  static String _overpassFiltersForQuery(
    String query,
    double radius,
    double lat,
    double lon,
  ) {
    final filters = <String>[];
    void addNode(String selector) {
      filters.add('node$selector(around:$radius,$lat,$lon);');
      filters.add('way$selector(around:$radius,$lat,$lon);');
    }

    if (query.contains('train') ||
        query.contains('mrt') ||
        query.contains('lrt') ||
        query.contains('station') ||
        query.contains('transit')) {
      addNode('["railway"="station"]');
      addNode('["public_transport"="station"]');
      addNode('["public_transport"="stop_position"]');
    }
    if (query.contains('bus') || query.contains('terminal')) {
      addNode('["amenity"="bus_station"]');
      addNode('["highway"="bus_stop"]');
      addNode('["public_transport"="platform"]');
    }
    if (query.contains('mall') ||
        query.contains('shopping') ||
        query.contains('market') ||
        query.contains('shop')) {
      addNode('["shop"]');
      addNode('["amenity"="marketplace"]');
    }
    if (query.contains('food') ||
        query.contains('restaurant') ||
        query.contains('cafe') ||
        query.contains('coffee')) {
      addNode('["amenity"="restaurant"]');
      addNode('["amenity"="cafe"]');
      addNode('["amenity"="food_court"]');
    }
    if (query.contains('park') || query.contains('outdoor')) {
      addNode('["leisure"="park"]');
      addNode('["tourism"="attraction"]');
    }

    if (filters.isEmpty) {
      addNode('["tourism"]');
      addNode('["amenity"="restaurant"]');
      addNode('["amenity"="cafe"]');
      addNode('["amenity"="bar"]');
      addNode('["shop"]');
      addNode('["leisure"="park"]');
    }

    return filters.join('\n');
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
        'extratags': '1',
        if (lat != null && lon != null) ...{
          'lat': lat.toString(),
          'lon': lon.toString(),
        },
      };

      final uri = Uri.parse(
        '$_nominatimBase/search',
      ).replace(queryParameters: params);

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

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

  static Future<List<Destination>> enrichDestinationsWithImages(
    List<Destination> destinations, {
    int maxLookups = 12,
  }) async {
    var lookupCount = 0;
    final futures = destinations.map((destination) async {
      if (_hasUsableImage(destination.imageUrl)) return destination;
      if (lookupCount >= maxLookups) return destination;
      lookupCount += 1;

      final imageUrl = await _resolveImageForDestination(
        destination,
      ).timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (!_hasUsableImage(imageUrl)) return destination;
      return _withImage(destination, imageUrl!);
    }).toList();

    return Future.wait(futures);
  }

  static Future<LatLng?> geocodeAddress(String query) async {
    final results = await searchPlacesByText(query: query, limit: 1);
    if (results.isEmpty) return null;
    return results.first.coordinates;
  }

  // Get directions using OSRM (FREE, no billing)
  static Future<Map<String, dynamic>?> getDirections({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    String profile = 'walking', // walking or cycling
  }) async {
    try {
      debugPrint('🌍 OSRM: Getting $profile directions (FREE)');

      final url =
          '$_osrmBase/route/v1/$profile/$startLon,$startLat;$endLon,$endLat';
      final uri = Uri.parse('$url?overview=full&geometries=geojson');

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

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

  static Destination? _convertOSMElementToDestination(
    Map<String, dynamic> element,
  ) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final id = 'osm_${element['id']}';
    final name = (tags['name'] ?? tags['name:en'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    final type =
        tags['tourism'] ?? tags['amenity'] ?? tags['shop'] ?? 'attraction';

    final center = element['center'] as Map<String, dynamic>?;
    final lat = _toDouble(element['lat'] ?? center?['lat']);
    final lon = _toDouble(element['lon'] ?? center?['lon']);
    if (lat == null || lon == null) return null;

    return Destination(
      id: id,
      name: name,
      description: _generateDescription(name, type),
      location: _locationFromTags(tags),
      imageUrl: _imageUrlFromTags(tags) ?? '',
      coordinates: LatLng(lat, lon),
      category: _mapOSMCategory(type),
      rating: 4.0, // Default rating
      tags: _destinationTags(type.toString(), tags),
      budget: BudgetInfo(minCost: 0, maxCost: 500, currency: 'PHP'),
    );
  }

  static Destination _convertNominatimToDestination(Map<String, dynamic> item) {
    final id = 'nominatim_${item['place_id']}';
    final name = item['display_name']?.split(',').first ?? 'Unknown Place';
    final lat = double.parse(item['lat']);
    final lon = double.parse(item['lon']);
    final type = item['type'] ?? 'place';
    final extraTags = item['extratags'] is Map
        ? Map<String, dynamic>.from(item['extratags'])
        : <String, dynamic>{};

    return Destination(
      id: id,
      name: name,
      description: _generateDescription(name, type),
      location: item['display_name'] ?? 'Philippines',
      imageUrl: _imageUrlFromTags(extraTags) ?? '',
      coordinates: LatLng(lat, lon),
      category: _mapOSMCategory(type),
      rating: 4.0,
      tags: _destinationTags(type.toString(), extraTags),
      budget: BudgetInfo(minCost: 0, maxCost: 500, currency: 'PHP'),
    );
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String _locationFromTags(Map<String, dynamic> tags) {
    final full = tags['addr:full']?.toString().trim();
    if (full != null && full.isNotEmpty) return full;

    final parts =
        [
          tags['addr:street'],
          tags['addr:suburb'],
          tags['addr:city'] ?? tags['addr:municipality'],
          tags['addr:province'],
        ].whereType<Object>().map((part) => part.toString().trim()).where((
          part,
        ) {
          return part.isNotEmpty;
        }).toList();

    if (parts.isNotEmpty) return parts.join(', ');
    return 'Philippines';
  }

  static List<String> _destinationTags(
    String type,
    Map<String, dynamic> sourceTags,
  ) {
    final tags = <String>[
      type,
      if (sourceTags['tourism'] != null) 'tourism:${sourceTags['tourism']}',
      if (sourceTags['amenity'] != null) 'amenity:${sourceTags['amenity']}',
      if (sourceTags['shop'] != null) 'shop:${sourceTags['shop']}',
      if (sourceTags['leisure'] != null) 'leisure:${sourceTags['leisure']}',
      if (sourceTags['wikidata'] != null) 'wikidata:${sourceTags['wikidata']}',
      if (sourceTags['wikipedia'] != null)
        'wikipedia:${sourceTags['wikipedia']}',
      if (sourceTags['wikimedia_commons'] != null)
        'commons:${sourceTags['wikimedia_commons']}',
      if (sourceTags['image'] != null) 'image:${sourceTags['image']}',
    ];
    return tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String? _imageUrlFromTags(Map<String, dynamic> tags) {
    final directImage = tags['image']?.toString().trim();
    if (_hasUsableImage(directImage)) return directImage;

    final commons = tags['wikimedia_commons']?.toString().trim();
    final commonsUrl = _commonsImageUrl(commons);
    if (_hasUsableImage(commonsUrl)) return commonsUrl;

    return null;
  }

  static Future<String?> _resolveImageForDestination(
    Destination destination,
  ) async {
    final directImage = _tagValue(destination.tags, 'image:');
    if (_hasUsableImage(directImage)) return directImage;

    final commons = _tagValue(destination.tags, 'commons:');
    final commonsUrl = _commonsImageUrl(commons);
    if (_hasUsableImage(commonsUrl)) return commonsUrl;

    final wikidata = _tagValue(destination.tags, 'wikidata:');
    final wikidataImage = await _imageFromWikidata(wikidata);
    if (_hasUsableImage(wikidataImage)) return wikidataImage;

    final wikipedia = _tagValue(destination.tags, 'wikipedia:');
    final wikipediaImage = await _imageFromWikipediaTag(wikipedia);
    if (_hasUsableImage(wikipediaImage)) return wikipediaImage;

    return null;
  }

  static String? _tagValue(List<String> tags, String prefix) {
    for (final tag in tags) {
      if (tag.startsWith(prefix)) return tag.substring(prefix.length).trim();
    }
    return null;
  }

  static Future<String?> _imageFromWikidata(String? wikidataId) async {
    if (wikidataId == null || !wikidataId.startsWith('Q')) return null;

    try {
      final uri = Uri.parse('$_wikidataBase/w/api.php').replace(
        queryParameters: {
          'action': 'wbgetclaims',
          'entity': wikidataId,
          'property': 'P18',
          'format': 'json',
        },
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final claims = data['claims'] as Map<String, dynamic>?;
      final p18 = claims?['P18'];
      if (p18 is! List || p18.isEmpty) return null;
      final firstClaim = p18.first as Map<String, dynamic>;
      final mainsnak = firstClaim['mainsnak'] as Map<String, dynamic>?;
      final dataValue = mainsnak?['datavalue'] as Map<String, dynamic>?;
      final fileName = dataValue?['value']?.toString();
      return _commonsFileUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _imageFromWikipediaTag(String? wikipediaTag) async {
    if (wikipediaTag == null || wikipediaTag.trim().isEmpty) return null;
    final separatorIndex = wikipediaTag.indexOf(':');
    final language = separatorIndex > 0
        ? wikipediaTag.substring(0, separatorIndex)
        : 'en';
    final title = separatorIndex > 0
        ? wikipediaTag.substring(separatorIndex + 1)
        : wikipediaTag;
    return _imageFromWikipediaSummary(language, title);
  }

  static Future<String?> _imageFromWikipediaSummary(
    String language,
    String title,
  ) async {
    try {
      final normalizedTitle = title.replaceAll(' ', '_');
      final uri = Uri.parse(
        'https://$language.wikipedia.org/api/rest_v1/page/summary/'
        '${Uri.encodeComponent(normalizedTitle)}',
      );
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final thumbnail = data['thumbnail'] as Map<String, dynamic>?;
      final original = data['originalimage'] as Map<String, dynamic>?;
      final source =
          thumbnail?['source']?.toString() ?? original?['source']?.toString();
      return _hasUsableImage(source) ? source : null;
    } catch (_) {
      return null;
    }
  }

  static String? _commonsImageUrl(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) return null;
    final value = rawValue.trim();
    if (_hasUsableImage(value)) return value;
    if (value.toLowerCase().startsWith('category:')) return null;
    final fileName = value.toLowerCase().startsWith('file:')
        ? value.substring(5)
        : value;
    return _commonsFileUrl(fileName);
  }

  static String? _commonsFileUrl(String? rawFileName) {
    final fileName = rawFileName?.trim();
    if (fileName == null || fileName.isEmpty) return null;
    if (fileName.toLowerCase().endsWith('.svg')) return null;
    return '$_commonsFilePath/${Uri.encodeComponent(fileName)}?width=900';
  }

  static bool _hasUsableImage(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.startsWith('http') && !lower.contains('.svg');
  }

  static Destination _withImage(Destination destination, String imageUrl) {
    return Destination(
      id: destination.id,
      name: destination.name,
      description: destination.description,
      location: destination.location,
      coordinates: destination.coordinates,
      imageUrl: imageUrl,
      category: destination.category,
      rating: destination.rating,
      tags: destination.tags,
      budget: destination.budget,
    );
  }

  static DestinationCategory _mapOSMCategory(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('restaurant') ||
        lower.contains('cafe') ||
        lower.contains('bar')) {
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
