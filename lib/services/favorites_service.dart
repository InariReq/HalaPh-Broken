import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/remote_sync_service.dart';

class FavoritesService {
  // ignore: unused_field
  static const _key = 'favorite_destinations';
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  String? _cachedUserId;
  List<String>? _cachedIds;
  Map<String, Destination>? _cachedDestinations;

  Future<List<String>> getFavorites({bool forceRefresh = false}) async {
    final userId = await _currentUserId();
    if (userId == null) return const <String>[];

    if (!forceRefresh && _cachedUserId == userId && _cachedIds != null) {
      return List<String>.from(_cachedIds!);
    }

    final payload = await RemoteSyncService.instance.loadNamespace('favorites');
    final ids = payload?['ids'] is List
        ? List<String>.from(payload!['ids'])
        : const <String>[];
    _cachedUserId = userId;
    _cachedIds = <String>{...ids}.toList();
    _cachedDestinations = _parseDestinations(payload?['places']);
    unawaited(
      FriendService()
          .publishFavoritePlaces(_orderedCachedDestinations())
          .catchError((_) {}),
    );
    return List<String>.from(_cachedIds!);
  }

  Future<List<Destination>> getFavoriteDestinations({
    bool forceRefresh = false,
  }) async {
    final ids = await getFavorites(forceRefresh: forceRefresh);
    final byId = _cachedDestinations ?? const <String, Destination>{};
    return ids
        .map((id) => byId[id])
        .whereType<Destination>()
        .toList(growable: false);
  }

  Future<void> setFavorites(
    List<String> ids, {
    Map<String, Destination>? destinations,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    final deduped = <String>{...ids}.toList();
    final sourceDestinations = destinations ?? _cachedDestinations ?? {};
    final savedDestinations = <String, Destination>{
      for (final id in deduped)
        if (sourceDestinations[id] != null) id: sourceDestinations[id]!,
    };
    _cachedUserId = userId;
    _cachedIds = deduped;
    _cachedDestinations = savedDestinations;
    await RemoteSyncService.instance.saveNamespace('favorites', {
      'ids': deduped,
      'places': savedDestinations.values
          .map((destination) => destination.toJson())
          .toList(),
    });
    await FriendService().publishFavoritePlaces(_orderedCachedDestinations());
  }

  Future<void> toggleFavorite(String id) async {
    final ids = await getFavorites();
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    await setFavorites(ids);
    FavoritesNotifier().notifyFavoritesChanged();
  }

  Future<void> toggleFavoriteDestination(Destination destination) async {
    final ids = await getFavorites();
    final destinations = Map<String, Destination>.from(
      _cachedDestinations ?? const <String, Destination>{},
    );
    if (ids.contains(destination.id)) {
      ids.remove(destination.id);
      destinations.remove(destination.id);
    } else {
      ids.add(destination.id);
      destinations[destination.id] = destination;
    }
    await setFavorites(ids, destinations: destinations);
    FavoritesNotifier().notifyFavoritesChanged();
  }

  Future<bool> isFavorite(String id) async {
    final ids = await getFavorites();
    return ids.contains(id);
  }

  void clearCache() {
    _cachedUserId = null;
    _cachedIds = null;
    _cachedDestinations = null;
  }

  Future<String?> _currentUserId() async {
    if (!await FirebaseAppService.initialize()) return null;
    return firebase_auth.FirebaseAuth.instance.currentUser?.uid;
  }

  List<Destination> _orderedCachedDestinations() {
    final ids = _cachedIds ?? const <String>[];
    final byId = _cachedDestinations ?? const <String, Destination>{};
    return ids
        .map((id) => byId[id])
        .whereType<Destination>()
        .toList(growable: false);
  }

  Map<String, Destination> _parseDestinations(Object? rawPlaces) {
    if (rawPlaces is! List) return <String, Destination>{};
    final places = <String, Destination>{};
    for (final rawPlace in rawPlaces) {
      if (rawPlace is! Map) continue;
      try {
        final destination = Destination.fromJson(
          Map<String, dynamic>.from(rawPlace),
        );
        places[destination.id] = destination;
      } catch (_) {}
    }
    return places;
  }
}
