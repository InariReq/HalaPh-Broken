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
        title: const Text('Trip History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTripHistory,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _pastPlans.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 120),
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No trip history yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Plans you mark as finished will appear here. Old plans also appear here after their end date.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pastPlans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        GoRouter.of(context).push(
          '/plan-details?planId=${Uri.encodeComponent(plan.id)}',
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
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
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildBannerFallback(),
              )
            else
              _buildBannerFallback(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title.isEmpty ? 'Untitled Trip' : plan.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plan.formattedDateRange,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  if (destinations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      destinations.take(3).join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 18, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: Colors.grey[500]),
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

  Widget _buildBannerFallback() {
    return Container(
      height: 96,
      width: double.infinity,
      color: const Color(0xFFE3F2FD),
      child: const Icon(Icons.route, size: 38, color: Color(0xFF1976D2)),
    );
  }
}
