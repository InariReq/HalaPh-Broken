import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/widgets/motion_widgets.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  bool _loading = true;
  List<TravelPlan> _pastPlans = [];
  StreamSubscription<void>? _plansSubscription;

  @override
  void initState() {
    super.initState();
    _loadTripHistory();
    _plansSubscription = SimplePlanService.changes.listen((_) {
      _syncTripHistoryFromCache();
    });
  }

  @override
  void dispose() {
    _plansSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTripHistory() async {
    setState(() {
      _loading = true;
    });

    try {
      await SimplePlanService.initialize(forceRefresh: true);
      final plans = _tripHistoryPlansFromCache();

      if (!mounted) return;
      setState(() {
        _pastPlans = plans;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load trip history: $e');
      if (!mounted) return;
      setState(() {
        _pastPlans = [];
        _loading = false;
      });
    }
  }

  void _syncTripHistoryFromCache() {
    if (!mounted) return;

    setState(() {
      _pastPlans = _tripHistoryPlansFromCache();
      _loading = false;
    });
  }

  List<TravelPlan> _tripHistoryPlansFromCache() {
    final plans = List<TravelPlan>.from(
      SimplePlanService.getAllPlans().where(
        SimplePlanService.isPlanInTripHistory,
      ),
    )..sort((a, b) => b.endDate.compareTo(a.endDate));
    return plans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Trip History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTripHistory,
        child: _loading
            ? const LoadingStatePanel(label: 'Loading trip history...')
            : _pastPlans.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                    children: [
                      const EmptyStatePanel(
                        icon: Icons.history_rounded,
                        title: 'No finished trips yet',
                        message:
                            'Finished plans will appear here after you mark them complete.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    itemCount: _pastPlans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final plan = _pastPlans[index];
                      return _TripHistoryCard(
                        plan: plan,
                        onReturnFromDetails: _syncTripHistoryFromCache,
                      );
                    },
                  ),
      ),
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  final TravelPlan plan;
  final VoidCallback onReturnFromDetails;

  const _TripHistoryCard({
    required this.plan,
    required this.onReturnFromDetails,
  });

  @override
  Widget build(BuildContext context) {
    final banner = plan.bannerImage?.trim();
    final hasBanner = banner != null && banner.isNotEmpty;
    final destinations = plan.itinerary
        .expand((day) => day.items)
        .map((item) => item.destination.name)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();
    final totalStops = plan.itinerary.fold<int>(
      0,
      (total, day) => total + day.items.length,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () async {
        await GoRouter.of(context).push(
          '/plan-details?planId=${Uri.encodeComponent(plan.id)}',
        );
        onReturnFromDetails();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasBanner)
              CachedNetworkImage(
                imageUrl: banner,
                height: 138,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildBannerFallback(),
                errorWidget: (_, __, ___) => _buildBannerFallback(),
              )
            else
              _buildBannerFallback(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title.isEmpty ? 'Untitled Trip' : plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        context,
                        icon: Icons.calendar_today_rounded,
                        label: plan.formattedDateRange,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      _buildInfoChip(
                        context,
                        icon: Icons.place_rounded,
                        label: '$totalStops stop${totalStops == 1 ? '' : 's'}',
                        color: const Color(0xFF1976D2),
                      ),
                    ],
                  ),
                  if (destinations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      destinations.take(3).join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF16351F)
                              : Colors.green[50],
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 15,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerFallback() {
    return Container(
      height: 118,
      width: double.infinity,
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
          Icons.route_rounded,
          size: 42,
          color: Colors.white.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}
