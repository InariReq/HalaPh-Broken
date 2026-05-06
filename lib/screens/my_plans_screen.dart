import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/utils/navigation_utils.dart';

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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => safeNavigateBack(context),
        ),
        title: const Text(
          'My Plans',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildPersonalPlans(personalPlans),
                    const SizedBox(height: 24),
                    _buildSharedPlans(sharedPlans),
                    const SizedBox(height: 24),
                    _buildCreateNewPlan(context),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'MY PERSONAL PLANS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        plans.isEmpty
            ? _buildEmptyPlansPlaceholder('No personal plans yet')
            : Column(
                children: plans.map((plan) => _buildPlanCard(plan)).toList(),
              ),
      ],
    );
  }

  Widget _buildSharedPlans(List<TravelPlan> plans) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'COLLABORATIVE PLANS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        plans.isEmpty
            ? _buildEmptyPlansPlaceholder('No collaborative plans yet')
            : Column(
                children: plans
                    .map((plan) => _buildPlanCard(plan, isSharedPlan: true))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildPlanCard(TravelPlan plan, {bool isSharedPlan = false}) {
    final shouldLeave = isSharedPlan && !SimplePlanService.isPlanOwner(plan.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Navigate to plan details
          context.go('/plan-details?planId=${plan.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Left blue bar
            Container(
              width: 4,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF64B5F6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Right side buttons
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
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
                  // Delete personal/owned plans; leave shared plans owned by others.
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
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    tooltip: shouldLeave ? 'Leave plan' : 'Delete plan',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  // Chevron
                  Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMarkFinishedConfirmation(
    BuildContext context,
    TravelPlan plan,
  ) async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as finished?'),
        content: Text(
          'Move "${plan.title}" to Trip History? You can still open it from Trip History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark Finished'),
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TravelPlan plan) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Plan'),
          content: Text(
            'Are you sure you want to delete "${plan.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
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
              child: const Text('Delete'),
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
          title: const Text('Leave Plan'),
          content: Text('Are you sure you want to leave "${plan.title}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
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
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreateNewPlan(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start a new adventure',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              debugPrint('My Plans Create New Plan tapped!');
              GoRouter.of(context).push('/create-plan');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.blue[600],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Create New Plan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.blue[600],
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
