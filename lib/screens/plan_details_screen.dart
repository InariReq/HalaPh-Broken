import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/models/friend.dart';
import 'package:halaph/models/plan.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/screens/add_place_screen.dart';
import 'package:halaph/screens/friends_screen.dart';

class DestinationData {
  final Destination destination;
  final int fromDay;
  final int fromIndex;

  DestinationData({
    required this.destination,
    required this.fromDay,
    required this.fromIndex,
  });
}

class PlanDetailsScreen extends StatefulWidget {
  final String? planId;

  const PlanDetailsScreen({super.key, this.planId});

  @visibleForTesting
  static List<String> collaboratorCodesForParticipants({
    required Iterable<String> participantUids,
    required String ownerUid,
    required Iterable<Friend> friends,
  }) {
    final participantSet = participantUids
        .map((uid) => uid.trim())
        .where((uid) => uid.isNotEmpty && uid != ownerUid)
        .toSet();

    final codes = <String>[];
    for (final friend in friends) {
      final friendUid = friend.uid?.trim();
      final friendCode = friend.code.trim();
      if (friendCode.isEmpty) continue;
      if ((friendUid != null && participantSet.contains(friendUid)) ||
          participantSet.contains(friendCode)) {
        codes.add(friendCode);
      }
    }
    return codes.toSet().toList();
  }

  @override
  State<PlanDetailsScreen> createState() => _PlanDetailsScreenState();
}

class _PlanDetailsScreenState extends State<PlanDetailsScreen> {
  final FriendService _friendService = FriendService();
  TravelPlan? _plan;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  final _titleController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  Map<int, List<Destination>> _itinerary = {};
  Map<String, String> _destinationStartTimes = {};
  Map<String, String> _destinationEndTimes = {};

  bool get _canEditPlan =>
      _plan != null && SimplePlanService.canEditPlan(_plan!.id);

  bool get _canManageCollaborators =>
      _plan != null && SimplePlanService.isPlanOwner(_plan!.id);

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    if (widget.planId == null || widget.planId!.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _plan = null;
        _isLoading = false;
      });
      return;
    }

    try {
      unawaited(_friendService.getMyCode());
      await SimplePlanService.initialize().timeout(const Duration(seconds: 10));

      _plan = SimplePlanService.getPlanById(widget.planId!);

      if (_plan == null) {
        try {
          final myCode = await _friendService.getMyCode().catchError((_) => '');
          _plan = await SimplePlanService.joinSharedPlan(
            widget.planId!,
            participantCode: myCode,
          ).timeout(const Duration(seconds: 10), onTimeout: () => null);
        } catch (e) {
          // Handle permission denied or other Firestore errors
          debugPrint('Plan access error: $e');
          if (!mounted) return;
          setState(() {
            _plan = null;
            _isLoading = false;
          });
          final errorString = e.toString();
          if (errorString.contains('permission-denied') ||
              errorString.contains('permission-denied')) {
            _showError('You do not have permission to view this plan.');
          }
          return;
        }
      }

      if (_plan != null) {
        _titleController.text = _plan!.title;
        _startDate = _plan!.startDate;
        _endDate = _plan!.endDate;

        _itinerary = {};
        _destinationStartTimes = {};
        _destinationEndTimes = {};

        for (final dayIt in _plan!.itinerary) {
          final dayNum = dayIt.date.difference(_plan!.startDate).inDays + 1;
          _itinerary[dayNum] = dayIt.items.map((i) => i.destination).toList();

          for (final item in dayIt.items) {
            _destinationStartTimes[item.destination.id] = _formatTimeOfDay(
              item.startTime,
            );
            _destinationEndTimes[item.destination.id] = _formatTimeOfDay(
              item.endTime,
            );
          }
        }
      }
    } catch (error) {
      debugPrint('Plan details load failed: $error');
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _manageCollaborators() async {
    if (_plan == null) return;
    if (!_canManageCollaborators) {
      _showError('Only the plan owner can manage collaborators.');
      return;
    }
    final friends = await _friendService.getFriends();
    if (!mounted) return;
    final initiallySelected =
        PlanDetailsScreen.collaboratorCodesForParticipants(
      participantUids: _plan!.participantUids,
      ownerUid: _plan!.createdBy,
      friends: friends,
    );
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => FriendsScreen(
          selectionMode: true,
          initialSelectedCodes: initiallySelected,
        ),
      ),
    );
    if (selected == null) return;
    // Use selected codes directly; membership will be resolved to UIDs on save
    final selectedCodes = selected
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toList();
    final success = await SimplePlanService.updatePlanParticipants(
      planId: _plan!.id,
      participantUids: selectedCodes,
    );
    if (!mounted) return;
    if (!success) {
      _showError('Failed to update collaborators');
      return;
    }
    final updatedPlan = SimplePlanService.getPlanById(_plan!.id);
    setState(() {
      _plan = updatedPlan;
    });
    _showSuccess('Collaborators updated');
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _savePlanChanges() async {
    if (_plan == null) return;
    if (!_canEditPlan) {
      _showError('You only have viewer access to this plan.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Validate input
      if (_titleController.text.trim().isEmpty) {
        _showError('Please enter a plan title');
        return;
      }

      if (_startDate == null || _endDate == null) {
        _showError('Please select valid dates');
        return;
      }

      // Update the plan using the service
      if (_plan == null) return;
      final success = await SimplePlanService.updatePlan(
        planId: _plan!.id,
        title: _titleController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        itinerary: _itinerary,
        destinationTimes: _destinationStartTimes,
        destinationEndTimes: _destinationEndTimes,
        bannerImage: _plan!.bannerImage,
      );

      if (success) {
        _showSuccess('Plan updated successfully!');

        // Reload the plan from service to get the latest data including banner image
        final updatedPlan = SimplePlanService.getPlanById(_plan!.id);
        if (updatedPlan != null) {
          setState(() {
            _plan = updatedPlan;
            _isEditing = false;
          });
        }

        // Navigate to My Plans
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          context.go('/my-plans');
        }
      } else {
        _showError('Failed to update plan');
      }
    } catch (e) {
      _showError('Failed to update plan');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.go('/'),
        ),
        actions: [
          if (!_isEditing && _canEditPlan)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.ios_share, color: Colors.black),
              onPressed: _plan == null
                  ? null
                  : () => context.push(
                        '/share-plan?planId=${Uri.encodeComponent(_plan!.id)}',
                      ),
            ),
          if (!_isEditing &&
              _plan != null &&
              SimplePlanService.isPlanOwner(_plan!.id))
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _showPlanDeleteConfirmation();
              },
            ),
          if (!_isEditing &&
              _plan != null &&
              SimplePlanService.isPlanParticipant(_plan!.id))
            TextButton(
              onPressed: _leavePlan,
              child: const Text('Leave', style: TextStyle(color: Colors.red)),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                });
                _loadPlan(); // Reset to original data
              },
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _savePlanChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
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
    );
  }

  Widget _buildContent() {
    if (_plan == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
              const SizedBox(height: 24),
              Text(
                'Plan Not Found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The plan you\'re looking for doesn\'t exist or may have been deleted.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/my-plans'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Back to My Plans',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  _buildHeroSection(),
                  _buildActionButtons(),
                  _buildItinerarySection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getBannerImageUrl() {
    final banner = _plan?.bannerImage;
    if (banner != null && banner.isNotEmpty) {
      return banner;
    }
    if (_plan != null &&
        _plan!.itinerary.isNotEmpty &&
        _plan!.itinerary.first.items.isNotEmpty) {
      return _plan!.itinerary.first.items.first.destination.imageUrl;
    }
    return '';
  }

  Widget _buildBannerImage() {
    final imagePath = _getBannerImageUrl();
    if (imagePath.isEmpty) return _buildFallbackBanner();

    // Check if it's a local file path
    if (imagePath.startsWith('/') || imagePath.contains('\\')) {
      return Image.file(
        File(imagePath),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackBanner();
        },
      );
    }

    // Network image
    return Image.network(
      imagePath,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildFallbackBanner();
      },
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1976D2),
            Color(0xFF03A9F4),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 54,
          color: Colors.white.withValues(alpha: 0.72),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      height: 224,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBannerImage(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isEditing)
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Plan Title',
                        hintStyle: TextStyle(
                          color: Colors.white70,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else
                    Text(
                      _plan?.title ?? 'Untitled Plan',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.05,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _plan?.formattedDateRange ?? 'No dates set',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

  Widget _buildActionButtons() {
    final canManageCollaborators = _canManageCollaborators;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isEditing ? _addLocations : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing ? Colors.blue[600] : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Add Locations',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _isEditing && canManageCollaborators
                  ? _manageCollaborators
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _isEditing && canManageCollaborators
                    ? Colors.blue[700]
                    : Colors.grey,
                side: BorderSide(
                  color: _isEditing && canManageCollaborators
                      ? Colors.blue.shade300
                      : Colors.grey,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_add, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _plan == null
                        ? 'Add Friends'
                        : 'Friends (${(_plan!.participantUids.toSet().length - 1).clamp(0, 99)})',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasValidPlanDateRange {
    final plan = _plan;
    if (plan == null) return false;
    return !plan.endDate.isBefore(plan.startDate);
  }

  void _showEditDateRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Set a valid plan date range before adding places.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _defaultDestinationTimeLabel({int offsetHours = 0}) {
    final time = DateTime.now().add(Duration(hours: offsetHours));
    final hour = time.hour;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  Future<void> _addLocations() async {
    if (!_hasValidPlanDateRange) {
      _showEditDateRequiredMessage();
      return;
    }

    if (_plan == null || !_canEditPlan) return;
    final dayNumber = 1;
    final result = await Navigator.push<Destination>(
      context,
      MaterialPageRoute(
        builder: (context) => AddPlaceScreen(targetDay: dayNumber),
      ),
    );

    if (result != null) {
      if (!mounted) return;
      setState(() {
        _itinerary[dayNumber] ??= [];
        _itinerary[dayNumber]!.add(result);
        _destinationStartTimes[result.id] = _defaultDestinationTimeLabel();
        _destinationEndTimes[result.id] =
            _defaultDestinationTimeLabel(offsetHours: 1);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} added to Day $dayNumber')),
      );
    }
  }

  void _removeDestinationFromPlan(Destination destination, int dayNumber) {
    if (!_isEditing || !_canEditPlan) return;

    setState(() {
      _itinerary[dayNumber]?.remove(destination);
      if (_itinerary[dayNumber]?.isEmpty == true) {
        _itinerary.remove(dayNumber);
      }
      _destinationStartTimes.remove(destination.id);
      _destinationEndTimes.remove(destination.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${destination.name} removed from Day $dayNumber'),
      ),
    );
  }

  void _handleDrop(DestinationData data, int toDay, int toIndex) {
    if (!_isEditing || !_canEditPlan) return;

    setState(() {
      // Remove from original position
      _itinerary[data.fromDay]!.removeAt(data.fromIndex);

      // Insert at new position
      _itinerary[toDay] ??= [];
      _itinerary[toDay]!.insert(toIndex, data.destination);

      // If moving to a different day, update the day structure
      if (data.fromDay != toDay) {
        // Ensure the original day still exists
        if (_itinerary[data.fromDay]!.isEmpty) {
          _itinerary.remove(data.fromDay);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          data.fromDay == toDay
              ? 'Moved ${data.destination.name} to position ${toIndex + 1}'
              : 'Moved ${data.destination.name} from Day ${data.fromDay} to Day $toDay',
        ),
      ),
    );
  }

  void _openDestinationDetails(Destination destination) {
    ExploreDetailsScreen.showAsBottomSheet(
      context,
      destinationId: destination.id,
      source: 'plan_details',
      destination: destination,
    );
  }

  Widget _buildItinerarySection() {
    if (_itinerary.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
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
          child: Center(
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
                    Icons.calendar_month_rounded,
                    size: 30,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No itinerary items yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                if (_isEditing)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Tap "Add Locations" to get started',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: _itinerary.keys.map((dayNumber) {
        final destinations = _itinerary[dayNumber]!;
        final dayDate = _plan?.startDate.add(Duration(days: dayNumber - 1)) ??
            DateTime.now();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5EAF3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      'Day $dayNumber',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(dayDate),
                      style: TextStyle(fontSize: 16, color: Colors.blue[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Destinations for this day
              ...destinations.asMap().entries.map((entry) {
                final destinationIndex = entry.key;
                final destination = entry.value;

                return _buildDestinationCard(
                  destination,
                  dayNumber,
                  destinationIndex,
                );
              }),

              // Add drop target at the end of the day for inserting destinations
              if (_isEditing)
                DragTarget<DestinationData>(
                  onWillAcceptWithDetails: (details) => true,
                  onAcceptWithDetails: (details) {
                    _handleDrop(details.data, dayNumber, destinations.length);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 16),
                      height: isHovering ? 60 : 40,
                      decoration: BoxDecoration(
                        color:
                            isHovering ? Colors.blue[50] : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isHovering
                            ? Border.all(color: Colors.blue[300]!)
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          size: 24,
                          color:
                              isHovering ? Colors.blue[600] : Colors.grey[400],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDestinationCard(Destination destination, int day, int index) {
    final time = _destinationStartTimes[destination.id] ??
        _defaultDestinationTimeLabel();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDestinationDetails(destination),
          child: _buildDestinationCardContent(destination, day, index, time),
        ),
      ),
    );
  }

  Widget _buildDestinationCardContent(
    Destination destination,
    int day,
    int index,
    String time,
  ) {
    if (_isEditing) {
      return _buildEditableDestinationCard(destination, day, index, time);
    } else {
      return _buildReadOnlyDestinationCard(destination, time, day, index);
    }
  }

  Widget _buildEditableDestinationCard(
    Destination destination,
    int day,
    int index,
    String time,
  ) {
    final actualTime = _formatTimeRangeForDestination(destination);

    return LongPressDraggable<DestinationData>(
      data: DestinationData(
        destination: destination,
        fromDay: day,
        fromIndex: index,
      ),
      feedback: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        elevation: 8,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 25,
                offset: const Offset(0, 12),
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: Colors.blue[300]!, width: 2),
          ),
          child: Transform.rotate(
            angle: 0.05,
            child: Opacity(
              opacity: 0.9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      color: Colors.grey[200],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: _buildDestinationImage(destination),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue[200]!,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    Icons.drag_indicator,
                    color: Colors.blue[600],
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Drop here',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Move "${destination.name}"',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      child: DragTarget<DestinationData>(
        onWillAcceptWithDetails: (details) {
          return details.data.destination.id != destination.id;
        },
        onAcceptWithDetails: (details) {
          _handleDrop(details.data, day, index);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isHovering ? Colors.blue[50] : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isHovering
                        ? Colors.blue.withValues(alpha: 0.22)
                        : Colors.blue.withValues(alpha: 0.10),
                    blurRadius: isHovering ? 24 : 22,
                    offset: Offset(0, isHovering ? 10 : 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: isHovering
                    ? Border.all(color: Colors.blue[400]!, width: 3)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image section with time overlay
                  Stack(
                    children: [
                      // Destination Image
                      Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          color: Colors.grey[200],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: _buildDestinationImage(destination),
                        ),
                      ),

                      // Time overlay
                      Positioned(
                        top: 12,
                        left: 12,
                        child: GestureDetector(
                          onTap: () => _selectTimeForDestination(destination),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.20),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Text(
                              actualTime,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Delete button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () =>
                              _removeDestinationFromPlan(destination, day),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),

                      // Location info overlay
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              destination.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              destination.location,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Action buttons section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Add Place After button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _addPlaceAfter(destination, day, index),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  'Place After',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
        },
      ),
    );
  }

  Widget _buildReadOnlyDestinationCard(
    Destination destination,
    String time,
    int day,
    int index,
  ) {
    final actualTime = _formatTimeRangeForDestination(destination);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.10),
            blurRadius: 22,
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
          // Image section with time overlay
          Stack(
            children: [
              // Destination Image
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: _buildDestinationImage(destination),
                ),
              ),

              // Time overlay - tap to edit
              Positioned(
                top: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () => _selectTimeForDestination(destination),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.20),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actualTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ),

              // Location info overlay
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.location,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action buttons section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Add Place After button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _addPlaceAfter(destination, day, index),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Place After',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _buildDestinationImage(Destination destination) {
    if (destination.imageUrl.isNotEmpty &&
        destination.imageUrl.startsWith('http')) {
      return Image.network(
        destination.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultDestinationImage(destination.category);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[100],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }
    return _buildDefaultDestinationImage(destination.category);
  }

  Future<void> _addPlaceAfter(
    Destination destination,
    int day,
    int index,
  ) async {
    if (!_hasValidPlanDateRange) {
      _showEditDateRequiredMessage();
      return;
    }

    if (!_isEditing) return;

    final result = await Navigator.push<Destination>(
      context,
      MaterialPageRoute(builder: (context) => AddPlaceScreen(targetDay: day)),
    );

    if (result != null) {
      if (!mounted) return;
      setState(() {
        _itinerary[day] ??= [];
        // Insert the new destination after the specified index
        _itinerary[day]!.insert(index + 1, result);
        // Set a default time for the new destination
        _destinationStartTimes[result.id] =
            _defaultDestinationTimeLabel(offsetHours: 1);
        _destinationEndTimes[result.id] =
            _defaultDestinationTimeLabel(offsetHours: 2);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.name} added after ${destination.name}'),
        ),
      );
    }
  }

  String _formatTimeRangeForDestination(Destination destination) {
    final start = _destinationStartTimes[destination.id] ??
        _defaultDestinationTimeLabel();
    final end =
        _destinationEndTimes[destination.id] ?? _defaultEndTimeFor(start);
    return '$start - $end';
  }

  String _defaultEndTimeFor(String startTime) {
    final (hour, minute) = _parseDisplayTime(startTime);
    return _formatDisplayTime(TimeOfDay(hour: (hour + 1) % 24, minute: minute));
  }

  (int, int) _parseDisplayTime(String value) {
    final parts = value.trim().split(RegExp(r'[:\s]+'));
    var hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 10;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final upper = value.toUpperCase();
    final isPM = upper.contains('PM');
    final isAM = upper.contains('AM');

    if (isPM && hour < 12) {
      hour += 12;
    } else if (isAM && hour == 12) {
      hour = 0;
    }

    return (hour.clamp(0, 23), minute.clamp(0, 59));
  }

  String _formatDisplayTime(TimeOfDay time) {
    final displayHour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final hourStr = displayHour.toString().padLeft(2, '0');
    final minuteStr = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hourStr:$minuteStr $period';
  }

  Future<void> _selectTimeForDestination(Destination destination) async {
    final selectedType = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        final start = _destinationStartTimes[destination.id] ??
            _defaultDestinationTimeLabel();
        final end =
            _destinationEndTimes[destination.id] ?? _defaultEndTimeFor(start);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Start Time'),
                subtitle: Text(start),
                onTap: () => Navigator.of(context).pop('start'),
              ),
              ListTile(
                leading: const Icon(Icons.stop),
                title: const Text('End Time'),
                subtitle: Text(end),
                onTap: () => Navigator.of(context).pop('end'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedType == null || !mounted) return;

    final isStart = selectedType == 'start';
    final start = _destinationStartTimes[destination.id] ??
        _defaultDestinationTimeLabel();
    final currentTime = isStart
        ? start
        : (_destinationEndTimes[destination.id] ?? _defaultEndTimeFor(start));

    final (hour, minute) = _parseDisplayTime(currentTime);
    final initialTime = TimeOfDay(hour: hour, minute: minute);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      if (!mounted) return;
      final newTime = _formatDisplayTime(picked);

      setState(() {
        if (isStart) {
          _destinationStartTimes[destination.id] = newTime;
          _destinationEndTimes[destination.id] ??= _defaultEndTimeFor(newTime);
        } else {
          _destinationEndTimes[destination.id] = newTime;
        }
      });

      final label = isStart ? 'Start time' : 'End time';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label updated to $newTime')),
      );
    }
  }

  Widget _buildDefaultDestinationImage(DestinationCategory category) {
    IconData icon;
    Color color = Colors.grey; // Default color

    switch (category) {
      case DestinationCategory.park:
        icon = Icons.park;
        color = Colors.green;
        break;
      case DestinationCategory.landmark:
        icon = Icons.location_city;
        color = Colors.teal;
        break;
      case DestinationCategory.food:
        icon = Icons.fastfood;
        color = Colors.orange;
        break;
      case DestinationCategory.activities:
        icon = Icons.sports_soccer;
        color = Colors.indigo;
        break;
      case DestinationCategory.museum:
        icon = Icons.museum;
        color = Colors.brown;
        break;
      case DestinationCategory.malls:
        icon = Icons.shopping_bag;
        color = Colors.pink;
        break;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: color.withValues(alpha: 0.1),
      child: Icon(icon, size: 48, color: color.withValues(alpha: 0.6)),
    );
  }

  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showPlanDeleteConfirmation() {
    if (_plan == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text(
          'Are you sure you want to delete "${_plan?.title ?? 'Untitled Plan'}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final plan = _plan;
              if (plan == null) return;
              final success = await SimplePlanService.deletePlan(plan.id);
              if (!mounted) return;
              if (success) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Plan deleted successfully')),
                );
                router.go('/my-plans'); // Navigate to My Plans after delete
              } else {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Failed to delete plan')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _leavePlan() async {
    if (_plan == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Plan'),
        content: Text(
          'Are you sure you want to leave "${_plan?.title ?? 'Untitled Plan'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await SimplePlanService.leavePlan(_plan!.id);
    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Left plan successfully')),
      );
      router.go('/my-plans');
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to leave plan')),
      );
    }
  }
}
