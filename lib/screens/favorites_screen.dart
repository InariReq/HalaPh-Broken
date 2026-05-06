import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:halaph/screens/route_options_screen.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/utils/navigation_utils.dart';

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
  static const Color _textPrimary = Color(0xFF1F2933);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE8E8E8);
  static const Color _danger = Color(0xFFE53935);

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
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeFavorite(String id) async {
    await _favoritesService.toggleFavorite(id);
    if (!mounted) return;
    await _loadFavorites();
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
            color: _textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: _textPrimary),
                onPressed: () => safeNavigateBack(context),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _textPrimary),
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
                          _EmptyFavoritesCard(),
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

                          return _FavoriteCard(
                            destination: destination,
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
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

class _FavoritesLoading extends StatelessWidget {
  const _FavoritesLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
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
                  color: _FavoritesScreenState._textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your favorite destinations are saved here.',
                style: TextStyle(
                  fontSize: 13,
                  color: _FavoritesScreenState._textSecondary,
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
            border: Border.all(color: const Color(0xFFBBDEFB)),
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(shadow: false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 58,
            color: _FavoritesScreenState._textSecondary,
          ),
          SizedBox(height: 14),
          Text(
            'No favorites yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _FavoritesScreenState._textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap the heart icon on places to save them here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _FavoritesScreenState._textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Destination destination;
  final VoidCallback onOpen;
  final VoidCallback onRoutes;
  final VoidCallback onRemove;

  const _FavoriteCard({
    required this.destination,
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
          onTap: onOpen,
          child: Container(
            decoration: _cardDecoration(),
            child: Row(
              children: [
                _buildImage(),
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
                            color: _FavoritesScreenState._textPrimary,
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
                            color: _FavoritesScreenState._textSecondary,
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
                      onPressed: onRoutes,
                    ),
                    IconButton(
                      icon: Icon(Icons.favorite_rounded),
                      color: _FavoritesScreenState._danger,
                      tooltip: 'Remove favorite',
                      onPressed: onRemove,
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

  Widget _buildImage() {
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
              errorBuilder: (context, error, stackTrace) => _imageFallback(),
            )
          : _imageFallback(),
    );
  }

  Widget _imageFallback() {
    return Container(
      width: 82,
      height: 92,
      color: const Color(0xFF172033),
      child: Icon(
        Icons.place_rounded,
        color: _FavoritesScreenState._primary,
        size: 32,
      ),
    );
  }
}

BoxDecoration _cardDecoration({bool shadow = true}) {
  return BoxDecoration(
    color: const Color(0xFF111827),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _FavoritesScreenState._border),
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
