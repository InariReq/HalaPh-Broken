import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/remote_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  // ignore: unused_field
  static const _key = 'favorite_destinations';
  static const _localIdsKeyPrefix = 'favorite_destinations_ids';
  static const _localPlacesKeyPrefix = 'favorite_destinations_places';
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  String? _cachedUserId;
  List<String>? _cachedIds;
  Map<String, Destination>? _cachedDestinations;

  Future<List<String>> getFavorites({bool forceRefresh = false}) async {
    final userId = await _currentUserId();
    final cacheScope = _cacheScope(userId);

    if (!forceRefresh && _cachedUserId == cacheScope && _cachedIds != null) {
      return List<String>.from(_cachedIds!);
    }

    if (userId == null) {
      return _loadLocalFavorites(scope: _localScope(null));
    }

    final payload = await RemoteSyncService.instance.loadNamespace('favorites');
    if (payload == null) {
      return _loadLocalFavorites(scope: _localScope(userId));
    }

    final ids = payload['ids'] is List
        ? List<String>.from(payload['ids'])
        : const <String>[];
    _cachedUserId = cacheScope;
    _cachedIds = <String>{...ids}.toList();
    _cachedDestinations = _parseDestinations(payload['places']);
    unawaited(
      _saveLocalFavorites(
        _cachedIds!,
        destinations: _cachedDestinations,
        scope: _localScope(userId),
      ),
    );
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
    final cacheScope = _cacheScope(userId);
    final deduped = <String>{...ids}.toList();
    final sourceDestinations = destinations ?? _cachedDestinations ?? {};
    final savedDestinations = <String, Destination>{
      for (final id in deduped)
        if (sourceDestinations[id] != null) id: sourceDestinations[id]!,
    };

    _cachedUserId = cacheScope;
    _cachedIds = deduped;
    _cachedDestinations = savedDestinations;

    if (userId == null) {
      await _saveLocalFavorites(
        deduped,
        destinations: savedDestinations,
        scope: _localScope(null),
      );
      return;
    }

    final savedRemotely = await RemoteSyncService.instance.saveNamespace(
      'favorites',
      {
        'ids': deduped,
        'places': savedDestinations.values
            .map((destination) => destination.toJson())
            .toList(),
      },
    );

    await _saveLocalFavorites(
      deduped,
      destinations: savedDestinations,
      scope: _localScope(userId),
    );

    if (savedRemotely) {
      await FriendService().publishFavoritePlaces(_orderedCachedDestinations());
    }
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

  Future<List<String>> _loadLocalFavorites({required String scope}) async {
    List<String> ids = const <String>[];
    String? placesJson;

    try {
      final localStore = SharedPreferencesAsync();
      ids = await localStore.getStringList(_localIdsKey(scope)) ??
          const <String>[];
      placesJson = await localStore.getString(_localPlacesKey(scope));
    } catch (_) {
      // SharedPreferences is unavailable in some test environments.
    }

    _cachedUserId = _cacheScopeForLocal(scope);
    _cachedIds = <String>{...ids}.toList();
    _cachedDestinations = _parseLocalDestinations(placesJson);
    return List<String>.from(_cachedIds!);
  }

  Future<void> _saveLocalFavorites(
    List<String> ids, {
    required Map<String, Destination>? destinations,
    required String scope,
  }) async {
    final deduped = <String>{...ids}.toList();
    final places = (destinations ?? const <String, Destination>{})
        .values
        .map((destination) => destination.toJson())
        .toList();

    try {
      final localStore = SharedPreferencesAsync();
      await localStore.setStringList(_localIdsKey(scope), deduped);
      await localStore.setString(_localPlacesKey(scope), jsonEncode(places));
    } catch (_) {
      // SharedPreferences is unavailable in some test environments.
    }
  }

  Map<String, Destination> _parseLocalDestinations(String? placesJson) {
    if (placesJson == null || placesJson.isEmpty) {
      return <String, Destination>{};
    }

    try {
      final decoded = jsonDecode(placesJson);
      return _parseDestinations(decoded);
    } catch (_) {
      return <String, Destination>{};
    }
  }

  String _cacheScope(String? userId) {
    return userId == null
        ? _cacheScopeForLocal(_localScope(null))
        : 'remote:$userId';
  }

  String _cacheScopeForLocal(String scope) {
    return 'local:$scope';
  }

  String _localScope(String? userId) {
    return userId == null ? 'guest' : 'user_$userId';
  }

  String _localIdsKey(String scope) {
    return '${_localIdsKeyPrefix}_$scope';
  }

  String _localPlacesKey(String scope) {
    return '${_localPlacesKeyPrefix}_$scope';
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
