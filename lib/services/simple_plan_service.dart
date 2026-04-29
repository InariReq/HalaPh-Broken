import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/remote_sync_service.dart';

class SimplePlanService {
  static final Map<String, TravelPlan> _plans = {};
  static int _planIdCounter = 1;
  static String? _loadedForUserId;
  static Future<void>? _initialization;
  static final Map<String, String> _ownerUids = {};
  static final Map<String, List<String>> _participantUids = {};
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesController.stream;

  static Future<void> initialize({bool forceRefresh = false}) async {
    if (!forceRefresh && _initialization != null) return _initialization;

    _initialization = _initialize(forceRefresh: forceRefresh);
    try {
      await _initialization;
    } finally {
      _initialization = null;
    }
  }

  static Future<void> _initialize({required bool forceRefresh}) async {
    if (!await FirebaseAppService.initialize()) {
      resetCache();
      return;
    }

    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      resetCache();
      return;
    }

    if (!forceRefresh && _loadedForUserId == userId) return;

    try {
      final remotePlans = await _loadRemotePlans().timeout(
        const Duration(seconds: 10),
      );
      _plans
        ..clear()
        ..addEntries(remotePlans.map((plan) => MapEntry(plan.id, plan)));
      _planIdCounter = _nextPlanId(remotePlans);
      _loadedForUserId = userId;
    } catch (error) {
      debugPrint('Plan load failed: $error');
      if (_loadedForUserId != userId) {
        _plans.clear();
        _planIdCounter = 1;
        _ownerUids.clear();
        _participantUids.clear();
        _loadedForUserId = userId;
      }
    }
  }

  static List<TravelPlan> getUserPlans({String? ownerId}) {
    final identities = _identityCandidates(ownerId ?? 'current_user');
    return _plans.values
        .where(
          (plan) => _isPlanOwner(plan, identities) && !_isCollaborative(plan),
        )
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  static List<TravelPlan> getCollaborativePlans({String? ownerId}) {
    final identities = _identityCandidates(ownerId ?? 'current_user');
    return _plans.values
        .where(
          (plan) =>
              _isPlanParticipant(plan, identities) && _isCollaborative(plan),
        )
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  static List<TravelPlan> getPlansSharedWithUser(String participantId) {
    final identities = _identityCandidates(participantId);
    return _plans.values
        .where(
          (plan) =>
              _isPlanParticipant(plan, identities) &&
              !_isPlanOwner(plan, identities),
        )
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  static TravelPlan? getNextUpcomingPlan({String? userId}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final identities = _identityCandidates(userId ?? 'current_user');

    final upcoming = _plans.values.where((plan) {
      final isUserPartOfPlan = _isPlanParticipant(plan, identities);
      final planDay = DateTime(
        plan.startDate.year,
        plan.startDate.month,
        plan.startDate.day,
      );
      final hasNotStarted = !planDay.isBefore(today);
      return isUserPartOfPlan && hasNotStarted;
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));

    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  static List<TravelPlan> getAllUpcomingPlans({String? userId}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final identities = _identityCandidates(userId ?? 'current_user');

    return _plans.values.where((plan) {
      final isUserPartOfPlan = _isPlanParticipant(plan, identities);
      final planDay = DateTime(
        plan.startDate.year,
        plan.startDate.month,
        plan.startDate.day,
      );
      final hasNotStarted = !planDay.isBefore(today);
      return isUserPartOfPlan && hasNotStarted;
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  static TravelPlan createPlan({
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    required List<Destination> destinations,
    String createdBy = 'current_user',
    String? bannerImage,
  }) {
    final id = _newPlanId();

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
    _notifyChanged();
    _saveRemotePlanInBackground(plan);
    return plan;
  }

  static TravelPlan? getPlanById(String id) => _plans[id];

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
    _notifyChanged();
    _saveRemotePlanInBackground(updated);
    return true;
  }

  static Future<bool> deletePlan(String id) async {
    final existing = _plans[id];
    if (existing == null) return false;

    final deleted = await _deleteRemotePlan(id);
    if (!deleted) return false;
    _plans.remove(id);
    _ownerUids.remove(id);
    _participantUids.remove(id);
    _notifyChanged();
    return true;
  }

  static List<TravelPlan> getAllPlans() => _plans.values.toList();

  static void resetCache() {
    _plans.clear();
    _planIdCounter = 1;
    _loadedForUserId = null;
    _initialization = null;
    _ownerUids.clear();
    _participantUids.clear();
  }

  static Future<bool> updatePlanParticipants({
    required String planId,
    required List<String> participantIds,
  }) async {
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
    try {
      await _saveRemotePlan(updated);
      _notifyChanged();
      return true;
    } catch (error) {
      debugPrint('Failed to update plan collaborators: $error');
      _plans[planId] = existing;
      return false;
    }
  }

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
    final id = _newPlanId();

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

    // Normalize participant IDs (include creator + selected collaborators)
    final creator = createdBy.trim().isNotEmpty
        ? createdBy.trim()
        : 'current_user';
    final participants = <String>{creator}
      ..addAll(
        participantIds
            .where((id) => id.trim().isNotEmpty)
            .map((id) => id.trim()),
      );

    final banner =
        _cleanImageUrl(bannerImage) ?? _firstDestinationImage(dayItineraries);

    final plan = TravelPlan(
      id: id,
      title: title,
      startDate: startDate,
      endDate: endDate,
      participantIds: participants.toList(),
      createdBy: creator,
      itinerary: dayItineraries,
      isShared: participants.length > 1,
      bannerImage: banner,
    );

    _plans[id] = plan;
    await _saveRemotePlan(plan);
    _notifyChanged();
    return plan;
  }

  static void clearAllPlans() {
    final ids = _plans.keys.toList();
    _plans.clear();
    _planIdCounter = 1;
    _ownerUids.clear();
    _participantUids.clear();
    _notifyChanged();
    for (final id in ids) {
      unawaited(_deleteRemotePlan(id));
    }
  }

  static Future<bool> addDestinationToPlan({
    required String planId,
    required Destination destination,
    int dayNumber = 1,
    String startTime = '10:30 AM',
  }) async {
    final existing = _plans[planId];
    if (existing == null) return false;

    final safeDay = dayNumber.clamp(1, existing.totalDays).toInt();
    final targetDate = existing.startDate.add(Duration(days: safeDay - 1));
    final (hour, minute) = _parseTime(startTime);
    final newItem = ItineraryItem(
      id: '${planId}_item_${DateTime.now().microsecondsSinceEpoch}',
      destination: destination,
      startTime: TimeOfDay(hour: hour, minute: minute),
      endTime: TimeOfDay(hour: (hour + 1) % 24, minute: minute),
      dayNumber: safeDay,
      notes: 'Visit ${destination.name}',
    );

    final itinerary = existing.itinerary
        .map((day) => DayItinerary(date: day.date, items: List.of(day.items)))
        .toList();
    final dayIndex = itinerary.indexWhere(
      (day) => _sameDate(day.date, targetDate),
    );
    if (dayIndex >= 0) {
      itinerary[dayIndex] = DayItinerary(
        date: itinerary[dayIndex].date,
        items: [...itinerary[dayIndex].items, newItem],
      );
    } else {
      itinerary.add(DayItinerary(date: targetDate, items: [newItem]));
      itinerary.sort((a, b) => a.date.compareTo(b.date));
    }

    final updated = TravelPlan(
      id: existing.id,
      title: existing.title,
      startDate: existing.startDate,
      endDate: existing.endDate,
      participantIds: existing.participantIds,
      createdBy: existing.createdBy,
      itinerary: itinerary,
      isShared: existing.isShared,
      bannerImage: existing.bannerImage,
    );

    _plans[planId] = updated;
    await _saveRemotePlan(updated);
    _notifyChanged();
    return true;
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
        if (period == 'PM' && hour != 12) {
          hour += 12;
        } else if (period == 'AM' && hour == 12) {
          hour = 0;
        }
      }
      return (hour, minute);
    } catch (_) {
      return (10, 0);
    }
  }

  static Future<List<TravelPlan>> _loadRemotePlans() async {
    final userId = _currentUserId();
    if (userId == null) return [];

    final snapshot = await _plansCollection
        .where('participantUids', arrayContains: userId)
        .get()
        .timeout(const Duration(seconds: 8));

    _ownerUids.clear();
    _participantUids.clear();

    final plans = <TravelPlan>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final plan = TravelPlan.fromJson(Map<String, dynamic>.from(data));
      plans.add(plan);
      _ownerUids[plan.id] = data['ownerUid'] as String? ?? userId;
      _participantUids[plan.id] = data['participantUids'] is List
          ? List<String>.from(data['participantUids'] as List)
          : <String>[userId];
    }
    final knownIds = plans.map((plan) => plan.id).toSet();
    unawaited(_migrateLegacyPlans(knownIds));
    return plans;
  }

  static Future<void> _migrateLegacyPlans(Set<String> knownIds) async {
    try {
      final legacyPlans = await _loadLegacyPlans().timeout(
        const Duration(seconds: 3),
      );
      for (final plan in legacyPlans) {
        if (knownIds.contains(plan.id)) continue;
        knownIds.add(plan.id);
        _saveRemotePlanInBackground(plan);
      }
    } catch (error) {
      debugPrint('Legacy plan migration skipped: $error');
    }
  }

  static Future<List<TravelPlan>> _loadLegacyPlans() async {
    final payload = await RemoteSyncService.instance.loadNamespace('plans');
    final rawPlans = payload?['plans'];
    if (rawPlans is! List) return const <TravelPlan>[];
    return rawPlans
        .whereType<Map>()
        .map((entry) => TravelPlan.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  static Future<void> _saveRemotePlan(TravelPlan plan) async {
    final currentUid = _currentUserId();
    if (currentUid == null) return;

    final existingOwnerUid = _ownerUids[plan.id];
    final ownerUid = existingOwnerUid ?? currentUid;
    var resolvedParticipantUids = await _resolveRemoteParticipants(
      plan: plan,
      ownerUid: ownerUid,
      currentUid: currentUid,
    );

    if (currentUid != ownerUid) {
      resolvedParticipantUids = {
        ...(_participantUids[plan.id] ?? <String>[ownerUid]),
        currentUid,
      }.toList();
    } else if (!resolvedParticipantUids.contains(ownerUid)) {
      resolvedParticipantUids = [...resolvedParticipantUids, ownerUid];
    }

    final data = plan.toJson()
      ..addAll({
        'ownerUid': ownerUid,
        'participantUids': resolvedParticipantUids,
        'participantCodes': plan.participantIds.map(_normalizeCode).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

    await _plansCollection
        .doc(plan.id)
        .set(data)
        .timeout(const Duration(seconds: 8));
    _ownerUids[plan.id] = ownerUid;
    _participantUids[plan.id] = resolvedParticipantUids;
  }

  static void _saveRemotePlanInBackground(TravelPlan plan) {
    unawaited(
      _saveRemotePlan(plan).catchError((Object error) {
        debugPrint('Background plan sync failed: $error');
      }),
    );
  }

  static Future<List<String>> _resolveRemoteParticipants({
    required TravelPlan plan,
    required String ownerUid,
    required String currentUid,
  }) async {
    if (currentUid != ownerUid) {
      return {
        ...(_participantUids[plan.id] ?? <String>[ownerUid]),
        currentUid,
      }.toList();
    }

    final participantCodes = plan.participantIds
        .map(_normalizeCode)
        .where((code) => code.isNotEmpty)
        .toSet();
    final creatorCode = _normalizeCode(plan.createdBy);
    final collaboratorCodes = participantCodes
        .where((code) => code != creatorCode)
        .toList();

    if (collaboratorCodes.isEmpty) {
      return <String>[ownerUid];
    }

    final resolved = await FriendService()
        .resolveParticipantUids(participantCodes)
        .timeout(const Duration(seconds: 6));
    if (resolved.length < collaboratorCodes.length + 1) {
      throw Exception(
        'Could not resolve every selected friend. Add them by friend code first.',
      );
    }
    return resolved;
  }

  static Future<bool> _deleteRemotePlan(String id) async {
    try {
      await _plansCollection
          .doc(id)
          .delete()
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    }
  }

  static String shareLink(String planId) =>
      'https://halaph.app/plan-details?planId=${Uri.encodeComponent(planId)}';

  static int _nextPlanId(List<TravelPlan> plans) {
    var highest = 0;
    for (final plan in plans) {
      final match = RegExp(r'^plan(\d+)$').firstMatch(plan.id);
      if (match == null) continue;
      final number = int.tryParse(match.group(1) ?? '');
      if (number != null && number > highest) highest = number;
    }
    return highest + 1;
  }

  static bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static void _notifyChanged() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  static Set<String> _identityCandidates(String? primaryId) {
    final identities = <String>{};
    void add(String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) identities.add(trimmed);
    }

    add(primaryId);
    add(_currentUserId());
    return identities;
  }

  static bool _isPlanOwner(TravelPlan plan, Set<String> identities) {
    return _matchesAnyIdentity(plan.createdBy, identities) ||
        _matchesAnyIdentity(_ownerUids[plan.id], identities);
  }

  static bool _isPlanParticipant(TravelPlan plan, Set<String> identities) {
    if (_isPlanOwner(plan, identities)) return true;
    if (plan.participantIds.any((id) => _matchesAnyIdentity(id, identities))) {
      return true;
    }

    final remoteParticipants = _participantUids[plan.id] ?? const <String>[];
    return remoteParticipants.any((id) => _matchesAnyIdentity(id, identities));
  }

  static bool _isCollaborative(TravelPlan plan) {
    final participantCodes = plan.participantIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final remoteParticipants = (_participantUids[plan.id] ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    return plan.isShared ||
        participantCodes.length > 1 ||
        remoteParticipants.length > 1;
  }

  static bool _matchesAnyIdentity(String? value, Set<String> identities) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return false;

    for (final identity in identities) {
      if (_sameIdentity(trimmed, identity)) return true;
    }
    return false;
  }

  static bool _sameIdentity(String left, String right) {
    final leftTrimmed = left.trim();
    final rightTrimmed = right.trim();
    if (leftTrimmed == rightTrimmed) return true;

    if (_isNormalizableParticipantId(leftTrimmed) &&
        _isNormalizableParticipantId(rightTrimmed)) {
      return _normalizeCode(leftTrimmed) == _normalizeCode(rightTrimmed);
    }

    return false;
  }

  static bool _isNormalizableParticipantId(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final lower = value.trim().toLowerCase();
    return RegExp(r'^[A-Za-z]{2}[0-9]{4}$').hasMatch(compact) ||
        lower == 'current_user' ||
        lower == 'demo_user';
  }

  static CollectionReference<Map<String, dynamic>> get _plansCollection =>
      FirebaseFirestore.instance.collection('sharedPlans');

  static String? _currentUserId() {
    if (!FirebaseAppService.isInitialized) return null;
    return firebase_auth.FirebaseAuth.instance.currentUser?.uid;
  }

  static String _newPlanId() {
    final id = 'plan_${DateTime.now().microsecondsSinceEpoch}_$_planIdCounter';
    _planIdCounter++;
    return id;
  }

  static String _normalizeCode(String code) {
    final compact = code.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (RegExp(r'^[A-Z]{2}[0-9]{4}$').hasMatch(compact)) {
      return '${compact.substring(0, 2)}-${compact.substring(2)}';
    }
    return code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  static String? _firstDestinationImage(List<DayItinerary> itinerary) {
    for (final day in itinerary) {
      for (final item in day.items) {
        final imageUrl = _cleanImageUrl(item.destination.imageUrl);
        if (imageUrl != null) return imageUrl;
      }
    }
    return null;
  }

  static String? _cleanImageUrl(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return null;
    if (_isRandomImageUrl(url)) return null;
    return url;
  }

  static bool _isRandomImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('picsum.photos') ||
        lower.contains('source.unsplash.com') ||
        lower.contains('randomuser.me');
  }
}
