import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:halaph/screens/route_options_screen.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/services/guide_mode_demo_state.dart';
import 'package:halaph/widgets/motion_widgets.dart';

class FavoritesScreen extends StatefulWidget {
  final bool guideModeDemo;

  const FavoritesScreen({
    super.key,
    this.guideModeDemo = false,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with WidgetsBindingObserver {
  static const Color _background = Color(0xFF0B1120);
  static const Color _primary = Color(0xFF2196F3);
  static const Color _primaryDark = Color(0xFF1976D2);
  static const Color _danger = Color(0xFFE53935);
  static const Duration _loadTimeout = Duration(seconds: 8);
  static const Duration _removeTimeout = Duration(seconds: 8);

  final _favoritesService = FavoritesService();
  List<Destination> _favorites = [];
  final Set<String> _busyFavoriteIds = {};
  bool _loading = true;
  int _loadRequestId = 0;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.guideModeDemo) {
      GuideModeDemoState.version.addListener(_applyGuideModeDemo);
      _applyGuideModeDemo();
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _loadFavorites();
    _subscription = FavoritesNotifier().onFavoritesChanged.listen((_) {
      _loadFavorites(showLoading: false);
    });
  }

  @override
  void didUpdateWidget(covariant FavoritesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guideModeDemo == widget.guideModeDemo) return;

    if (widget.guideModeDemo) {
      WidgetsBinding.instance.removeObserver(this);
      _subscription?.cancel();
      GuideModeDemoState.version.addListener(_applyGuideModeDemo);
      _applyGuideModeDemo();
      return;
    }

    GuideModeDemoState.version.removeListener(_applyGuideModeDemo);
    WidgetsBinding.instance.addObserver(this);
    _loadFavorites();
    _subscription = FavoritesNotifier().onFavoritesChanged.listen((_) {
      _loadFavorites(showLoading: false);
    });
  }

  void _applyGuideModeDemo() {
    if (!mounted) return;
    setState(() {
      _favorites = GuideModeDemoState.favoriteDestinations();
      _busyFavoriteIds.clear();
      _loading = false;
      _loadRequestId++;
    });
  }

  @override
  void dispose() {
    GuideModeDemoState.version.removeListener(_applyGuideModeDemo);
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.guideModeDemo) return;
    if (state == AppLifecycleState.resumed) {
      _loadFavorites(showLoading: _favorites.isEmpty);
    }
  }

  Future<void> _loadFavorites({bool showLoading = true}) async {
    if (widget.guideModeDemo) {
      _applyGuideModeDemo();
      return;
    }
    if (!mounted) return;

    final requestId = ++_loadRequestId;
    final shouldShowLoading =
        showLoading && _favorites.isEmpty && _busyFavoriteIds.isEmpty;
    if (shouldShowLoading) {
      setState(() => _loading = true);
    }

    try {
      final destinations = await _favoritesService
          .getFavoriteDestinations(
            forceRefresh: true,
          )
          .timeout(_loadTimeout);
      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _favorites = destinations
            .where((destination) => !_busyFavoriteIds.contains(destination.id))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() => _loading = false);
    }
  }

  Future<bool> _removeFavorite(String id) async {
    if (widget.guideModeDemo) return false;
    if (_busyFavoriteIds.contains(id)) return false;

    final index = _favorites.indexWhere((item) => item.id == id);
    if (index == -1) return false;
    final removed = _favorites[index];
    final messenger = ScaffoldMessenger.of(context);

    _loadRequestId++;

    setState(() {
      _busyFavoriteIds.add(id);
      _favorites.removeAt(index);
      _loading = false;
    });

    var removedSuccessfully = false;
    try {
      removedSuccessfully =
          await _favoritesService.removeFavorite(id).timeout(_removeTimeout);
    } catch (_) {
      removedSuccessfully = false;
    }

    if (!mounted) return false;

    setState(() {
      _busyFavoriteIds.remove(id);
      _loading = false;
      if (!removedSuccessfully &&
          !_favorites.any((item) => item.id == removed.id)) {
        _favorites.insert(index.clamp(0, _favorites.length), removed);
      }
    });

    if (!removedSuccessfully) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not remove favorite. Please try again.'),
        ),
      );
    }
    return removedSuccessfully;
  }

  void refresh() {
    if (widget.guideModeDemo) return;
    _loadFavorites(showLoading: _favorites.isEmpty);
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
            onPressed: widget.guideModeDemo
                ? null
                : () => _loadFavorites(showLoading: _favorites.isEmpty),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const _FavoritesLoading()
            : RefreshIndicator(
                onRefresh: () => _loadFavorites(showLoading: false),
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
                              isDemo: widget.guideModeDemo,
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
    return const LoadingStatePanel(label: 'Loading favorites');
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
                'Saved places',
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
      message:
          'Guide Mode will place Intramuros here after you tap Save destination.',
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Destination destination;
  final bool isBusy;
  final bool isDemo;
  final VoidCallback onOpen;
  final VoidCallback onRoutes;
  final Future<bool> Function() onRemove;

  const _FavoriteCard({
    required this.destination,
    required this.isBusy,
    this.isDemo = false,
    required this.onOpen,
    required this.onRoutes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(destination.id),
      direction: isBusy || isDemo
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (isBusy) return false;
        await onRemove();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _FavoritesScreenState._danger,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isBusy || isDemo ? null : onOpen,
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
                      onPressed: isBusy || isDemo ? null : onRoutes,
                    ),
                    IconButton(
                      icon: Icon(Icons.favorite_rounded),
                      color: _FavoritesScreenState._danger,
                      tooltip: 'Remove favorite',
                      onPressed: isBusy || isDemo ? null : () => onRemove(),
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
