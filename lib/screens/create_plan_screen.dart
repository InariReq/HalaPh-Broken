import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/screens/add_place_screen.dart';
import 'package:halaph/screens/friends_screen.dart';
import 'package:halaph/utils/navigation_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _titleController = TextEditingController(text: 'Untitled');
  final AuthService _authService = AuthService();
  final FriendService _friendService = FriendService();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  File? _bannerImage;
  final ImagePicker _imagePicker = ImagePicker();
  final Set<String> _selectedCollaboratorCodes = <String>{};
  String? _currentUserCode;

  // Structure to hold destinations organized by day
  Map<int, List<Destination>> _itinerary = {};

  // Structure to hold times for destinations (destination_id -> time)
  final Map<String, String> _destinationTimes = {};

  // Scroll tracking for location bar
  final ScrollController _scrollController = ScrollController();
  int _currentVisibleDay = 1;
  int _currentVisibleDestination = 0;

  // Role structure for future implementation (commented for now)
  // Map<String, String> _userRoles = {'current_user': 'Editor'}; // 'Editor' or 'Viewer'

  @override
  void initState() {
    super.initState();
    _initializeUserContext();
    _loadDestinations();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializeUserContext() async {
    final myCode = await _friendService.getMyCode();
    if (!mounted) return;
    setState(() {
      _currentUserCode = myCode;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_startDate == null || _endDate == null) return;

    final days = _endDate!.difference(_startDate!).inDays + 1;
    final scrollOffset = _scrollController.offset;
    final screenHeight = MediaQuery.of(context).size.height;

    // Fixed offset - account for header spacing
    double contentStartOffset = 320; // Banner + buttons + padding
    double adjustedScrollOffset = scrollOffset - contentStartOffset;

    // If we're still in the header area
    if (adjustedScrollOffset < 0) {
      if (_currentVisibleDay != 1 || _currentVisibleDestination != 0) {
        setState(() {
          _currentVisibleDay = 1;
          _currentVisibleDestination = 0;
        });
      }
      return;
    }

    // Track by day and destination
    int currentDay = 1;
    int currentDestination = 0;
    double accumulatedHeight = 0;

    for (int day = 1; day <= days; day++) {
      final destinations = _itinerary[day] ?? [];

      // Add day header height
      accumulatedHeight += 80; // Day header height

      for (int destIndex = 0; destIndex < destinations.length; destIndex++) {
        final cardHeight =
            240; // Destination card height (160 image + 80 buttons + padding)
        final cardTop = accumulatedHeight;
        final cardBottom = accumulatedHeight + cardHeight;

        final screenCenter = adjustedScrollOffset + screenHeight * 0.5;
        if (screenCenter >= cardTop && screenCenter <= cardBottom) {
          currentDay = day;
          currentDestination = destIndex;
          break;
        }

        accumulatedHeight += cardHeight;
      }

      // Add day spacing
      if (day < days) {
        accumulatedHeight += 16; // Day card margin
      }
    }

    if (currentDay != _currentVisibleDay ||
        currentDestination != _currentVisibleDestination) {
      setState(() {
        _currentVisibleDay = currentDay;
        _currentVisibleDestination = currentDestination;
      });
    }
  }

  Future<void> _loadDestinations() async {
    // Destinations are loaded on-demand in the FutureBuilder
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _initializeItinerary();
      });
    }
  }

  void _initializeItinerary() {
    if (_startDate != null && _endDate != null) {
      final days = _endDate!.difference(_startDate!).inDays + 1;
      _itinerary = {};
      for (int i = 1; i <= days; i++) {
        _itinerary[i] = [];
      }
    }
  }

  Future<void> _pickBannerImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 400,
        imageQuality: 80,
      );

      if (image != null) {
        if (!mounted) return;
        setState(() {
          _bannerImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _addPlace(int day) async {
    final result = await Navigator.push<Destination>(
      context,
      MaterialPageRoute(builder: (context) => AddPlaceScreen(targetDay: day)),
    );

    if (result != null) {
      if (!mounted) return;
      setState(() {
        _itinerary[day] ??= [];
        _itinerary[day]!.add(result);
        _destinationTimes[result.id] = '10:30 AM';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} added to Day $day')),
      );
    }
  }

  Future<void> _addFriends() async {
    final selectedCodes = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => FriendsScreen(
          selectionMode: true,
          initialSelectedCodes: _selectedCollaboratorCodes.toList(),
        ),
      ),
    );
    if (selectedCodes == null || !mounted) return;
    setState(() {
      _selectedCollaboratorCodes
        ..clear()
        ..addAll(selectedCodes);
    });
  }

  Future<void> _addPlaceAfter(int day, int index) async {
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
        _destinationTimes[result.id] = '11:30 AM';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.name} added after position ${index + 1}'),
        ),
      );
    }
  }

  void _removeDestination(int day, int index) {
    final destination = _itinerary[day]![index];
    setState(() {
      _itinerary[day]!.removeAt(index);
      _destinationTimes.remove(destination.id);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${destination.name} removed')));
  }

  Future<void> _savePlan() async {
    // Validate dates
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return;
    }

    // Destination validation
    bool hasDestinations = false;
    for (final dayDestinations in _itinerary.values) {
      if (dayDestinations.isNotEmpty) {
        hasDestinations = true;
        break;
      }
    }

    if (!hasDestinations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one destination')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bannerImagePath = _bannerImage?.path ?? _firstDestinationImageUrl();

      final currentUserId =
          _currentUserCode ?? await _friendService.getMyCode();
      final fallbackUserId = await _authService.getCurrentUserIdentifier();

      // Save with timeout to prevent hanging
      final savedPlan =
          await SimplePlanService.savePlan(
            title: _titleController.text.trim(),
            startDate: _startDate!,
            endDate: _endDate!,
            itinerary: _itinerary,
            destinationTimes: _destinationTimes,
            createdBy: currentUserId.isNotEmpty
                ? currentUserId
                : fallbackUserId,
            participantIds: _selectedCollaboratorCodes.toList(),
            bannerImage: bannerImagePath,
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Save timed out. Please check your connection.');
            },
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan "${savedPlan.title}" saved successfully!'),
          ),
        );
        // Navigate BEFORE setting _isLoading = false (widget will unmount)
        final planId = savedPlan.id;
        setState(() {
          _isLoading = false;
        });
        context.go('/plan-details?planId=$planId');
      }
    } catch (e) {
      debugPrint('Error saving plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save plan: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _firstDestinationImageUrl() {
    for (final destinations in _itinerary.values) {
      for (final destination in destinations) {
        final imageUrl = destination.imageUrl.trim();
        if (imageUrl.isEmpty || !imageUrl.startsWith('http')) continue;
        if (_isRandomImageUrl(imageUrl)) continue;
        return imageUrl;
      }
    }
    return null;
  }

  bool _isRandomImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('picsum.photos') ||
        lower.contains('source.unsplash.com') ||
        lower.contains('randomuser.me');
  }

  Future<void> _selectTimeForDestination(Destination destination) async {
    final currentTime = _destinationTimes[destination.id] ?? '10:30 AM';
    final hour = int.parse(currentTime.split(':')[0]);
    final minute = int.parse(currentTime.split(':')[1].split(' ')[0]);
    final isPM = currentTime.contains('PM');

    final initialTime = TimeOfDay(
      hour: isPM && hour < 12
          ? hour + 12
          : (hour == 12 && !isPM)
          ? 0
          : hour,
      minute: minute,
    );

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      if (!mounted) return;
      final hourStr = pickedTime.hourOfPeriod.toString().padLeft(2, '0');
      final minuteStr = pickedTime.minute.toString().padLeft(2, '0');
      final period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
      final newTime = '$hourStr:$minuteStr $period';

      setState(() {
        _destinationTimes[destination.id] = newTime;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Time updated to $newTime')));
    }
  }

  void _handleDrop(DestinationData data, int toDay, int toIndex) {
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
        title: const Text(
          'Blank Plan',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePlan,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Create',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Banner Section with Editable Title
            _buildBannerSection(),

            // Action Buttons
            _buildActionButtons(),

            // Main Content - Circles and Cards aligned together
            _buildAlignedItinerarySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSection() {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[300],
      ),
      child: Stack(
        children: [
          // Banner Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _bannerImage != null
                ? Image.file(
                    _bannerImage!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildDefaultBanner();
                    },
                  )
                : _buildDefaultBanner(),
          ),

          // Overlay with Title and Date
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Editable Title
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Untitled',
                      hintStyle: TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Date Range Selector
                  InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getDateRangeText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Change Banner Button
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: _pickBannerImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[400]!, Colors.grey[600]!],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 50, color: Colors.white70),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _addPlace(1), // Default to Day 1
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Place',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _addFriends,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selectedCollaboratorCodes.isEmpty
                        ? 'Add Friends'
                        : 'Friends (${_selectedCollaboratorCodes.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlignedItinerarySection() {
    if (_startDate == null || _endDate == null) {
      return const Center(
        child: Text(
          'Please select a date range to start planning',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    final days = _endDate!.difference(_startDate!).inDays + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ...List.generate(days, (index) {
            final dayNumber = index + 1;

            return _buildAlignedDayCard(dayNumber);
          }),
        ],
      ),
    );
  }

  Widget _buildAlignedDayCard(int dayNumber) {
    final destinations = _itinerary[dayNumber] ?? [];

    return Column(
      children: [
        // Day header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Itinerary Day $dayNumber',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (_startDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(
                          _startDate!.add(Duration(days: dayNumber - 1)),
                        ),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Add place button for this day
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () => _addPlace(dayNumber),
                  icon: const Icon(Icons.add, color: Colors.white),
                  iconSize: 18,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Destinations with circles aligned in same Row
        if (destinations.isEmpty)
          DragTarget<DestinationData>(
            onWillAccept: (data) => data != null,
            onAccept: (data) {
              _handleDrop(data, dayNumber, 0);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isHovering ? Colors.blue[50] : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isHovering
                      ? Border.all(color: Colors.blue[300]!)
                      : null,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          isHovering
                              ? Icons.add_circle_outline
                              : Icons.place_outlined,
                          size: 32,
                          color: isHovering
                              ? Colors.blue[600]
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isHovering
                              ? 'Drop destination here'
                              : 'No places added yet',
                          style: TextStyle(
                            color: isHovering
                                ? Colors.blue[600]
                                : Colors.grey[500],
                            fontSize: 14,
                            fontWeight: isHovering
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        else
          Column(
            children: [
              ...destinations.asMap().entries.map((entry) {
                final index = entry.key;
                final destination = entry.value;
                return _buildAlignedDestinationItem(
                  destination,
                  dayNumber,
                  index,
                );
              }),
              // Add drop target at the end of the day for inserting destinations
              DragTarget<DestinationData>(
                onWillAccept: (data) => data != null,
                onAccept: (data) {
                  _handleDrop(data, dayNumber, destinations.length);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 16),
                    height: isHovering ? 60 : 40,
                    decoration: BoxDecoration(
                      color: isHovering ? Colors.blue[50] : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isHovering
                          ? Border.all(color: Colors.blue[300]!)
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add,
                        size: 24,
                        color: isHovering ? Colors.blue[600] : Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAlignedDestinationItem(
    Destination destination,
    int day,
    int index,
  ) {
    final time = _destinationTimes[destination.id] ?? '10:30 AM';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle indicator on the left
          Container(
            width: 40,
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Card on the right with enhanced drag and drop
          Expanded(
            child: LongPressDraggable<DestinationData>(
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
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(color: Colors.blue[300]!, width: 2),
                  ),
                  child: Transform.rotate(
                    angle: 0.05, // Slight rotation for drag effect
                    child: Opacity(
                      opacity: 0.9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Actual image in feedback
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
                              child:
                                  destination.imageUrl.isNotEmpty &&
                                      destination.imageUrl.startsWith('http')
                                  ? Image.network(
                                      destination.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return _buildDefaultDestinationImage(
                                              destination.category,
                                            );
                                          },
                                    )
                                  : _buildDefaultDestinationImage(
                                      destination.category,
                                    ),
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
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: DragTarget<DestinationData>(
                onWillAccept: (data) {
                  return data != null && data.destination.id != destination.id;
                },
                onAccept: (data) {
                  _handleDrop(data, day, index);
                },
                onMove: (details) {
                  // Optional: Add haptic feedback or other interactions
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
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: isHovering
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.black.withOpacity(0.08),
                            blurRadius: isHovering ? 16 : 12,
                            offset: Offset(0, isHovering ? 6 : 4),
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
                                  child:
                                      destination.imageUrl.isNotEmpty &&
                                          destination.imageUrl.startsWith(
                                            'http',
                                          )
                                      ? Image.network(
                                          destination.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return _buildDefaultDestinationImage(
                                                  destination.category,
                                                );
                                              },
                                        )
                                      : _buildDefaultDestinationImage(
                                          destination.category,
                                        ),
                                ),
                              ),

                              // Gradient overlay
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(12),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Time overlay
                              Positioned(
                                top: 12,
                                left: 12,
                                child: GestureDetector(
                                  onTap: () =>
                                      _selectTimeForDestination(destination),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          time,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 12,
                                        ),
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
                                    onPressed: () => _addPlaceAfter(day, index),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      side: const BorderSide(
                                        color: Colors.blue,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('+ Place After'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Delete button
                                OutlinedButton(
                                  onPressed: () =>
                                      _removeDestination(day, index),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Icon(Icons.delete, size: 16),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSynchronizedLocationBar() {
    if (_startDate == null || _endDate == null) {
      return const SizedBox.shrink();
    }

    final days = _endDate!.difference(_startDate!).inDays + 1;

    return SingleChildScrollView(
      controller: _scrollController, // Use the same scroll controller
      child: Column(
        children: [
          // Match the exact same structure as main content
          const SizedBox(height: 16), // Match banner margin
          // Create circles for each day's destinations
          ...List.generate(days, (dayIndex) {
            final dayNumber = dayIndex + 1;
            final destinations = _itinerary[dayNumber] ?? [];

            return [
              // Day header - match exact height of day header
              const SizedBox(height: 80), // Day header height
              // Circles for this day's destinations - aligned with card centers
              ...List.generate(destinations.length, (destIndex) {
                final destination = destinations[destIndex];
                final isCurrent =
                    dayNumber == _currentVisibleDay &&
                    destIndex == _currentVisibleDestination;
                final isLastDest = destIndex == destinations.length - 1;

                return Column(
                  children: [
                    // Circle positioned at center of destination card (80px from start of card)
                    const SizedBox(height: 80), // Center of 160px image
                    Center(
                      child: Container(
                        width: isCurrent ? 20 : 16,
                        height: isCurrent ? 20 : 16,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: isCurrent
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    // Remaining card height to match total card height
                    const SizedBox(
                      height: 80,
                    ), // Rest of card (160 total - 80 to center = 80)
                    // Card bottom margin
                    const SizedBox(height: 16),
                    // Connecting line between cards
                    if (!isLastDest)
                      Container(
                        width: 2,
                        height: 16, // Card margin
                        color: Colors.grey[300],
                      ),
                  ],
                );
              }),

              // Day spacing between day cards
              if (dayNumber < days)
                const SizedBox(height: 16), // Day card margin
            ];
          }).expand((element) => element),

          const SizedBox(height: 100), // Bottom spacing
        ],
      ),
    );
  }

  Widget _buildDayCard(int dayNumber) {
    final destinations = _itinerary[dayNumber] ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DragTarget<DestinationData>(
        onWillAccept: (data) {
          return data != null && data.fromDay != dayNumber;
        },
        onAccept: (data) {
          _handleDrop(
            data,
            dayNumber,
            destinations.length,
          ); // Add to end of day
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Container(
            decoration: BoxDecoration(
              color: isHovering ? Colors.blue[50] : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Itinerary Day $dayNumber',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            if (_startDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(
                                  _startDate!.add(
                                    Duration(days: dayNumber - 1),
                                  ),
                                ),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Add place button for this day
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: () => _addPlace(dayNumber),
                          icon: const Icon(Icons.add, color: Colors.white),
                          iconSize: 18,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Drop zone indicator for empty days
                if (destinations.isEmpty && isHovering)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue[300]!,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: Colors.blue,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Drop destination here',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (destinations.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'No places added yet',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: destinations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final destination = entry.value;
                        return _buildDestinationItem(
                          destination,
                          dayNumber,
                          index,
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDestinationItem(Destination destination, int day, int index) {
    final time = _destinationTimes[destination.id] ?? '10:30 AM';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Main destination card with drag and drop (entire card draggable)
          LongPressDraggable<DestinationData>(
            data: DestinationData(
              destination: destination,
              fromDay: day,
              fromIndex: index,
            ),
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Opacity(
                  opacity: 0.8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image in feedback with overlay (longer height)
                      Container(
                        width: double.infinity,
                        height: 140, // Slightly shorter for feedback
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[300]!, Colors.blue[600]!],
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              // Background gradient
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue[300]!,
                                      Colors.blue[600]!,
                                    ],
                                  ),
                                ),
                              ),
                              // Gradient overlay for text visibility
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Time overlay
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    time,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              // Location info overlay
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      destination.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      destination.location,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            childWhenDragging: DragTarget<DestinationData>(
              onWillAccept: (data) {
                return data != null && data.destination.id != destination.id;
              },
              onAccept: (data) {
                _handleDrop(data, day, index);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.drag_indicator,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Dragging ${destination.name}...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            child: DragTarget<DestinationData>(
              onWillAccept: (data) {
                return data != null && data.destination.id != destination.id;
              },
              onAccept: (data) {
                _handleDrop(data, day, index);
              },
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: isHovering ? Colors.blue[50] : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                      border: isHovering
                          ? Border.all(color: Colors.blue[300]!, width: 2)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image section with time overlay, location info (no drag handle)
                        Stack(
                          children: [
                            // Destination Image (taller to match image)
                            Container(
                              width: double.infinity,
                              height: 160, // Increased to match image design
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
                                child:
                                    destination.imageUrl.isNotEmpty &&
                                        destination.imageUrl.startsWith('http')
                                    ? Image.network(
                                        destination.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return _buildDefaultDestinationImage(
                                                destination.category,
                                              );
                                            },
                                      )
                                    : _buildDefaultDestinationImage(
                                        destination.category,
                                      ),
                              ),
                            ),

                            // Gradient overlay for better text visibility
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(12),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Time overlay (editable)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: GestureDetector(
                                onTap: () =>
                                    _selectTimeForDestination(destination),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        time,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Hidden alignment circle for location bar tracking
                            Positioned(
                              top: 80, // Center of 160px image
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  key: ValueKey('alignment_${destination.id}'),
                                  width: 1,
                                  height: 1,
                                  color: Colors.transparent,
                                ),
                              ),
                            ),

                            // Location name and address overlay
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
                                  onPressed: () => _addPlaceAfter(day, index),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                    side: const BorderSide(color: Colors.blue),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('+ Place After'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Delete button
                              OutlinedButton(
                                onPressed: () => _removeDestination(day, index),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Icon(Icons.delete, size: 16),
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
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultDestinationImage(DestinationCategory category) {
    Color startColor, endColor;
    IconData iconData;

    switch (category) {
      case DestinationCategory.park:
        startColor = const Color(0xFF81C784);
        endColor = const Color(0xFF4CAF50);
        iconData = Icons.park;
        break;
      case DestinationCategory.landmark:
        startColor = const Color(0xFF64B5F6);
        endColor = const Color(0xFF2196F3);
        iconData = Icons.location_city;
        break;
      case DestinationCategory.food:
        startColor = const Color(0xFFFFB74D);
        endColor = const Color(0xFFFF9800);
        iconData = Icons.restaurant;
        break;
      case DestinationCategory.activities:
        startColor = const Color(0xFFBA68C8);
        endColor = const Color(0xFF9C27B0);
        iconData = Icons.beach_access;
        break;
      case DestinationCategory.museum:
        startColor = const Color(0xFFF06292);
        endColor = const Color(0xFFE91E63);
        iconData = Icons.museum;
        break;
      case DestinationCategory.market:
        startColor = const Color(0xFF4DB6AC);
        endColor = const Color(0xFF009688);
        iconData = Icons.shopping_cart;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(iconData, size: 24, color: Colors.white)),
    );
  }

  String _getDateRangeText() {
    if (_startDate == null || _endDate == null) {
      return 'Set date';
    }

    final startFormat = '${_startDate!.month}/${_startDate!.day}';
    final endFormat = '${_endDate!.month}/${_endDate!.day}';

    if (_startDate!.year == _endDate!.year) {
      return '$startFormat - $endFormat';
    } else {
      return '$startFormat/${_startDate!.year} - $endFormat/${_endDate!.year}';
    }
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
    return '${months[date.month - 1]} ${date.day}';
  }
}
