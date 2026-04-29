import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/simple_plan_service.dart';

void main() {
  tearDown(SimplePlanService.resetCache);

  test(
    'shared plans are visible to creator and selected collaborator',
    () async {
      SimplePlanService.resetCache();

      final destination = Destination(
        id: 'dest-1',
        name: 'Rizal Park',
        location: 'Manila',
        category: DestinationCategory.landmark,
        imageUrl: 'https://example.com/rizal.jpg',
        description: 'Historic park',
        rating: 4.5,
        budget: BudgetInfo(minCost: 0, maxCost: 0),
      );
      final startDate = DateTime.now().add(const Duration(days: 7));
      final endDate = startDate.add(const Duration(days: 1));
      final plan = SimplePlanService.createPlan(
        title: 'Shared Manila Trip',
        startDate: startDate,
        endDate: endDate,
        destinations: [destination],
        createdBy: 'AB-1234',
      );

      final updated = await SimplePlanService.updatePlanParticipants(
        planId: plan.id,
        participantIds: ['cd5678'],
      );

      expect(updated, isTrue);
      expect(SimplePlanService.getUserPlans(ownerId: 'AB1234'), isEmpty);
      expect(
        SimplePlanService.getCollaborativePlans(
          ownerId: 'AB1234',
        ).map((plan) => plan.id),
        contains(plan.id),
      );
      expect(
        SimplePlanService.getPlansSharedWithUser(
          'CD-5678',
        ).map((plan) => plan.id),
        contains(plan.id),
      );
      expect(
        SimplePlanService.getNextUpcomingPlan(userId: 'AB1234')?.id,
        plan.id,
      );
      expect(
        SimplePlanService.getNextUpcomingPlan(userId: 'CD5678')?.id,
        plan.id,
      );
    },
  );
}
