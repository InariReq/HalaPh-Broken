import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/services/budget_routing_service.dart';

void main() async {
  print('=== TESTING BUDGET ROUTING SERVICE ===');
  
  // Test locations in Manila
  final origin = LatLng(14.5995, 120.9842); // Manila area
  final destination = LatLng(14.5833, 120.9833); // Rizal Park
  
  print('\n--- Route Calculation Test ---');
  print('Origin: ${origin.latitude}, ${origin.longitude}');
  print('Destination: ${destination.latitude}, ${destination.longitude}');
  
  try {
    final routes = await BudgetRoutingService.calculateBudgetRoutes(
      origin: origin,
      destination: destination,
    );
    
    print('\nFound ${routes.length} routes:');
    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      print('\nRoute ${i + 1}: ${route.summary}');
      print('  Mode: ${route.mode}');
      print('  Duration: ${route.duration.inMinutes} minutes');
      print('  Distance: ${route.distance.toStringAsFixed(2)} km');
      print('  Fare: ${route.cost == 0.0 ? 'Free' : 'PHP ${route.cost.toStringAsFixed(2)}'}');
      print('  Instructions: ${route.instructions.length}');
      
      for (int j = 0; j < route.instructions.length; j++) {
        print('    Step ${j + 1}: ${route.instructions[j]}');
      }
    }
    
    print('\n=== TEST COMPLETE ===');
  } catch (e) {
    print('Error: $e');
  }
}
