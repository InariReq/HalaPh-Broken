import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halaph/db/local_db.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/repositories/backend_repository.dart';

class SimplePlanService {
  static final Map<String, TravelPlan> _plans = {};
  static bool _initialized = false;
  static int _planIdCounter = 1;

  static Future<void> initialize() => _ensureInit();

  static List<TravelPlan> getUserPlans({String? ownerId}) {
    final owner = ownerId ?? 'current_user';
    return _plans.values.where((plan) => plan.createdBy == owner).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  static List<TravelPlan> getCollaborativePlans({String? ownerId}) {
    final owner = ownerId ?? 'current_user';
    return _plans.values
        .where(
          (plan) => plan.createdBy == owner && plan.participantIds.length > 1,
        )
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  static List<TravelPlan> getPlansSharedWithUser(String participantId) {
    return _plans.values
        .where(
          (plan) =>
              plan.createdBy != participantId &&
              plan.participantIds.contains(participantId),
        )
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  static Future<void> _initFromStorage() async {
    if (_initialized) return;
    await LocalDb.instance.init();
    final plans = await LocalDb.instance.loadPlans();
    _plans.clear();
    for (var p in plans) {
      _plans[p.id] = p;
    }
    _planIdCounter = _nextPlanId(_plans.keys);
    _initialized = true;
  }

  static Future<void> _persistAll() async {
    await LocalDb.instance.init();
    await LocalDb.instance.savePlans(_plans.values.toList());
  }

  static TravelPlan createPlan({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required List<Destination> destinations,
    String createdBy = 'current_user',
    String? bannerImage,
  }) {
    final id = 'plan$_planIdCounter';
    _planIdCounter++;

    final itinerary = _buildItinerary(startDate, endDate, destinations);

    final plan = TravelPlan(
      id: id,
      title: title,
      startDate: startDate,
      endDate: endDate,
      participantIds: [createdBy],
      createdBy: createdBy,
      itinerary: itinerary,
      isShared: false,
      bannerImage: bannerImage,
    );

    _plans[id] = plan;
    unawaited(_persistAll());
    // Also synchronize with the backend (fire-and-forget; backend is mocked for now)
    unawaited(BackendRepository().savePlan(plan));
    return plan;
  }

  static TravelPlan? getPlanById(String id) => _plans[id];

  static Future<void> _ensureInit() async {
    await _initFromStorage();
  }

  static bool updatePlan({
    required String planId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    List<Destination>? destinations,
    String? bannerImage,
  }) {
    final existing = _plans[planId];
    if (existing == null) return false;

    final newItinerary = destinations != null
        ? _buildItinerary(
            startDate ?? existing.startDate,
            endDate ?? existing.endDate,
            destinations,
          )
        : existing.itinerary;

    final updated = TravelPlan(
      id: existing.id,
      title: title ?? existing.title,
      startDate: startDate ?? existing.startDate,
      endDate: endDate ?? existing.endDate,
      participantIds: existing.participantIds,
      createdBy: existing.createdBy,
      itinerary: newItinerary,
      isShared: existing.isShared,
      bannerImage: bannerImage ?? existing.bannerImage,
    );

    _plans[planId] = updated;
    unawaited(_persistAll());
    unawaited(BackendRepository().savePlan(updated));
    return true;
  }

  static Future<bool> updatePlanParticipants({
    required String planId,
    required List<String> participantIds,
  }) async {
    await _ensureInit();
    final existing = _plans[planId];
    if (existing == null) return false;

    final normalized = <String>{existing.createdBy}
      ..addAll(
        participantIds
            .where((id) => id.trim().isNotEmpty)
            .map((id) => id.trim()),
      );
    final updated = TravelPlan(
      id: existing.id,
      title: existing.title,
      startDate: existing.startDate,
      endDate: existing.endDate,
      participantIds: normalized.toList(),
      createdBy: existing.createdBy,
      itinerary: existing.itinerary,
      isShared: normalized.length > 1,
      bannerImage: existing.bannerImage,
    );
    _plans[planId] = updated;
    await _persistAll();
    unawaited(BackendRepository().savePlan(updated));
    return true;
  }

  static Future<bool> deletePlan(String id) async {
    await _ensureInit();
    final existed = _plans.remove(id) != null;
    await _persistAll();
    return existed;
  }

  static List<TravelPlan> getAllPlans() => _plans.values.toList();

  static Future<TravelPlan> savePlan({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required Map<int, List<Destination>> itinerary,
    Map<String, String>? destinationTimes,
    String createdBy = 'current_user',
    List<String> participantIds = const [],
    String? bannerImage,
  }) async {
    await _ensureInit();
    final id = 'plan$_planIdCounter';
    _planIdCounter++;

    final dayItineraries = <DayItinerary>[];
    final totalDays = endDate.difference(startDate).inDays + 1;

    for (int day = 0; day < totalDays; day++) {
      final date = startDate.add(Duration(days: day));
      final dests = itinerary[day + 1] ?? [];
      if (dests.isEmpty) continue;

      final items = <ItineraryItem>[];
      for (int i = 0; i < dests.length; i++) {
        final dest = dests[i];
        final timeStr = destinationTimes?[dest.id] ?? '10:00 AM';
        final (hour, minute) = _parseTime(timeStr);

        items.add(
          ItineraryItem(
            id: '${id}_item_${day}_$i',
            destination: dest,
            startTime: TimeOfDay(hour: hour, minute: minute),
            endTime: TimeOfDay(hour: (hour + 1) % 24, minute: minute),
            dayNumber: day + 1,
            notes: 'Visit ${dest.name}',
          ),
        );
      }

      dayItineraries.add(DayItinerary(date: date, items: items));
    }

    final banner =
        bannerImage ??
        'https://picsum.photos/seed/${title.hashCode}_${startDate.millisecondsSinceEpoch}/400/200';

    final participants = <String>{createdBy}
      ..addAll(participantIds.where((id) => id.trim().isNotEmpty));

    final plan = TravelPlan(
      id: id,
      title: title,
      startDate: startDate,
      endDate: endDate,
      participantIds: participants.toList(),
      createdBy: createdBy,
      itinerary: dayItineraries,
      isShared: participants.length > 1,
      bannerImage: banner,
    );

    _plans[id] = plan;
    await _persistAll();
    unawaited(BackendRepository().savePlan(plan));
    return plan;
  }

  static void clearAllPlans() {
    _plans.clear();
    _planIdCounter = 1;
  }

  static List<DayItinerary> _buildItinerary(
    DateTime start,
    DateTime end,
    List<Destination> dests,
  ) {
    final days = end.difference(start).inDays + 1;
    final itineraries = <DayItinerary>[];

    for (int d = 0; d < days; d++) {
      final date = start.add(Duration(days: d));
      final perDay = (dests.length / days).ceil();
      final startIdx = d * perDay;
      final endIdx = (startIdx + perDay).clamp(0, dests.length);

      final items = <ItineraryItem>[];
      for (int i = startIdx; i < endIdx; i++) {
        final dest = dests[i];
        final hour = 9 + (i % 4) * 2;
        items.add(
          ItineraryItem(
            id: 'item_${DateTime.now().millisecondsSinceEpoch}_$i',
            destination: dest,
            startTime: TimeOfDay(hour: hour, minute: 0),
            endTime: TimeOfDay(hour: hour + 2, minute: 0),
            dayNumber: d + 1,
            notes: 'Visit ${dest.name}',
          ),
        );
      }

      if (items.isNotEmpty) {
        itineraries.add(DayItinerary(date: date, items: items));
      }
    }

    return itineraries;
  }

  static (int, int) _parseTime(String timeStr) {
    try {
      final cleaned = timeStr.trim().replaceAll(RegExp(r'\s+'), ' ');
      final parts = cleaned.split(' ');
      final hm = parts[0].split(':');
      var hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);

      if (parts.length > 1) {
        final period = parts[1].toUpperCase();
        if (period == 'PM' && hour != 12)
          hour += 12;
        else if (period == 'AM' && hour == 12)
          hour = 0;
      }
      return (hour, minute);
    } catch (_) {
      return (10, 0);
    }
  }

  static int _nextPlanId(Iterable<String> existingIds) {
    int maxId = 0;
    for (final id in existingIds) {
      if (id.startsWith('plan')) {
        final numeric = int.tryParse(id.substring(4));
        if (numeric != null && numeric > maxId) {
          maxId = numeric;
        }
      }
    }
    return maxId + 1;
  }
}
