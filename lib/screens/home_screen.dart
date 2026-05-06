import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:go_router/go_router.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/models/plan.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Destination> _trendingDestinations = [];
  bool _isLoading = false;
  bool _isTrendingLoadInProgress = false;
  final Set<String> _favoriteIds = {};
  final FavoritesService _favoritesService = FavoritesService();
  final FriendService _friendService = FriendService();
  StreamSubscription? _favoritesSubscription;
  StreamSubscription? _plansSubscription;
  TravelPlan? _nextPlan;
  bool _plansLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndTrending();
    _loadFavorites();
    _loadUpcomingPlan();
    _favoritesSubscription = FavoritesNotifier().onFavoritesChanged.listen((_) {
      _loadFavorites();
    });
    _plansSubscription = SimplePlanService.changes.listen((_) {
      _loadUpcomingPlan();
    });
  }

  Future<void> _initializeLocationAndTrending() async {
    await _checkLocationStatus();
    await _loadTrendingDestinations();
  }

  Future<void> _checkLocationStatus() async {
    if (!mounted) return;
    setState(() {
      _locationStatus = 'Getting location...';
      _locationEnabled = false;
    });

    try {
      final location = await DestinationService.getCurrentLocation();
      if (!mounted) return;
      final hasValidLocation = !DestinationService.isInvalidLocation(location);

      setState(() {
        _locationEnabled = hasValidLocation;
        _locationStatus = hasValidLocation
            ? 'Location found • Showing nearby places'
            : 'Location off • Showing popular destinations';
      });

      // Trending destinations are loaded once from initState.
      // Avoid triggering a second location/search request after status check.
    } catch (e) {
      debugPrint('Location check error: $e');
      if (!mounted) return;
      setState(() {
        _locationEnabled = false;
        _locationStatus = 'Location unavailable • Showing popular destinations';
      });
    }
  }

  Future<void> _loadUpcomingPlan({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _plansLoading = true;
    });
    try {
      await SimplePlanService.initialize(forceRefresh: forceRefresh);
      final myCode = await _friendService.getMyCode().catchError(
            (_) => 'current_user',
          );
      final nextPlan = SimplePlanService.getNextUpcomingPlan(userId: myCode);
      if (!mounted) return;
      setState(() {
        _nextPlan = nextPlan;
        _plansLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading upcoming plan: $e');
      if (!mounted) return;
      setState(() {
        _plansLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    _plansSubscription?.cancel();
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
      setState(() {
        if (_favoriteIds.contains(id)) {
          _favoriteIds.remove(id);
        } else {
          _favoriteIds.add(id);
        }
      });
    } catch (_) {}
  }

  Future<void> _loadTrendingDestinations() async {
    if (!mounted || _isTrendingLoadInProgress) return;

    _isTrendingLoadInProgress = true;
    setState(() {
      _isLoading = true;
      _trendingDestinations = []; // Clear cache first
    });

    try {
      debugPrint('=== HOME SCREEN: Loading trending destinations ===');
      final destinations = await DestinationService.getTrendingDestinations();
      debugPrint(
        'Home screen loaded ${destinations.length} trending destinations',
      );

      // Debug: Check if we got any real data
      if (destinations.isEmpty) {
        debugPrint('❌ NO DESTINATIONS RETURNED');
      } else {
        debugPrint('✅ Got ${destinations.length} destinations');
        for (var dest in destinations.take(3)) {
          debugPrint('- ${dest.name} (${dest.category}) - ID: ${dest.id}');
        }
      }

      if (!mounted) return;
      setState(() {
        _trendingDestinations = destinations;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading trending destinations: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } finally {
      _isTrendingLoadInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHomeEntrance(
                order: 0,
                child: _buildHeader(context),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _buildHomeEntrance(
                order: 1,
                child: _buildCurrentPlan(context),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _buildHomeEntrance(
                order: 2,
                child: _buildTrendingSection(context),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeEntrance({
    required Widget child,
    required int order,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (order * 90)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  bool _locationEnabled = true;
  String _locationStatus = 'Getting location...';

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [
                        Color(0xFF0D47A1),
                        Color(0xFF1976D2),
                        Color(0xFF03A9F4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    );
                  },
                  child: Text(
                    'Where Every Trip\nFinds Its Line',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                      letterSpacing: -0.8,
                      shadows: [
                        Shadow(
                          color: Color(0x22000000),
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Discover Philippines',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _locationEnabled ? Icons.location_on : Icons.location_off,
                      size: 20,
                      color: _locationEnabled
                          ? Colors.green[600]
                          : Colors.grey[600],
                    ),
                    if (!_locationEnabled) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _retryLocation,
                        child: Icon(
                          Icons.refresh,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ],
                ),
                if (!_locationEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _locationStatus,
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ),
              ],
            ),
          ),
          StreamBuilder<firebase_auth.User?>(
            stream: firebase_auth.FirebaseAuth.instance.userChanges(),
            initialData: firebase_auth.FirebaseAuth.instance.currentUser,
            builder: (context, snapshot) {
              final avatarUrl = snapshot.data?.photoURL?.trim();
              final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

              return Tooltip(
                message: 'Open settings',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => GoRouter.of(context).push('/settings'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1976D2),
                            Color(0xFF03A9F4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        backgroundImage: hasAvatar
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: hasAvatar
                            ? null
                            : Icon(Icons.person, color: Colors.blue[700]),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _retryLocation() async {
    setState(() {
      _locationStatus = 'Getting location...';
      _locationEnabled = false;
    });

    try {
      final location = await DestinationService.getCurrentLocation();
      final hasValidLocation = !DestinationService.isInvalidLocation(location);

      if (!mounted) return;

      setState(() {
        _locationEnabled = hasValidLocation;
        _locationStatus = hasValidLocation
            ? 'Location found • Showing nearby places'
            : 'Unable to get location • Tap refresh to retry';
      });

      if (hasValidLocation) {
        _loadTrendingDestinations();
      }
    } catch (e) {
      debugPrint('Retry location error: $e');
      if (!mounted) return;
      setState(() {
        _locationEnabled = false;
        _locationStatus = 'Location error • Tap refresh to retry';
      });
    }
  }

  Widget _buildCurrentPlan(BuildContext context) {
    if (_plansLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF3F8FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1ECFF)),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              height: 34,
              width: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Loading your next plan...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_nextPlan != null) {
      return _buildNextPlanCard(context, _nextPlan!);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF3F8FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1ECFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Next Up',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'No current plans yet. Start a trip plan when you are ready.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.20),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  debugPrint('Create Plan tapped!');
                  GoRouter.of(context).push('/create-plan');
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Create Plan',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _bestPlanImagePath(TravelPlan plan) {
    final banner = plan.bannerImage?.trim();
    if (banner != null && banner.isNotEmpty) {
      return banner;
    }

    for (final day in plan.itinerary) {
      for (final item in day.items) {
        final imageUrl = item.destination.imageUrl.trim();
        if (imageUrl.isNotEmpty) {
          return imageUrl;
        }
      }
    }

    return null;
  }

  Widget _buildNextPlanImageHeader(String dayText, String? imagePath) {
    final hasNetworkImage =
        imagePath != null && imagePath.trim().startsWith('http');
    final hasLocalImage = imagePath != null &&
        imagePath.trim().isNotEmpty &&
        !hasNetworkImage &&
        File(imagePath.trim()).existsSync();

    Widget imageLayer;
    if (hasNetworkImage) {
      imageLayer = CachedNetworkImage(
        imageUrl: imagePath.trim(),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (context, url, error) => _buildPlanImageFallback(),
        placeholder: (context, url) => _buildPlanImageFallback(),
      );
    } else if (hasLocalImage) {
      imageLayer = Image.file(
        File(imagePath.trim()),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPlanImageFallback(),
      );
    } else {
      imageLayer = _buildPlanImageFallback();
    }

    return SizedBox(
      height: 120,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageLayer,
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dayText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanImageFallback() {
    return Container(
      color: Colors.blue[400],
      child: Center(
        child: Icon(
          Icons.calendar_month,
          size: 48,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildNextPlanCard(BuildContext context, TravelPlan plan) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final planDay = DateTime(
      plan.startDate.year,
      plan.startDate.month,
      plan.startDate.day,
    );
    final endDay = DateTime(
      plan.endDate.year,
      plan.endDate.month,
      plan.endDate.day,
    );
    final daysUntil = planDay.difference(today).inDays;
    final isActive = !planDay.isAfter(today) && !endDay.isBefore(today);
    final dayText = isActive && daysUntil < 0
        ? 'Now'
        : daysUntil == 0
            ? 'Today'
            : daysUntil == 1
                ? 'Tomorrow'
                : 'In $daysUntil days';
    final destinationCount = _destinationCount(plan);
    final heroImagePath = _bestPlanImagePath(plan);
    final firstDestination = _firstPlanDestination(plan);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          GoRouter.of(context).push('/plan-details?planId=${plan.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNextPlanImageHeader(dayText, heroImagePath),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.coffee, color: Colors.brown[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Next Up',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateRange(plan.startDate, plan.endDate),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (destinationCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.place, size: 14, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$destinationCount destination${destinationCount > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (firstDestination != null)
                      _buildNextPlanStopShortcut(firstDestination),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Destination? _firstPlanDestination(TravelPlan plan) {
    for (final day in plan.itinerary) {
      for (final item in day.items) {
        return item.destination;
      }
    }
    return null;
  }

  void _openPlanDestinationDetails(Destination destination) {
    ExploreDetailsScreen.showAsBottomSheet(
      context,
      destinationId: destination.id,
      source: 'home_up_next',
      destination: destination,
    );
  }

  Widget _buildNextPlanStopShortcut(Destination destination) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openPlanDestinationDetails(destination),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.place_rounded, size: 18, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destination.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: Colors.blue[600],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _destinationCount(TravelPlan plan) {
    return plan.itinerary.fold<int>(
      0,
      (total, day) => total + day.items.length,
    );
  }

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDateRange(DateTime start, DateTime end) {
    if (start.day == end.day &&
        start.month == end.month &&
        start.year == end.year) {
      return '${_months[start.month - 1]} ${start.day}, ${start.year}';
    }
    if (start.month == end.month && start.year == end.year) {
      return '${_months[start.month - 1]} ${start.day}-${end.day}, ${start.year}';
    }
    return '${_months[start.month - 1]} ${start.day} - ${_months[end.month - 1]} ${end.day}, ${end.year}';
  }

  Widget _buildTrendingSection(BuildContext context) {
    final hasFewResults = !_isLoading && _trendingDestinations.length < 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby Trending Places',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (hasFewResults)
                      Text(
                        'Only ${_trendingDestinations.length} found',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _isLoading
            ? Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            : _trendingDestinations.isEmpty
                ? _buildEmptyPlacesState()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._trendingDestinations.map(_buildTrendingCard),
                      if (hasFewResults) _buildSearchPrompt(),
                    ],
                  ),
      ],
    );
  }

  Widget _buildSearchPrompt() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFBEB),
            Color(0xFFFFF4D8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFDFA3)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Want more options?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Search for specific places, restaurants, or attractions to discover more destinations.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              GoRouter.of(context).go('/explore');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[600],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Search Destinations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlacesState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 220,
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                'No nearby places found from your current location',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
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
      child: Center(
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

  Widget _buildTrendingCard(Destination destination) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EEF8)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
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
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.76),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          destination.location,
                          style: TextStyle(
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
                if (destination.rating <= 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_border_rounded,
                            color: Color(0xFF6B7280),
                            size: 15,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Unrated',
                            style: TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (destination.rating > 0)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB300),
                            size: 15,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            destination.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Heart icon overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(destination),
                    child: Container(
                      width: 38,
                      height: 38,
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
              ],
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    destination.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  // Explore More button
                  GestureDetector(
                    onTap: () {
                      debugPrint(
                        '=== HOME SCREEN TAP: ${destination.name} - ID: ${destination.id} ===',
                      );
                      ExploreDetailsScreen.showAsBottomSheet(
                        context,
                        destinationId: destination.id,
                        source: 'home',
                        destination: destination,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.20),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        'Explore More',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
