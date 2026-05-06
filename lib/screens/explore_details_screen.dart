import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/screens/route_options_screen.dart';
import 'package:halaph/utils/navigation_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ExploreDetailsScreen extends StatefulWidget {
  final String destinationId;
  final String? source;
  final Destination? destination;

  const ExploreDetailsScreen({
    super.key,
    required this.destinationId,
    this.source,
    this.destination,
  });

  @override
  State<ExploreDetailsScreen> createState() => _ExploreDetailsScreenState();

  static void showAsBottomSheet(
    BuildContext context, {
    required String destinationId,
    String? source,
    Destination? destination,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: ExploreDetailsScreen(
          destinationId: destinationId,
          source: source,
          destination: destination,
        ),
      ),
    );
  }
}

class _ExploreDetailsScreenState extends State<ExploreDetailsScreen> {
  Destination? _destination;
  bool _isLoading = true;
  final FavoritesService _favoritesService = FavoritesService();
  bool _isFavorite = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadDestination();
    _subscription = FavoritesNotifier().onFavoritesChanged.listen((_) {
      if (_destination != null) {
        _checkFavoriteStatus();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    if (_destination == null) return;
    final isFav = await _favoritesService.isFavorite(_destination!.id);
    if (mounted && _isFavorite != isFav) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _loadDestination() async {
    setState(() => _isLoading = true);

    try {
      Destination? found;

      if (widget.destination != null) {
        found = widget.destination;
        // Refresh place details using ID when available.
        // Destination no longer fetched by ID - use existing data
        final refreshed = null;
        if (refreshed != null) {
          found = refreshed;
        }
      }

      if (found == null) {
        final destinations = await DestinationService.getTrendingDestinations();
        for (var dest in destinations) {
          if (dest.id == widget.destinationId) {
            found = dest;
            break;
          }
        }
      }

      if (found == null) {
        final searchResults = await DestinationService.searchDestinations(
          widget.destination?.name ?? widget.destinationId,
        );
        for (var dest in searchResults) {
          if (dest.id == widget.destinationId) {
            found = dest;
            break;
          }
        }
      }

      // Destination no longer fetched by ID - use existing data

      final isFav =
          found != null ? await _favoritesService.isFavorite(found.id) : false;

      if (mounted) {
        setState(() {
          _destination = found;
          _isFavorite = isFav;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_destination == null) return;
    await _favoritesService.toggleFavoriteDestination(_destination!);
    setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _showAddToPlanSheet() async {
    final destination = _destination;
    if (destination == null) return;

    await SimplePlanService.initialize();
    if (!mounted) return;

    final plans = SimplePlanService.getAllPlans();
    if (plans.isEmpty) {
      final createPlan = await showModalBottomSheet<bool>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add to Plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text('No plans yet. Create a plan first.'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Create Plan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (createPlan == true && mounted) {
        context.push('/create-plan');
      }
      return;
    }

    final selectedPlan = await showModalBottomSheet<TravelPlan>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Add to Plan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...plans.map(
              (plan) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(plan.title),
                subtitle: Text(plan.formattedDateRange),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => Navigator.of(context).pop(plan),
              ),
            ),
          ],
        ),
      ),
    );
    if (selectedPlan == null) return;

    final success = await SimplePlanService.addDestinationToPlan(
      planId: selectedPlan.id,
      destination: destination,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${destination.name} added to ${selectedPlan.title}'
              : 'Failed to add ${destination.name} to plan',
        ),
        backgroundColor: success ? Colors.green[600] : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_destination == null) {
      return const Center(child: Text('Destination not found'));
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar at the top
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Explore Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => safeNavigateBack(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeroImageWithOverlay(),
                    const SizedBox(height: 16),
                    _buildCategorySection(),
                    const SizedBox(height: 16),
                    _buildAddToPlanButton(),
                    const SizedBox(height: 24),
                    _buildAboutSection(),
                    const SizedBox(height: 24),
                    _buildViewRoutesButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    if (imageUrl.trim().isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Preview Image'),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Text(
                    'Image unavailable',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatingChip(Destination destination) {
    final rating = destination.rating;
    if (rating <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFECB3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 17),
          const SizedBox(width: 5),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFF7A5200),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Rating',
            style: TextStyle(
              color: Color(0xFF7A5200),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImageWithOverlay() {
    final imageUrl = _destination?.imageUrl ?? '';
    final hasPreviewableImage =
        imageUrl.trim().isNotEmpty && imageUrl.trim().startsWith('http');

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: hasPreviewableImage
                  ? () => _showImagePreview(imageUrl.trim())
                  : null,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: hasPreviewableImage
                    ? CachedNetworkImage(
                        imageUrl: imageUrl.trim(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.blue[600],
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildFallbackImage(),
                      )
                    : _buildFallbackImage(),
              ),
            ),
          ),
          if (hasPreviewableImage)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_out_map, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Tap to preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _toggleFavorite,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ),
          ),
          if (_destination != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
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
                      _destination!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _destination!.location,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF81D4FA), Color(0xFF29B6F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.place, size: 48, color: Colors.white),
            SizedBox(height: 8),
            Text(
              'No Photo Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    final destination = _destination;
    if (destination == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getCategoryIcon(destination.category),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  DestinationService.getCategoryName(destination.category),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _buildRatingChip(destination),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(DestinationCategory category) {
    switch (category) {
      case DestinationCategory.park:
        return Icons.park;
      case DestinationCategory.landmark:
        return Icons.location_city;
      case DestinationCategory.food:
        return Icons.restaurant;
      case DestinationCategory.activities:
        return Icons.beach_access;
      case DestinationCategory.museum:
        return Icons.museum;
      case DestinationCategory.malls:
        return Icons.shopping_cart;
    }
  }

  Widget _buildAboutSection() {
    if (_destination == null) return SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About the destination',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _destination!.description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF757575),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddToPlanButton() {
    return InkWell(
      onTap: _destination == null ? null : _showAddToPlanSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add to Plan',
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.green,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewRoutesButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _destination == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RouteOptionsScreen(
                      destinationId: widget.destinationId,
                      destinationName: _destination?.name ?? 'Destination',
                      destination: _destination,
                      source: widget.source,
                    ),
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'View Routes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
