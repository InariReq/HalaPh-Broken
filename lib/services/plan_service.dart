import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/destination.dart';

class PlanService {
  static final List<TravelPlan> _plans = [];
  static int _planIdCounter = 1;

  // Get all user plans
  static List<TravelPlan> getUserPlans() {
    debugPrint('=== GET USER PLANS ===');
    debugPrint('Total plans in service: ${_plans.length}');
    for (var plan in _plans) {
      debugPrint('Plan: "${plan.title}" by "${plan.createdBy}"');
    }
    final userPlans = _plans.where((plan) => plan.createdBy == 'current_user').toList();
    debugPrint('User plans count: ${userPlans.length}');
    debugPrint('====================');
    return userPlans;
  }

  // Simple add destination method
  static bool addDestinationToPlanSimple(String planId, Destination destination) {
    try {
      final planIndex = _plans.indexWhere((plan) => plan.id == planId);
      if (planIndex == -1) return false;

      final plan = _plans[planIndex];
      
      // Create new item
      final newItem = ItineraryItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        destination: destination,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 0),
        dayNumber: 1,
        notes: 'Visit ${destination.name}',
      );

      // Add to first day or create new day
      final updatedItinerary = List<DayItinerary>.from(plan.itinerary);
      if (updatedItinerary.isEmpty) {
        updatedItinerary.add(DayItinerary(
          date: DateTime.now(),
          items: [newItem],
        ));
      } else {
        final firstDay = updatedItinerary[0];
        final updatedItems = List<ItineraryItem>.from(firstDay.items);
        updatedItems.add(newItem);
        updatedItinerary[0] = DayItinerary(
          date: firstDay.date,
          items: updatedItems,
        );
      }

      // Update plan
      _plans[planIndex] = TravelPlan(
        id: plan.id,
        title: plan.title,
        startDate: plan.startDate,
        endDate: plan.endDate,
        participantIds: plan.participantIds,
        createdBy: plan.createdBy,
        itinerary: updatedItinerary,
        isShared: plan.isShared,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Create a new travel plan
  static TravelPlan createPlan({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required List<Destination> destinations,
    String createdBy = 'current_user',
    List<DayItinerary>? customItinerary,
  }) {
    // Create itinerary items distributed across days
    final List<DayItinerary> dayItineraries = createDayItineraries(
      startDate,
      endDate,
      destinations,
    );

    final plan = TravelPlan(
      id: 'plan_$_planIdCounter',
      title: title,
      startDate: startDate,
      endDate: endDate,
      participantIds: [createdBy],
      createdBy: createdBy,
      itinerary: customItinerary ?? dayItineraries,
      isShared: false,
    );
    
    _plans.add(plan);
    debugPrint('=== CREATED PLAN ===');
    debugPrint('Plan: "${plan.title}" by "${plan.createdBy}"');
    debugPrint('Total plans now: ${_plans.length}');
    debugPrint('==================');
    _planIdCounter++;
    return plan;
  }

  // Get all plans
  static List<TravelPlan> getAllPlans() {
    return List.from(_plans);
  }

  // Get plan by ID
  static TravelPlan? getPlanById(String id) {
    try {
      return _plans.firstWhere((plan) => plan.id == id);
    } catch (e) {
      return null;
    }
  }

  
  // Delete a plan
  static bool deletePlan(String id) {
    try {
      _plans.removeWhere((plan) => plan.id == id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update a plan
  static bool updatePlan(TravelPlan updatedPlan) {
    try {
      final index = _plans.indexWhere((plan) => plan.id == updatedPlan.id);
      if (index != -1) {
        _plans[index] = updatedPlan;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Create day itineraries from destinations
  static List<DayItinerary> createDayItineraries(
    DateTime startDate,
    DateTime endDate,
    List<Destination> destinations,
  ) {
    final List<DayItinerary> dayItineraries = [];
    final totalDays = endDate.difference(startDate).inDays + 1;
    
    // Distribute destinations across days
    for (int day = 0; day < totalDays; day++) {
      final currentDate = startDate.add(Duration(days: day));
      final List<ItineraryItem> dayItems = [];
      
      // Add destinations for this day
      final destinationsPerDay = (destinations.length / totalDays).ceil();
      final startIndex = day * destinationsPerDay;
      final endIndex = (startIndex + destinationsPerDay).clamp(0, destinations.length);
      
      for (int i = startIndex; i < endIndex; i++) {
        final destination = destinations[i];
        final startHour = 9 + (i % 4) * 2;
        final endHour = 11 + (i % 4) * 2;
        final item = ItineraryItem(
          id: 'item_${_planIdCounter}_${day}_$i',
          destination: destination,
          startTime: TimeOfDay(hour: startHour, minute: 0),
          endTime: TimeOfDay(hour: endHour, minute: 0),
          dayNumber: day + 1,
          notes: 'Visit ${destination.name}',
        );
        dayItems.add(item);
      }
      
      if (dayItems.isNotEmpty) {
        dayItineraries.add(DayItinerary(
          date: currentDate,
          items: dayItems,
        ));
      }
    }
    
    return dayItineraries;
  }
}
