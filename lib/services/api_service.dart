import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Using a mock API for now - replace with real API later
  static const String mockApiBaseUrl = 'https://jsonplaceholder.typicode.com'; // Free mock API
  static const Duration timeout = Duration(seconds: 30);

  // HTTP Client
  static final http.Client _client = http.Client();

  // Mock API GET request for single item
  static Future<Map<String, dynamic>> getMockApi(String endpoint) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$mockApiBaseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
            },
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
            headers: {
              'Content-Type': 'application/json',
            },
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
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$mockApiBaseUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
            },
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
      print('API call successful, got ${response.length} posts from real API');
      print('Returning mock Philippines destinations for now');
      // Return mock Philippines destinations (same for both screens)
      return _getMockDestinationData();
    } catch (e) {
      // Return mock data if API fails
      print('API failed, using mock data: $e');
      return _getMockDestinationData();
    }
  }

  static Future<Map<String, dynamic>> getDestination(String id) async {
    try {
      final response = await getMockApi('/posts/$id');
      return response;
    } catch (e) {
      // Return empty data if API fails
      print('Get destination API failed: $e');
      return {};
    }
  }

  // Search destinations
  static Future<List<dynamic>> searchDestinations(String query) async {
    try {
      final response = await getMockApiList('/posts');
      print('Search API call successful, got ${response.length} posts');
      print('API service is deprecated - returning empty list');
      return [];
    } catch (e) {
      print('Search API failed: $e');
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
        'city_id': 'manila'
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
        'city_id': 'cebu'
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
        'city_id': 'boracay'
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
        'city_id': 'palawan'
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
        'city_id': 'bohol'
      }
    ];
  }

  // Transport endpoints (placeholder for future implementation)
  static Future<List<dynamic>> getTransportOptions(String from, String to) async {
    // For now, return mock transport data
    // Later implement real Philippines transport API
    return [
      {
        'type': 'Jeepney',
        'duration': '25 min',
        'cost': 12.00,
        'description': 'Local jeepney route'
      },
      {
        'type': 'Bus',
        'duration': '35 min', 
        'cost': 20.00,
        'description': 'City bus service'
      },
      {
        'type': 'MRT',
        'duration': '15 min',
        'cost': 15.00,
        'description': 'Metro rail transit'
      }
    ];
  }

  // User endpoints
  static Future<Map<String, dynamic>> login(String email, String password) async {
    return await post('/auth/login', {'email': email, 'password': password});
  }

  static Future<Map<String, dynamic>> register(String email, String password, String name) async {
    return await post('/auth/register', {
      'email': email,
      'password': password,
      'name': name,
    });
  }
}
