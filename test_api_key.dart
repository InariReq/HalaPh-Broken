import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('=== TESTING API KEY WITH DIFFERENT ENDPOINT ===');
  
  const apiKey = String.fromEnvironment('MAPS_API_KEY');

  if (apiKey.isEmpty) {
    print('MAPS_API_KEY is not configured. Run with --dart-define=MAPS_API_KEY=your_key_here');
    return;
  }
  
  // Test 1: Geocoding API (simpler)
  print('\n1. Testing Geocoding API...');
  final uri1 = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
    'address': 'Manila, Philippines',
    'key': apiKey,
  });
  
  try {
    final response1 = await http.get(uri1);
    print('Status Code: ${response1.statusCode}');
    print('Response: ${response1.body}');
    
    if (response1.statusCode == 200) {
      final data = json.decode(response1.body);
      print('Status: ${data['status']}');
      if (data['status'] == 'OK') {
        print('Geocoding API works! API key is valid');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
  
  // Test 2: Places API with simple query
  print('\n2. Testing Places API...');
  final uri2 = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
    'query': 'restaurants Manila',
    'key': apiKey,
  });
  
  try {
    final response2 = await http.get(uri2);
    print('Status Code: ${response2.statusCode}');
    print('Response: ${response2.body}');
    
    if (response2.statusCode == 200) {
      final data = json.decode(response2.body);
      print('Status: ${data['status']}');
      if (data['status'] == 'OK') {
        print('Places API works!');
      } else {
        print('Places API error: ${data['error_message'] ?? 'No error message'}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
