import 'package:halaph/db/local_db.dart';
import 'package:halaph/services/favorites_notifier.dart';

class FavoritesService {
  static const _key = 'favorite_destinations';
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();
  
  Future<List<String>> getFavorites() async {
    final ids = await LocalDb.instance.loadFavorites();
    return ids;
  }

  Future<void> setFavorites(List<String> ids) async {
    await LocalDb.instance.saveFavorites(ids);
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
