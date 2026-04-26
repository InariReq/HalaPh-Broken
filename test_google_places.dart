import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/google_maps_api_service.dart';
import 'package:halaph/services/destination_service.dart';

void main() async {
  print('=== TESTING GOOGLE PLACES API ===');
  
  // Test 1: Simple text search
  print('\n--- Test 1: Simple Text Search ---');
  final manilaLocation = LatLng(14.5995, 120.9842);
  final results1 = await GoogleMapsApiService.searchPlaces(query: 'restaurants', location: manilaLocation);
  print('Results: ${results1.length}');
  for (var result in results1.take(3)) {
    print('- ${result.name} (${result.location})');
  }
  
  // Test 2: Trending destinations
  print('\n--- Test 2: Trending Destinations ---');
  final trending = await DestinationService.getTrendingDestinations();
  print('Trending results: ${trending.length}');
  for (var result in trending.take(3)) {
    print('- ${result.name} (${result.location}) - Rating: ${result.rating}');
  }
  
  // Test 3: Enhanced search
  print('\n--- Test 3: Enhanced Search ---');
  final enhanced = await DestinationService.searchDestinationsEnhanced();
  print('Enhanced search results: ${enhanced.length}');
  for (var result in enhanced.take(3)) {
    print('- ${result.name} (${result.location}) - Category: ${result.category}');
  }
  
  print('\n=== TEST COMPLETE ===');
}
