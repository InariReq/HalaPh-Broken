import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:halaph/widgets/motion_widgets.dart';

class MyPlansScreen extends StatefulWidget {
  const MyPlansScreen({super.key});

  @override
  State<MyPlansScreen> createState() => _MyPlansScreenState();
}

class _MyPlansScreenState extends State<MyPlansScreen> {
  final FriendService _friendService = FriendService();
  String _myCode = 'current_user';
  bool _isLoading = true;
  StreamSubscription? _plansSubscription;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _plansSubscription = SimplePlanService.changes.listen((_) {
      _loadPlans(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _plansSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadPlans({bool forceRefresh = false}) async {
    final results = await Future.wait<dynamic>([
      _friendService.getMyCode().catchError((_) => 'demo_user'),
      SimplePlanService.initialize(forceRefresh: forceRefresh).catchError((e) {
        debugPrint('SimplePlanService.init error: $e');
      }),
    ]);
    if (!mounted) return;

    setState(() {
      _myCode = results[0] as String;
      _isLoading = false;
    });

    debugPrint('Loaded plans for user: $_myCode');
    final personalPlans = SimplePlanService.getUserPlans();
    final sharedPlans = SimplePlanService.getCollaborativePlans();
    debugPrint(
      'Personal plans: ${personalPlans.length}, Shared plans: ${sharedPlans.length}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final personalPlans = SimplePlanService.getUserPlans();
    final sharedPlans = SimplePlanService.getCollaborativePlans();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'My Plans',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingStatePanel(label: 'Loading plans...')
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildCreateNewPlan(context),
                    const SizedBox(height: 24),
                    _buildPersonalPlans(personalPlans),
                    const SizedBox(height: 24),
                    _buildSharedPlans(sharedPlans),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPersonalPlans(List<TravelPlan> plans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'MY PERSONAL PLANS',
          subtitle: plans.isEmpty
              ? 'Plans you create will appear here.'
              : '${plans.length} active plan${plans.length == 1 ? '' : 's'}',
          icon: Icons.person_pin_circle_rounded,
          iconColor: const Color(0xFF1976D2),
        ),
        const SizedBox(height: 14),
        plans.isEmpty
            ? _buildPlanEntrance(
                order: 0,
                child: _buildEmptyPlansPlaceholder('No personal plans yet'),
              )
            : Column(
                children: plans.asMap().entries.map((entry) {
                  return _buildPlanEntrance(
                    order: entry.key,
                    child: _buildPlanCard(entry.value),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildSharedPlans(List<TravelPlan> plans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'COLLABORATIVE PLANS',
          subtitle: plans.isEmpty
              ? 'Shared trips from friends will appear here.'
              : '${plans.length} shared plan${plans.length == 1 ? '' : 's'}',
          icon: Icons.groups_rounded,
          iconColor: const Color(0xFF7B1FA2),
        ),
        const SizedBox(height: 14),
        plans.isEmpty
            ? _buildPlanEntrance(
                order: 0,
                child: _buildEmptyPlansPlaceholder(
                  'No collaborative plans yet',
                ),
              )
            : Column(
                children: plans.asMap().entries.map((entry) {
                  return _buildPlanEntrance(
                    order: entry.key,
                    child: _buildPlanCard(
                      entry.value,
                      isSharedPlan: true,
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
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

  Widget _buildPlanEntrance({
    required int order,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (order.clamp(0, 4) * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
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
      source: 'my_plans',
      destination: destination,
    );
  }

  Widget _buildPlanDestinationShortcut(Destination destination) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _openPlanDestinationDetails(destination),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 14,
                  color: Color(0xFF1565C0),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    destination.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 13,
                  color: Color(0xFF1565C0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(TravelPlan plan, {bool isSharedPlan = false}) {
    final shouldLeave = isSharedPlan && !SimplePlanService.isPlanOwner(plan.id);
    final firstDestination = _firstPlanDestination(plan);
    final destinationCount = _destinationCount(plan);
    final accentColor =
        isSharedPlan ? const Color(0xFF7B1FA2) : const Color(0xFF1976D2);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.go('/plan-details?planId=${plan.id}');
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.72),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSharedPlan ? Icons.group_work_rounded : Icons.map_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (plan.isFinished) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Done',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildPlanMetaChip(
                          icon: Icons.calendar_today_rounded,
                          label: _formatDateRange(
                            plan.startDate,
                            plan.endDate,
                          ),
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        _buildPlanMetaChip(
                          icon: Icons.place_rounded,
                          label:
                              '$destinationCount stop${destinationCount == 1 ? '' : 's'}',
                          color: accentColor,
                        ),
                      ],
                    ),
                    if (firstDestination != null)
                      _buildPlanDestinationShortcut(firstDestination),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!shouldLeave && !plan.isFinished)
                    IconButton(
                      onPressed: () {
                        _showMarkFinishedConfirmation(context, plan);
                      },
                      icon: Icon(
                        Icons.check_circle_outline,
                        color: Colors.green[600],
                        size: 20,
                      ),
                      tooltip: 'Mark as finished',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  IconButton(
                    onPressed: () {
                      if (shouldLeave) {
                        _showLeaveConfirmation(context, plan);
                      } else {
                        _showDeleteConfirmation(context, plan);
                      }
                    },
                    icon: Icon(
                      shouldLeave ? Icons.logout : Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    tooltip: shouldLeave ? 'Leave plan' : 'Delete plan',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanMetaChip({
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

  int _destinationCount(TravelPlan plan) {
    return plan.itinerary.fold<int>(
      0,
      (total, day) => total + day.items.length,
    );
  }

  Future<void> _showMarkFinishedConfirmation(
    BuildContext context,
    TravelPlan plan,
  ) async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark as finished?'),
        content: Text(
          'Move "${plan.title}" to Trip History? You can still open it from Trip History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Mark Finished'),
          ),
        ],
      ),
    );

    if (shouldFinish != true) return;

    final success = await SimplePlanService.markPlanFinished(plan.id);
    if (!mounted || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Plan moved to Trip History.'
              : 'Could not mark plan as finished.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      setState(() {});
    }
  }

  String _formatDateRange(DateTime startDate, DateTime endDate) {
    final months = [
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
    return '${months[startDate.month - 1]} ${startDate.day} - ${months[endDate.month - 1]} ${endDate.day}';
  }

  Widget _buildEmptyPlansPlaceholder(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: EmptyStatePanel(
        icon: Icons.folder_open_rounded,
        title: message,
        message: 'Create or join a plan to see it here.',
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TravelPlan plan) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Plan'),
          content: Text(
            'Are you sure you want to delete "${plan.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final success = await SimplePlanService.deletePlan(plan.id);
                if (!mounted) return;
                if (success) {
                  _loadPlans();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Plan "${plan.title}" deleted successfully',
                      ),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Failed to delete plan')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showLeaveConfirmation(BuildContext context, TravelPlan plan) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Leave Plan'),
          content: Text('Are you sure you want to leave "${plan.title}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final success = await SimplePlanService.leavePlan(plan.id);
                if (!mounted) return;
                if (success) {
                  _loadPlans(forceRefresh: true);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Left "${plan.title}"')),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Failed to leave plan')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreateNewPlan(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () {
          debugPrint('My Plans Create New Plan tapped!');
          GoRouter.of(context).push('/create-plan');
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1976D2),
                Color(0xFF03A9F4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Plan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Start a route, add stops, and organize your trip.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
