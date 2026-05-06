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
    DestinationCategory.malls,
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
      final destinations = await DestinationService.searchDestinations(
        _searchController.text,
      );
      final filteredDestinations = _selectedCategory == null
          ? destinations
          : destinations
              .where((destination) => destination.category == _selectedCategory)
              .toList(growable: false);

      // For demo purposes, let's mark some as favorites and recently explored
      final favorites = filteredDestinations.take(3).toList();
      final recent = filteredDestinations.skip(3).take(4).toList();

      if (!mounted || version != _searchVersion) return;
      setState(() {
        _destinations = filteredDestinations;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w800,
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
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE5EAF3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        height: 36,
                        width: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  )
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
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5EAF3)),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => _onSearchChanged(),
          decoration: InputDecoration(
            hintText: 'Search Philippines destinations...',
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.blue[700]),
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
              borderRadius: BorderRadius.circular(22),
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
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                selectedColor: Colors.blue[50],
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.blue[700] : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF90CAF9)
                      : const Color(0xFFE5EAF3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.place_rounded,
            color: Colors.blue[700],
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.2,
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5EAF3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.travel_explore_rounded,
                  size: 30,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                providerError == null
                    ? 'No places found'
                    : 'Google Places is unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
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
      height: 292,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).cardColor,
        border: Border.all(color: const Color(0xFFE8EEF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                top: Radius.circular(22),
              ),
              color: Colors.grey[300],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
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
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destination.location,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _addDestination(destination),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1976D2),
            Color(0xFF03A9F4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.place_rounded,
          size: 42,
          color: Colors.white.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}
