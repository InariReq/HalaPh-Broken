import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('=== TESTING GOOGLE PLACES API DIRECTLY ===');
  
  const apiKey = String.fromEnvironment('MAPS_API_KEY');
  const baseUrl = 'https://maps.googleapis.com/maps/api/place';

  if (apiKey.isEmpty) {
    print('MAPS_API_KEY is not configured. Run with --dart-define=MAPS_API_KEY=your_key_here');
    return;
  }
  
  // Test 1: Simple text search
  print('\n1. Testing text search...');
  final url1 = '$baseUrl/textsearch/json?query=restaurants%20Manila&key=$apiKey';
  print('URL: ${url1.replaceAll(apiKey, 'HIDDEN_KEY')}');
  
  try {
    final response1 = await http.get(Uri.parse(url1));
    print('Status Code: ${response1.statusCode}');
    print('Response Body: ${response1.body}');
    
    if (response1.statusCode == 200) {
      final data = json.decode(response1.body);
      print('Status: ${data['status']}');
      if (data['status'] == 'OK') {
        print('✅ SUCCESS: Found ${data['results'].length} results');
      } else {
        print('❌ ERROR: ${data['status']}');
        if (data.containsKey('error_message')) {
          print('Error Message: ${data['error_message']}');
        }
      }
    }
  } catch (e) {
    print('❌ EXCEPTION: $e');
  }
  
  // Test 2: Find place
  print('\n2. Testing find place...');
  final url2 = '$baseUrl/findplacefromtext/json?input=SM%20Mall%20of%20Asia%20Philippines&inputtype=textquery&key=$apiKey';
  print('URL: ${url2.replaceAll(apiKey, 'HIDDEN_KEY')}');
  
  try {
    final response2 = await http.get(Uri.parse(url2));
    print('Status Code: ${response2.statusCode}');
    print('Response Body: ${response2.body}');
    
    if (response2.statusCode == 200) {
      final data = json.decode(response2.body);
      print('Status: ${data['status']}');
      if (data['status'] == 'OK') {
        print('✅ SUCCESS: Found place');
      } else {
        print('❌ ERROR: ${data['status']}');
        if (data.containsKey('error_message')) {
          print('Error Message: ${data['error_message']}');
        }
      }
    }
  } catch (e) {
    print('❌ EXCEPTION: $e');
  }
  
  print('\n=== TEST COMPLETE ===');
}
