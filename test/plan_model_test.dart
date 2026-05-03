import 'package:flutter_test/flutter_test.dart';
import 'package:halaph/models/plan.dart';

void main() {
  test('TravelPlan JSON round-trip', () {
    final plan = TravelPlan(
      id: 'plan1',
      title: 'Test Plan',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 1)),
      participantUids: ['u1'],
      createdBy: 'u1',
      itinerary: [],
      isShared: false,
      bannerImage: null,
    );

    final json = plan.toJson();
    final rebuilt = TravelPlan.fromJson(Map<String, dynamic>.from(json));
    expect(rebuilt.id, plan.id);
    expect(rebuilt.title, plan.title);
  });
}
