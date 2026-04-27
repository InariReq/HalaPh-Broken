import 'package:halaph/db/local_db.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/remote_sync_service.dart';

class FavoritesService {
  // ignore: unused_field
  static const _key = 'favorite_destinations';
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  Future<List<String>> getFavorites() async {
    final localIds = await LocalDb.instance.loadFavorites();
    final payload = await RemoteSyncService.instance.loadNamespace('favorites');
    final remoteIds = payload?['ids'] is List
        ? List<String>.from(payload!['ids'])
        : const <String>[];
    if (remoteIds.isEmpty) return localIds;
    final merged = <String>{...localIds, ...remoteIds}.toList();
    await LocalDb.instance.saveFavorites(merged);
    return merged;
  }

  Future<void> setFavorites(List<String> ids) async {
    final deduped = <String>{...ids}.toList();
    await LocalDb.instance.saveFavorites(deduped);
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
}
