import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:halaph/services/firebase_app_service.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/remote_sync_service.dart';

class FavoritesService {
  // ignore: unused_field
  static const _key = 'favorite_destinations';
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  String? _cachedUserId;
  List<String>? _cachedIds;

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
    return List<String>.from(_cachedIds!);
  }

  Future<void> setFavorites(List<String> ids) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    final deduped = <String>{...ids}.toList();
    _cachedUserId = userId;
    _cachedIds = deduped;
    await RemoteSyncService.instance.saveNamespace('favorites', {
      'ids': deduped,
    });
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

  Future<bool> isFavorite(String id) async {
    final ids = await getFavorites();
    return ids.contains(id);
  }

  void clearCache() {
    _cachedUserId = null;
    _cachedIds = null;
  }

  Future<String?> _currentUserId() async {
    if (!await FirebaseAppService.initialize()) return null;
    return firebase_auth.FirebaseAuth.instance.currentUser?.uid;
  }
}
