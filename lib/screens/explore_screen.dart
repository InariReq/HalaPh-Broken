import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<Destination> _destinations = [];
  bool _isLoading = false;
  final Set<String> _favoriteIds = {};
  final FavoritesService _favoritesService = FavoritesService();
  StreamSubscription? _subscription;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  final TextEditingController _searchController = TextEditingController();
  DestinationCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
    _loadFavorites();
    _subscription = FavoritesNotifier().onFavoritesChanged.listen((_) {
      _loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final ids = await _favoritesService.getFavorites();
      if (mounted) {
        setState(() {
          _favoriteIds.clear();
          _favoriteIds.addAll(ids);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite(Destination destination) async {
    final id = destination.id;
    try {
      await _favoritesService.toggleFavoriteDestination(destination);
      if (!mounted) return;
      setState(() {
        if (_favoriteIds.contains(id)) {
          _favoriteIds.remove(id);
        } else {
          _favoriteIds.add(id);
        }
      });
    } catch (_) {}
  }

  final List<DestinationCategory> _categories = [
    DestinationCategory.park,
    DestinationCategory.landmark,
    DestinationCategory.food,
    DestinationCategory.activities,
    DestinationCategory.museum,
    DestinationCategory.malls,
  ];

  Future<void> _loadDestinations() async {
    await _runDestinationSearch();
  }

  Future<void> _searchDestinations() async {
    await _runDestinationSearch();
  }

  void _queueSearchDestinations() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _searchDestinations,
    );
  }

  Future<void> _runDestinationSearch() async {
    final generation = ++_searchGeneration;
    final query = _searchController.text.trim();

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (query.isEmpty) {
        final location = await DestinationService.getCurrentLocation();
        final destinations = await DestinationService.getTrendingDestinations();
        final deduped =
            DestinationService.deduplicateDestinationsById(destinations);
        final nearbyTrending = _prioritizedNearbyTrendingPlaces(
          deduped,
          location,
          radiusKm: 5,
          limit: 5,
        );

        if (!mounted || generation != _searchGeneration) return;

        setState(() {
          _selectedCategory = null;
          _destinations = nearbyTrending;
        });
      } else {
        final destinations = await DestinationService.searchDestinations(query);
        final deduped =
            DestinationService.deduplicateDestinationsById(destinations);

        if (!mounted || generation != _searchGeneration) return;

        setState(() {
          _selectedCategory = null;
          _destinations = deduped;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _distanceKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(b.latitude - a.latitude);
    final dLon = _degreesToRadians(b.longitude - a.longitude);
    final lat1 = _degreesToRadians(a.latitude);
    final lat2 = _degreesToRadians(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return earthRadiusKm * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  List<Destination> _nearbyPlacesForCategory(
    List<Destination> destinations,
    LatLng location,
    DestinationCategory category, {
    required double radiusKm,
    required int limit,
  }) {
    final nearby = destinations.where((destination) {
      if (destination.category != category) return false;

      final coordinates = destination.coordinates;
      if (coordinates == null) return true;

      return _distanceKm(location, coordinates) <= radiusKm;
    }).toList()
      ..sort((a, b) {
        final aDistance = a.coordinates == null
            ? double.infinity
            : _distanceKm(location, a.coordinates!);
        final bDistance = b.coordinates == null
            ? double.infinity
            : _distanceKm(location, b.coordinates!);
        final distanceCompare = aDistance.compareTo(bDistance);
        if (distanceCompare != 0) return distanceCompare;

        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;

        return a.name.compareTo(b.name);
      });

    return nearby.take(limit).toList();
  }

  List<Destination> _prioritizedNearbyTrendingPlaces(
    List<Destination> destinations,
    LatLng location, {
    required double radiusKm,
    required int limit,
  }) {
    final nearby = destinations.where((destination) {
      final coordinates = destination.coordinates;
      if (coordinates == null) return true;
      return _distanceKm(location, coordinates) <= radiusKm;
    }).toList()
      ..sort((a, b) {
        final priorityCompare =
            _nearbyTrendingPriority(a).compareTo(_nearbyTrendingPriority(b));
        if (priorityCompare != 0) return priorityCompare;

        final aDistance = a.coordinates == null
            ? double.infinity
            : _distanceKm(location, a.coordinates!);
        final bDistance = b.coordinates == null
            ? double.infinity
            : _distanceKm(location, b.coordinates!);
        final distanceCompare = aDistance.compareTo(bDistance);
        if (distanceCompare != 0) return distanceCompare;

        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;

        return a.name.compareTo(b.name);
      });

    return nearby.take(limit).toList();
  }

  int _nearbyTrendingPriority(Destination destination) {
    return switch (destination.category) {
      DestinationCategory.food => 0,
      DestinationCategory.malls => 1,
      DestinationCategory.activities => 2,
      DestinationCategory.landmark => 3,
      DestinationCategory.park => 4,
      DestinationCategory.museum => 5,
    };
  }

  Future<void> _filterByCategory(DestinationCategory? category) async {
    final generation = ++_searchGeneration;

    _searchDebounce?.cancel();
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _selectedCategory = category;
      _searchController.clear();
    });

    try {
      final location = await DestinationService.getCurrentLocation();

      if (category == null) {
        final destinations = await DestinationService.getTrendingDestinations();
        final deduped =
            DestinationService.deduplicateDestinationsById(destinations);
        final nearbyTrending = _prioritizedNearbyTrendingPlaces(
          deduped,
          location,
          radiusKm: 5,
          limit: 5,
        );

        if (!mounted || generation != _searchGeneration) return;

        setState(() {
          _destinations = nearbyTrending;
        });
        return;
      }

      final destinations = await DestinationService.searchDestinations('');
      final deduped =
          DestinationService.deduplicateDestinationsById(destinations);
      final filtered = _nearbyPlacesForCategory(
        deduped,
        location,
        category,
        radiusKm: 5,
        limit: 5,
      );

      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        _destinations = filtered;
      });
    } catch (e) {
      debugPrint('Category filter error: $e');
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Explore Philippines',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildFilterChips(),
            const SizedBox(height: 12),
            _buildExploreSummary(),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _isLoading ? _buildLoadingIndicator() : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => _queueSearchDestinations(),
          decoration: InputDecoration(
            hintText: 'Search Philippines destinations...',
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _queueSearchDestinations();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final categories = <DestinationCategory?>[
      null,
      ..._categories,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((category) {
            final isSelected = _selectedCategory == category;
            final label = category == null
                ? 'All'
                : DestinationService.getCategoryName(category);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => _filterByCategory(category),
                backgroundColor: Colors.white,
                selectedColor: Colors.blue[50],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.blue[700] : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                elevation: isSelected ? 2 : 0,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildExploreSummary() {
    final isSearching = _searchController.text.trim().isNotEmpty;
    final summary = isSearching
        ? 'Showing search results'
        : _selectedCategory == null
            ? 'Showing 5 nearby trending places, prioritizing food and malls'
            : 'Showing up to 5 nearby places within 5 km for this category';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(
            isSearching
                ? Icons.search_rounded
                : _selectedCategory == null
                    ? Icons.trending_up_rounded
                    : Icons.near_me_rounded,
            size: 18,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_destinations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No destinations found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _selectedCategory = null;
                _runDestinationSearch();
              },
              child: const Text('Show All'),
            ),
          ],
        ),
      );
    }

    final hasFewResults = _destinations.length < 5;

    return Column(
      children: [
        if (hasFewResults) _buildFewResultsPrompt(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _destinations.length,
            itemBuilder: (context, index) {
              final destination = _destinations[index];
              debugPrint('=== BUILDING CARD FOR: ${destination.name} ===');
              debugPrint('=== DESTINATION ID: ${destination.id} ===');
              return _buildDestinationCard(destination);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFewResultsPrompt() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Only ${_destinations.length} found. Try a different search or category!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage(DestinationCategory category) {
    final (startColor, endColor) = switch (category) {
      DestinationCategory.park => (
          const Color(0xFF81C784),
          const Color(0xFF4CAF50),
        ),
      DestinationCategory.landmark => (
          const Color(0xFF64B5F6),
          const Color(0xFF2196F3),
        ),
      DestinationCategory.food => (
          const Color(0xFFFFB74D),
          const Color(0xFFFF9800),
        ),
      DestinationCategory.activities => (
          const Color(0xFFBA68C8),
          const Color(0xFF9C27B0),
        ),
      DestinationCategory.museum => (
          const Color(0xFFF06292),
          const Color(0xFFE91E63),
        ),
      DestinationCategory.malls => (
          const Color(0xFF4DB6AC),
          const Color(0xFF009688),
        ),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 48, color: Colors.white),
            SizedBox(height: 8),
            Text(
              'No Photo Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard(Destination destination) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlay
            Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: destination.imageUrl.isNotEmpty &&
                            destination.imageUrl.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: destination.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.blue[600],
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              return _buildFallbackImage(destination.category);
                            },
                          )
                        : _buildFallbackImage(destination.category),
                  ),
                ),
                // Category tag and heart icon overlay
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      DestinationService.getCategoryName(destination.category),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(destination),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _favoriteIds.contains(destination.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.red,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                // Text overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(0),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination.location,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    destination.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  // Centered View Details button
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        debugPrint('=== TAPPING ON: ${destination.name} ===');
                        debugPrint('=== PASSING ID: ${destination.id} ===');
                        ExploreDetailsScreen.showAsBottomSheet(
                          context,
                          destinationId: destination.id,
                          source: 'explore',
                          destination: destination,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'View Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
