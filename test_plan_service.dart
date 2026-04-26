import 'lib/services/simple_plan_service.dart';
import 'lib/models/destination.dart';

void main() {
  print('Testing SimplePlanService...');
  
  // Check existing plans
  final existingPlans = SimplePlanService.getAllPlans();
  print('Existing plans: ${existingPlans.length}');
  for (final plan in existingPlans) {
    print('  - ${plan.id}: ${plan.title}');
  }
  
  // Create a test plan if none exist
  if (existingPlans.isEmpty) {
    print('Creating test plan...');
    final testDestinations = [
      Destination(
        id: 'dest1',
        name: 'Manila Bay',
        location: 'Manila',
        category: DestinationCategory.landmark,
        imageUrl: 'https://example.com/bay.jpg',
        description: 'Beautiful bay sunset',
        rating: 4.5,
        budget: BudgetInfo(minCost: 100, maxCost: 500),
      ),
    ];
    
    final testPlan = SimplePlanService.createPlan(
      title: 'Test Manila Tour',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: 2)),
      destinations: testDestinations,
    );
    
    print('Created plan: ${testPlan.id} - ${testPlan.title}');
  }
  
  // Test retrieval
  final plans = SimplePlanService.getAllPlans();
  print('Plans after test: ${plans.length}');
  for (final plan in plans) {
    print('  - ${plan.id}: ${plan.title}');
    final retrieved = SimplePlanService.getPlanById(plan.id);
    print('    Retrieved: ${retrieved?.title ?? "NULL"}');
  }
}
