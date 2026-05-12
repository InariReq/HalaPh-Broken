import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../models/plan.dart';
import 'budget_routing_service.dart';

class GuideModeDemoDestination {
  final String name;
  final String type;
  final String description;
  final String ratingDisplay;
  final String locationLabel;
  final IconData icon;

  const GuideModeDemoDestination({
    required this.name,
    required this.type,
    required this.description,
    required this.ratingDisplay,
    required this.locationLabel,
    required this.icon,
  });
}

class GuideModeDemoRouteOption {
  final String title;
  final List<TravelMode> modes;
  final String fare;
  final String reason;
  final String source;
  final String time;

  const GuideModeDemoRouteOption({
    required this.title,
    required this.modes,
    required this.fare,
    required this.reason,
    required this.source,
    required this.time,
  });
}

class GuideModeDemoRouteStep {
  final int number;
  final TravelMode mode;
  final String modeLabel;
  final String instruction;
  final String? fare;
  final String? transferHint;

  const GuideModeDemoRouteStep({
    required this.number,
    required this.mode,
    required this.modeLabel,
    required this.instruction,
    this.fare,
    this.transferHint,
  });
}

class GuideModeDemoFareLine {
  final String label;
  final String amount;
  final bool isTotal;

  const GuideModeDemoFareLine({
    required this.label,
    required this.amount,
    this.isTotal = false,
  });
}

class GuideModeDemoPlan {
  final String title;
  final int stopCount;
  final List<String> stops;
  final String estimatedBudget;
  final bool shared;

  const GuideModeDemoPlan({
    required this.title,
    required this.stopCount,
    required this.stops,
    required this.estimatedBudget,
    required this.shared,
  });
}

class GuideModeDemoCollaboration {
  final String planTitle;
  final List<String> participants;
  final String note;

  const GuideModeDemoCollaboration({
    required this.planTitle,
    required this.participants,
    required this.note,
  });
}

class GuideModeDemoReminder {
  final String primary;
  final String secondary;

  const GuideModeDemoReminder({
    required this.primary,
    required this.secondary,
  });
}

class GuideModeDemoTripHistory {
  final String title;
  final int stopCount;
  final String finishedLabel;

  const GuideModeDemoTripHistory({
    required this.title,
    required this.stopCount,
    required this.finishedLabel,
  });
}

class GuideModeDemoData {
  static const destinations = [
    GuideModeDemoDestination(
      name: 'Intramuros',
      type: 'Landmark',
      description: 'Historic walls, museums, and walkable Manila stops.',
      ratingDisplay: '4.8 guide rating',
      locationLabel: 'Manila heritage district',
      icon: Icons.fort_rounded,
    ),
    GuideModeDemoDestination(
      name: 'Rizal Park',
      type: 'Park',
      description: 'Open green space for a calm stop between museums.',
      ratingDisplay: '4.7 guide rating',
      locationLabel: 'Central Manila',
      icon: Icons.park_rounded,
    ),
    GuideModeDemoDestination(
      name: 'National Museum',
      type: 'Museum',
      description: 'Culture stop near other Manila landmarks.',
      ratingDisplay: '4.8 guide rating',
      locationLabel: 'Museum complex',
      icon: Icons.museum_rounded,
    ),
    GuideModeDemoDestination(
      name: 'SM Mall of Asia',
      type: 'Mall',
      description: 'Large bay-area mall with food, shops, and events.',
      ratingDisplay: '4.6 guide rating',
      locationLabel: 'Pasay bay area',
      icon: Icons.store_mall_directory_rounded,
    ),
  ];

  static const routeOptions = [
    GuideModeDemoRouteOption(
      title: 'Walking',
      modes: [TravelMode.walking],
      fare: '₱0',
      reason: 'Best for nearby places',
      source: 'Walking route',
      time: '8 min',
    ),
    GuideModeDemoRouteOption(
      title: 'Jeepney route',
      modes: [TravelMode.walking, TravelMode.jeepney, TravelMode.walking],
      fare: '₱26',
      reason: 'Lowest estimated fare',
      source: 'Estimate only',
      time: '24 min',
    ),
    GuideModeDemoRouteOption(
      title: 'Jeepney + Train',
      modes: [
        TravelMode.walking,
        TravelMode.jeepney,
        TravelMode.train,
        TravelMode.walking,
      ],
      fare: '₱45',
      reason: 'Balanced fare and travel time',
      source: 'Live transit estimate',
      time: '38 min',
    ),
  ];

  static const routeGuideSteps = [
    GuideModeDemoRouteStep(
      number: 1,
      mode: TravelMode.walking,
      modeLabel: 'Walk',
      instruction: 'Walk to the jeepney stop',
      fare: '₱0',
      transferHint: 'Start near the main entrance',
    ),
    GuideModeDemoRouteStep(
      number: 2,
      mode: TravelMode.jeepney,
      modeLabel: 'Jeepney',
      instruction: 'Ride jeepney bound for Cubao',
      fare: '₱13',
    ),
    GuideModeDemoRouteStep(
      number: 3,
      mode: TravelMode.walking,
      modeLabel: 'Transfer',
      instruction: 'Alight near MRT station',
      fare: '₱0',
      transferHint: 'Follow station signs',
    ),
    GuideModeDemoRouteStep(
      number: 4,
      mode: TravelMode.train,
      modeLabel: 'Train',
      instruction: 'Ride train toward Taft',
      fare: '₱28',
    ),
    GuideModeDemoRouteStep(
      number: 5,
      mode: TravelMode.walking,
      modeLabel: 'Walk',
      instruction: 'Walk to destination',
      fare: '₱0',
    ),
  ];

  static const fareBreakdown = [
    GuideModeDemoFareLine(label: 'Walk', amount: '₱0'),
    GuideModeDemoFareLine(label: 'Jeepney', amount: '₱13'),
    GuideModeDemoFareLine(label: 'Train', amount: '₱28'),
    GuideModeDemoFareLine(label: 'Walk', amount: '₱0'),
    GuideModeDemoFareLine(label: 'Total', amount: '₱41', isTotal: true),
  ];

  static const plan = GuideModeDemoPlan(
    title: 'Manila Day Trip',
    stopCount: 3,
    stops: ['Intramuros', 'National Museum', 'Rizal Park'],
    estimatedBudget: '₱120',
    shared: false,
  );

  static const collaboration = GuideModeDemoCollaboration(
    planTitle: 'Shared Plan',
    participants: ['Jia', 'Friend'],
    note: 'Each person can set their own starting point.',
  );

  static const reminder = GuideModeDemoReminder(
    primary: 'Leave for Stop 1 in 1 hour',
    secondary: 'Next stop reminder in 30 minutes',
  );

  static const tripHistory = GuideModeDemoTripHistory(
    title: 'Manila Museum Loop',
    stopCount: 3,
    finishedLabel: 'Finished today',
  );

  static List<Destination> destinationsForApp() {
    return destinations
        .map(
          (destination) => Destination(
            id: 'guide-${destination.name.toLowerCase().replaceAll(' ', '-')}',
            name: destination.name,
            description: destination.description,
            location: destination.locationLabel,
            imageUrl: '',
            category: _categoryFor(destination.type),
            rating: _ratingFor(destination.ratingDisplay),
            tags: [destination.type, 'Guide Mode'],
          ),
        )
        .toList(growable: false);
  }

  static TravelPlan travelPlanForApp() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day + 1);
    final demoDestinations = destinationsForApp();
    final planStops = demoDestinations
        .where((destination) => plan.stops.contains(destination.name))
        .toList(growable: false);

    return TravelPlan(
      id: 'guide-mode-manila-day-trip',
      title: plan.title,
      startDate: start,
      endDate: start,
      participantUids: const ['guide_user'],
      createdBy: 'guide_user',
      itinerary: [
        DayItinerary(
          date: start,
          items: [
            for (var i = 0; i < planStops.length; i++)
              ItineraryItem(
                id: 'guide-stop-${i + 1}',
                destination: planStops[i],
                startTime: TimeOfDay(hour: 9 + i, minute: 0),
                endTime: TimeOfDay(hour: 10 + i, minute: 0),
                notes: 'Guide Mode preview stop',
                dayNumber: 1,
                transportOptions: const ['Walk', 'Jeepney', 'Train'],
              ),
          ],
        ),
      ],
    );
  }

  static DestinationCategory _categoryFor(String type) {
    return switch (type.toLowerCase()) {
      'park' => DestinationCategory.park,
      'museum' => DestinationCategory.museum,
      'mall' => DestinationCategory.malls,
      _ => DestinationCategory.landmark,
    };
  }

  static double _ratingFor(String display) {
    final value = double.tryParse(display.split(' ').first.trim());
    return value == null ? 0.0 : value.clamp(0.0, 5.0);
  }
}
