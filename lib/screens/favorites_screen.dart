import 'dart:async';
import 'package:flutter/material.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:halaph/screens/route_options_screen.dart';
import 'package:halaph/utils/navigation_utils.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with WidgetsBindingObserver {
  final _favoritesService = FavoritesService();
  List<Destination> _favorites = [];
  bool _loading = true;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFavorites();
    _subscription = FavoritesNotifier().onFavoritesChanged.listen((_) {
      _loadFavorites();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    try {
      final destinations = await _favoritesService.getFavoriteDestinations(
        forceRefresh: true,
      );
      if (mounted) {
        setState(() {
          _favorites = destinations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeFavorite(String id) async {
    await _favoritesService.toggleFavorite(id);
    _loadFavorites();
  }

  void refresh() {
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => safeNavigateBack(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart icon on places to add them here',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final d = _favorites[index];
                return Dismissible(
                  key: Key(d.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _removeFavorite(d.id),
                  child: ListTile(
                    onTap: () => ExploreDetailsScreen.showAsBottomSheet(
                      context,
                      destinationId: d.id,
                      source: 'favorites',
                      destination: d,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          d.imageUrl.isNotEmpty && d.imageUrl.startsWith('http')
                          ? Image.network(
                              d.imageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.place,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    title: Text(d.name),
                    subtitle: Text(d.location),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.directions),
                          tooltip: 'View routes',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RouteOptionsScreen(
                                  destinationId: d.id,
                                  destinationName: d.name,
                                  source: 'favorites',
                                  destination: d,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          tooltip: 'Remove favorite',
                          onPressed: () => _removeFavorite(d.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
