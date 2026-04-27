import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:halaph/services/budget_routing_service.dart';
import 'package:halaph/services/google_maps_api_service.dart';

class ApiService {
  // Using a mock API for now - replace with real API later
  static const String mockApiBaseUrl =
      'https://jsonplaceholder.typicode.com'; // Free mock API
  static const Duration timeout = Duration(seconds: 30);

  // HTTP Client
  static final http.Client _client = http.Client();

  // Mock API GET request for single item
  static Future<Map<String, dynamic>> getMockApi(String endpoint) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$mockApiBaseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Mock API GET request for list items
  static Future<List<dynamic>> getMockApiList(String endpoint) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$mockApiBaseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Generic POST request (for future use)
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$mockApiBaseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Destinations endpoints
  static Future<List<dynamic>> getDestinations() async {
    try {
      // Make real HTTP call to test API connectivity
      final response = await getMockApiList('/posts');
      debugPrint(
        'API call successful, got ${response.length} posts from real API',
      );
      debugPrint('Returning mock Philippines destinations for now');
      // Return mock Philippines destinations (same for both screens)
      return _getMockDestinationData();
    } catch (e) {
      // Return mock data if API fails
      debugPrint('API failed, using mock data: $e');
      return _getMockDestinationData();
    }
  }

  static Future<Map<String, dynamic>> getDestination(String id) async {
    try {
      final response = await getMockApi('/posts/$id');
      return response;
    } catch (e) {
      // Return empty data if API fails
      debugPrint('Get destination API failed: $e');
      return {};
    }
  }

  // Search destinations
  static Future<List<dynamic>> searchDestinations(String query) async {
    try {
      final response = await getMockApiList('/posts');
      debugPrint('Search API call successful, got ${response.length} posts');
      debugPrint('API service is deprecated - returning empty list');
      return [];
    } catch (e) {
      debugPrint('Search API failed: $e');
      throw Exception('Search API failed: $e');
    }
  }

  // Mock destination data for fallback
  static List<dynamic> _getMockDestinationData() {
    return [
      {
        'id': '1',
        'city_name': 'Manila',
        'country': 'Philippines',
        'description': 'Capital city of the Philippines with historic sites',
        'category': 'landmark',
        'rating': 4.5,
        'minCost': 100,
        'maxCost': 300,
        'city_id': 'manila',
      },
      {
        'id': '2',
        'city_name': 'Cebu',
        'country': 'Philippines',
        'description': 'Beautiful island city with beaches and heritage sites',
        'category': 'activities',
        'rating': 4.3,
        'minCost': 200,
        'maxCost': 500,
        'city_id': 'cebu',
      },
      {
        'id': '3',
        'city_name': 'Boracay',
        'country': 'Philippines',
        'description': 'Famous white sand beach destination',
        'category': 'park',
        'rating': 4.7,
        'minCost': 300,
        'maxCost': 800,
        'city_id': 'boracay',
      },
      {
        'id': '4',
        'city_name': 'Palawan',
        'country': 'Philippines',
        'description': 'Stunning island with pristine beaches and lagoons',
        'category': 'activities',
        'rating': 4.8,
        'minCost': 400,
        'maxCost': 1000,
        'city_id': 'palawan',
      },
      {
        'id': '5',
        'city_name': 'Bohol',
        'country': 'Philippines',
        'description': 'Home to Chocolate Hills and tarsier sanctuaries',
        'category': 'landmark',
        'rating': 4.4,
        'minCost': 150,
        'maxCost': 400,
        'city_id': 'bohol',
      },
    ];
  }

  static Future<List<dynamic>> getTransportOptions(
    String from,
    String to,
  ) async {
    final origin = await GoogleMapsApiService.geocodeAddress(from);
    final destination = await GoogleMapsApiService.geocodeAddress(to);
    if (origin == null || destination == null) return [];

    final routes = await BudgetRoutingService.calculateBudgetRoutes(
      origin: origin,
      destination: destination,
    );
    return routes
        .map(
          (route) => {
            'type': route.mode.name,
            'duration': '${route.duration.inMinutes} min',
            'distanceKm': route.distance,
            'cost': route.cost,
            'fareRegular': route.fareDetails.regular,
            'fareStudent': route.fareDetails.student,
            'farePwd': route.fareDetails.pwd,
            'fareSenior': route.fareDetails.senior,
            'description': route.summary,
            'route': route.routeDetails?.routeName,
            'instructions': route.instructions,
          },
        )
        .toList();
  }

  // User endpoints
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    return await post('/auth/login', {'email': email, 'password': password});
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String name,
  ) async {
    return await post('/auth/register', {
      'email': email,
      'password': password,
      'name': name,
    });
  }
}
