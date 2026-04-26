import 'dart:async';
import 'package:flutter/material.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/travel_cost_service.dart';
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
  final TextEditingController _searchController = TextEditingController();
  DestinationCategory? _selectedCategory;
  List<Destination> _destinations = [];
  bool _isLoading = false;
  final Map<String, List<TravelCostEstimate>> _travelCosts = {};
  final Set<String> _favoriteIds = {};
  final FavoritesService _favoritesService = FavoritesService();
  StreamSubscription? _subscription;

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

  Future<void> _toggleFavorite(String id) async {
    try {
      await _favoritesService.toggleFavorite(id);
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
    DestinationCategory.market,
  ];

  Future<void> _loadDestinations() async {
    setState(() => _isLoading = true);
    try {
final destinations = await DestinationService.searchDestinationsEnhanced(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        category: _selectedCategory,
      );
      setState(() => _destinations = destinations);
      _loadTravelCosts(destinations);
    } catch (e) {
      debugPrint('Error loading destinations: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTravelCosts(List<Destination> destinations) async {
    for (final destination in destinations) {
      if (destination.coordinates != null) {
        try {
          final costs = await TravelCostService.getTravelCostEstimates(destination.coordinates!);
          if (mounted) {
            setState(() {
              _travelCosts[destination.id] = costs;
            });
          }
        } catch (e) {
          print('Error loading travel costs for ${destination.name}: $e');
        }
      }
    }
  }

  Future<void> _searchDestinations() async {
    setState(() => _isLoading = true);
    try {
      final destinations = await DestinationService.searchDestinationsEnhanced(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        category: _selectedCategory,
      );
      setState(() => _destinations = destinations);
      _loadTravelCosts(destinations);
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _filterByCategory(DestinationCategory? category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });

    try {
      final destinations = await DestinationService.searchDestinationsEnhanced(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        category: category,
      );
      setState(() => _destinations = destinations);
      _loadTravelCosts(destinations);
    } catch (e) {
      debugPrint('Category filter error: $e');
    } finally {
      setState(() => _isLoading = false);
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
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: Colors.grey[700]),
            onPressed: () {
              // TODO: Advanced filters
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildFilterChips(),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading ? _buildLoadingIndicator() : _buildSearchResults(),
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
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => _searchDestinations(), // real-time search
          decoration: InputDecoration(
            hintText: 'Search Philippines destinations...',
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _searchDestinations();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(DestinationService.getCategoryName(category)),
                selected: isSelected,
                onSelected: (selected) => _filterByCategory(selected ? category : null),
                backgroundColor: Colors.white,
                selectedColor: Colors.blue[50],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.blue[700] : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: isSelected ? 2 : 0,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_destinations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No destinations found', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _destinations.length,
      itemBuilder: (context, index) {
        final destination = _destinations[index];
        print('=== BUILDING CARD FOR: ${destination.name} ===');
        print('=== DESTINATION ID: ${destination.id} ===');
        return _buildDestinationCard(destination);
      },
    );
  }

  Widget _buildFallbackImage(DestinationCategory category) {
    Color startColor, endColor;
    IconData iconData;
    String categoryName;

    switch (category) {
      case DestinationCategory.park:
        startColor = const Color(0xFF81C784);
        endColor = const Color(0xFF4CAF50);
        iconData = Icons.park;
        categoryName = 'Park';
        break;
      case DestinationCategory.landmark:
        startColor = const Color(0xFF64B5F6);
        endColor = const Color(0xFF2196F3);
        iconData = Icons.location_city;
        categoryName = 'Landmark';
        break;
      case DestinationCategory.food:
        startColor = const Color(0xFFFFB74D);
        endColor = const Color(0xFFFF9800);
        iconData = Icons.restaurant;
        categoryName = 'Food';
        break;
      case DestinationCategory.activities:
        startColor = const Color(0xFFBA68C8);
        endColor = const Color(0xFF9C27B0);
        iconData = Icons.beach_access;
        categoryName = 'Activity';
        break;
      case DestinationCategory.museum:
        startColor = const Color(0xFFF06292);
        endColor = const Color(0xFFE91E63);
        iconData = Icons.museum;
        categoryName = 'Museum';
        break;
      case DestinationCategory.market:
        startColor = const Color(0xFF4DB6AC);
        endColor = const Color(0xFF009688);
        iconData = Icons.shopping_cart;
        categoryName = 'Market';
        break;
      default:
        startColor = const Color(0xFF90A4AE);
        endColor = const Color(0xFF607D8B);
        iconData = Icons.place;
        categoryName = 'Place';
    }

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
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: destination.imageUrl.isNotEmpty && destination.imageUrl.startsWith('http')
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
                              print('CachedNetworkImage error for ${destination.name}: $error');
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    onTap: () => _toggleFavorite(destination.id),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        _favoriteIds.contains(destination.id) ? Icons.favorite : Icons.favorite_border,
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
                          Colors.black.withOpacity(0.7),
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
                        print('=== TAPPING ON: ${destination.name} ===');
                        print('=== PASSING ID: ${destination.id} ===');
                        ExploreDetailsScreen.showAsBottomSheet(
                          context,
                          destinationId: destination.id,
                          source: 'explore',
                          destination: destination,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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