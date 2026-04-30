import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/utils/navigation_utils.dart';

class AddPlaceScreen extends StatefulWidget {
  final int? targetDay; // Optional day to add place to

  const AddPlaceScreen({super.key, this.targetDay});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  DestinationCategory? _selectedCategory;
  bool _isLoading = false;
  Timer? _searchDebounce;
  int _searchVersion = 0;
  List<Destination> _destinations = [];
  List<Destination> _favoriteDestinations = [];
  List<Destination> _recentlyExplored = [];

  final List<DestinationCategory> _categories = [
    DestinationCategory.park,
    DestinationCategory.landmark,
    DestinationCategory.food,
    DestinationCategory.activities,
    DestinationCategory.museum,
    DestinationCategory.market,
  ];

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    await _searchDestinations();
  }

  Future<void> _searchDestinations() async {
    if (!mounted) return;
    final version = ++_searchVersion;
    setState(() => _isLoading = true);
    try {
      final destinations = await DestinationService.searchDestinationsEnhanced(
        query: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        category: _selectedCategory,
      );

      // For demo purposes, let's mark some as favorites and recently explored
      final favorites = destinations.take(3).toList();
      final recent = destinations.skip(3).take(4).toList();

      if (!mounted || version != _searchVersion) return;
      setState(() {
        _destinations = destinations;
        _favoriteDestinations = favorites;
        _recentlyExplored = recent;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || version != _searchVersion) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load destinations: $e')),
      );
    }
  }

  Future<void> _filterByCategory(DestinationCategory? category) async {
    setState(() {
      _selectedCategory = category;
    });
    await _searchDestinations();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchDestinations();
    });
  }

  void _addDestination(Destination destination) {
    safePopWithResult(context, destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => safeNavigateBack(context),
        ),
        title: Text(
          widget.targetDay != null
              ? 'Add to Day ${widget.targetDay}'
              : 'Add Place',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar (from explore screen)
          _buildSearchBar(),
          const SizedBox(height: 16),

          // Category Filters (from explore screen)
          _buildFilterChips(),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14.4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show sections only when not searching
                        if (_searchController.text.isEmpty) ...[
                          // Your Favorites Section
                          if (_favoriteDestinations.isNotEmpty) ...[
                            _buildSectionHeader('Your Favorites'),
                            const SizedBox(height: 12),
                            _buildHorizontalDestinationList(
                              _favoriteDestinations,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Recently Explored Section
                          if (_recentlyExplored.isNotEmpty) ...[
                            _buildSectionHeader('Recently Explored'),
                            const SizedBox(height: 12),
                            _buildDestinationGrid(_recentlyExplored),
                            const SizedBox(height: 24),
                          ],

                          // All Destinations Section
                          _buildSectionHeader('All Places'),
                          const SizedBox(height: 12),
                          _buildDestinationGrid(_destinations),
                        ] else ...[
                          // When searching, show all destinations without section headers
                          _buildDestinationGrid(_destinations),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
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
          onChanged: (_) => _onSearchChanged(),
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
                onSelected: (selected) =>
                    _filterByCategory(selected ? category : null),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildHorizontalDestinationList(List<Destination> destinations) {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: destinations.length,
        itemBuilder: (context, index) {
          final destination = destinations[index];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            child: _buildDestinationCard(destination),
          );
        },
      ),
    );
  }

  Widget _buildDestinationGrid(List<Destination> destinations) {
    if (destinations.isEmpty) {
      final providerError = DestinationService.placesProviderError;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            const Icon(Icons.place_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              providerError == null
                  ? 'No places found'
                  : 'Google Places is unavailable',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (providerError != null) ...[
              const SizedBox(height: 8),
              Text(
                providerError,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: destinations.length,
      itemBuilder: (context, index) {
        final destination = destinations[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildDestinationCard(destination),
        );
      },
    );
  }

  Widget _buildDestinationCard(Destination destination) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              color: Colors.grey[300],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: destination.imageUrl.isNotEmpty
                  ? Image.network(
                      destination.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultImage();
                      },
                    )
                  : _buildDefaultImage(),
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destination.location,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _addDestination(destination),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(Icons.place, size: 40, color: Colors.grey[600]),
      ),
    );
  }
}
