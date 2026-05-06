import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/services/simple_plan_service.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  bool _loading = true;
  List<TravelPlan> _pastPlans = [];

  @override
  void initState() {
    super.initState();
    _loadTripHistory();
  }

  Future<void> _loadTripHistory() async {
    setState(() {
      _loading = true;
    });

    try {
      await SimplePlanService.initialize(forceRefresh: true);
      final plans = SimplePlanService.getAllPlans()
          .where(SimplePlanService.isPlanInTripHistory)
          .toList()
        ..sort((a, b) => b.endDate.compareTo(a.endDate));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Trip History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTripHistory,
        child: _loading
            ? Center(
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
            : _pastPlans.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
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
                              height: 64,
                              width: 64,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Icon(
                                Icons.history_rounded,
                                size: 34,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No trip history yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Plans you mark as finished will appear here. Old plans also appear here after their end date.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    itemCount: _pastPlans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final plan = _pastPlans[index];
                      return _TripHistoryCard(plan: plan);
                    },
                  ),
      ),
    );
  }
}

class _TripHistoryCard extends StatelessWidget {
  final TravelPlan plan;

  const _TripHistoryCard({required this.plan});

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
      onTap: () {
        GoRouter.of(context).push(
          '/plan-details?planId=${Uri.encodeComponent(plan.id)}',
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        icon: Icons.calendar_today_rounded,
                        label: plan.formattedDateRange,
                        color: const Color(0xFF475569),
                      ),
                      _buildInfoChip(
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
                        color: Colors.grey[800],
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
                          color: Colors.green[50],
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
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.grey[500]),
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

  Widget _buildInfoChip({
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
      decoration: const BoxDecoration(
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
