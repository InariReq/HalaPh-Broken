import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:halaph/screens/route_options_screen.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/widgets/motion_widgets.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with WidgetsBindingObserver {
  static const Color _background = Color(0xFF0B1120);
  static const Color _primary = Color(0xFF2196F3);
  static const Color _primaryDark = Color(0xFF1976D2);
  static const Color _danger = Color(0xFFE53935);

  final _favoritesService = FavoritesService();
  List<Destination> _favorites = [];
  final Set<String> _busyFavoriteIds = {};
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
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeFavorite(String id) async {
    if (_busyFavoriteIds.contains(id)) return;

    final index = _favorites.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final removed = _favorites[index];

    setState(() {
      _busyFavoriteIds.add(id);
      _favorites.removeAt(index);
    });

    try {
      await _favoritesService.toggleFavorite(id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _favorites.insert(index.clamp(0, _favorites.length), removed);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyFavoriteIds.remove(id);
        });
        _loadFavorites();
      }
    }
  }

  void refresh() {
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: _background,
        elevation: 0,
        title: Text(
          'Favorites',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Refresh favorites',
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const _FavoritesLoading()
            : RefreshIndicator(
                onRefresh: _loadFavorites,
                child: _favorites.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
                        children: [
                          _FavoritesEntrance(
                            order: 0,
                            child: _EmptyFavoritesCard(),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                        itemCount: _favorites.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _SectionHeader(count: _favorites.length);
                          }

                          final destination = _favorites[index - 1];
                          final isBusy =
                              _busyFavoriteIds.contains(destination.id);

                          return _FavoritesEntrance(
                            order: index - 1,
                            child: _FavoriteCard(
                              destination: destination,
                              isBusy: isBusy,
                              onOpen: () =>
                                  ExploreDetailsScreen.showAsBottomSheet(
                                context,
                                destinationId: destination.id,
                                source: 'favorites',
                                destination: destination,
                              ),
                              onRoutes: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RouteOptionsScreen(
                                      destinationId: destination.id,
                                      destinationName: destination.name,
                                      source: 'favorites',
                                      destination: destination,
                                    ),
                                  ),
                                );
                              },
                              onRemove: () => _removeFavorite(destination.id),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

class _FavoritesEntrance extends StatelessWidget {
  final int order;
  final Widget child;

  const _FavoritesEntrance({
    required this.order,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (order.clamp(0, 5) * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _FavoritesLoading extends StatelessWidget {
  const _FavoritesLoading();

  @override
  Widget build(BuildContext context) {
    return const LoadingStatePanel(label: 'Loading favorites...');
  }
}

class _SectionHeader extends StatelessWidget {
  final int count;

  const _SectionHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saved Places',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your favorite destinations are saved here.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF172033),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.28),
            ),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: _FavoritesScreenState._primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFavoritesCard extends StatelessWidget {
  const _EmptyFavoritesCard();

  @override
  Widget build(BuildContext context) {
    return const EmptyStatePanel(
      icon: Icons.favorite_border_rounded,
      title: 'No favorites yet',
      message: 'Tap the heart icon on places to save them here.',
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Destination destination;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onRoutes;
  final VoidCallback onRemove;

  const _FavoriteCard({
    required this.destination,
    required this.isBusy,
    required this.onOpen,
    required this.onRoutes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(destination.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _FavoritesScreenState._danger,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isBusy ? null : onOpen,
          child: Container(
            decoration: _cardDecoration(context),
            child: Row(
              children: [
                _buildImage(context),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          destination.location.isEmpty
                              ? 'Saved destination'
                              : destination.location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.directions_rounded),
                      color: _FavoritesScreenState._primaryDark,
                      tooltip: 'View routes',
                      onPressed: isBusy ? null : onRoutes,
                    ),
                    IconButton(
                      icon: Icon(Icons.favorite_rounded),
                      color: _FavoritesScreenState._danger,
                      tooltip: 'Remove favorite',
                      onPressed: isBusy ? null : onRemove,
                    ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final imageUrl = destination.imageUrl.trim();
    final hasNetworkImage = imageUrl.isNotEmpty && imageUrl.startsWith('http');

    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
      child: hasNetworkImage
          ? Image.network(
              imageUrl,
              width: 82,
              height: 92,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _imageFallback(context),
            )
          : _imageFallback(context),
    );
  }

  Widget _imageFallback(BuildContext context) {
    return Container(
      width: 82,
      height: 92,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.place_rounded,
        color: _FavoritesScreenState._primary,
        size: 32,
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context, {bool shadow = true}) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.28),
    ),
    boxShadow: shadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ]
        : null,
  );
}
