import 'package:halaph/models/destination.dart';
import 'package:halaph/services/simple_plan_service.dart';

Future<void> main() async {
  print('Testing banner image fix...');
  SimplePlanService.debugAllowMemoryOnlyPlans = true;

  // Clear any existing plans
  SimplePlanService.clearAllPlans();

  // Create a test destination
  final destination = Destination(
    id: 'test_dest',
    name: 'Test Destination',
    location: 'Test Location',
    category: DestinationCategory.landmark,
    imageUrl: 'https://picsum.photos/seed/test/400/300',
    description: 'Test description',
    rating: 4.5,
    budget: BudgetInfo(minCost: 100, maxCost: 500),
  );

  // Create a plan with banner image
  final testBannerUrl = 'https://picsum.photos/seed/banner_test/400/200';
  final plan = SimplePlanService.createPlan(
    title: 'Test Plan',
    startDate: DateTime.now(),
    endDate: DateTime.now().add(Duration(days: 2)),
    destinations: [destination],
    bannerImage: testBannerUrl,
  );

  print('Created plan with banner image: ${plan.bannerImage}');

  // Verify banner image is set
  if (plan.bannerImage == testBannerUrl) {
    print('SUCCESS: Banner image set correctly during creation');
  } else {
    print('ERROR: Banner image not set correctly during creation');
    return;
  }

  // Update the plan without changing banner image
  final success = await SimplePlanService.updatePlan(
    planId: plan.id,
    title: 'Updated Test Plan',
    bannerImage: null, // This should preserve the existing banner image
  );

  if (success) {
    final updatedPlan = SimplePlanService.getPlanById(plan.id);
    print('Updated plan banner image: ${updatedPlan?.bannerImage}');

    // Verify banner image is preserved
    if (updatedPlan?.bannerImage == testBannerUrl) {
      print('SUCCESS: Banner image preserved during update');
    } else {
      print('ERROR: Banner image lost during update');
    }
  } else {
    print('ERROR: Failed to update plan');
  }

  // Test updating with new banner image
  final newBannerUrl = 'https://picsum.photos/seed/new_banner/400/200';
  final success2 = await SimplePlanService.updatePlan(
    planId: plan.id,
    title: 'Updated Test Plan with New Banner',
    bannerImage: newBannerUrl,
  );

  if (success2) {
    final updatedPlan2 = SimplePlanService.getPlanById(plan.id);
    print('Updated plan with new banner image: ${updatedPlan2?.bannerImage}');

    // Verify banner image is updated
    if (updatedPlan2?.bannerImage == newBannerUrl) {
      print('SUCCESS: Banner image updated correctly');
    } else {
      print('ERROR: Banner image not updated correctly');
    }
  } else {
    print('ERROR: Failed to update plan with new banner');
  }

  print('Test completed!');
  SimplePlanService.debugAllowMemoryOnlyPlans = false;
}
