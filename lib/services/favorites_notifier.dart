import 'dart:async';

class FavoritesNotifier {
  static final FavoritesNotifier _instance = FavoritesNotifier._internal();
  factory FavoritesNotifier() => _instance;
  FavoritesNotifier._internal();
  
  final _controller = StreamController<void>.broadcast();
  
  Stream<void> get onFavoritesChanged => _controller.stream;
  
  void notifyFavoritesChanged() {
    _controller.add(null);
  }
  
  void dispose() {
    _controller.close();
  }
}