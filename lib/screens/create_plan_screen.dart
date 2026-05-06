import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/services/simple_plan_service.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/screens/add_place_screen.dart';
import 'package:halaph/screens/friends_screen.dart';
import 'package:halaph/utils/navigation_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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
  final Map<String, String> _destinationStartTimes = {};
  final Map<String, String> _destinationEndTimes = {};

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

  Future<File> _copyBannerImageToPermanentStorage(File source) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final bannerDir = Directory('${documentsDir.path}/plan_banners');

    if (!await bannerDir.exists()) {
      await bannerDir.create(recursive: true);
    }

    final extension = source.path.split('.').last.toLowerCase();
    final safeExtension =
        extension.isEmpty || extension.length > 5 ? 'jpg' : extension;
    final fileName =
        'plan_banner_${DateTime.now().microsecondsSinceEpoch}.$safeExtension';

    return source.copy('${bannerDir.path}/$fileName');
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
        final permanentBanner = await _copyBannerImageToPermanentStorage(
          File(image.path),
        );

        if (!mounted) return;
        setState(() {
          _bannerImage = permanentBanner;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  bool get _hasPlanDateRangeSelected =>
      _startDate != null &&
      _endDate != null &&
      !_endDate!.isBefore(_startDate!);

  void _showDateRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Set a start date and end date before adding places.'),
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

  Future<void> _addPlace(int day) async {
    if (!_hasPlanDateRangeSelected) {
      _showDateRequiredMessage();
      return;
    }

    final result = await Navigator.push<Destination>(
      context,
      MaterialPageRoute(builder: (context) => AddPlaceScreen(targetDay: day)),
    );

    if (result != null) {
      if (!mounted) return;
      setState(() {
        _itinerary[day] ??= [];
        _itinerary[day]!.add(result);
        _destinationStartTimes[result.id] = _defaultDestinationTimeLabel();
        _destinationEndTimes[result.id] =
            _defaultDestinationTimeLabel(offsetHours: 1);
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
    if (!_hasPlanDateRangeSelected) {
      _showDateRequiredMessage();
      return;
    }

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
          content: Text('${result.name} added after position ${index + 1}'),
        ),
      );
    }
  }

  void _removeDestination(int day, int index) {
    final destination = _itinerary[day]![index];
    setState(() {
      _itinerary[day]!.removeAt(index);
      _destinationStartTimes.remove(destination.id);
      _destinationEndTimes.remove(destination.id);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${destination.name} removed')));
  }

  Future<String> _uploadBannerImageIfPossible({
    required File bannerFile,
    required String ownerId,
  }) async {
    try {
      final cleanOwnerId = ownerId.trim().isEmpty ? 'unknown' : ownerId.trim();
      final extension = bannerFile.path.split('.').last.toLowerCase();
      final safeExtension =
          extension.isEmpty || extension.length > 5 ? 'jpg' : extension;
      final fileName =
          'plan_banner_${DateTime.now().microsecondsSinceEpoch}.$safeExtension';

      final ref = FirebaseStorage.instance
          .ref()
          .child('plan_banners')
          .child(cleanOwnerId)
          .child(fileName);

      final metadata = SettableMetadata(
        contentType: _contentTypeForExtension(safeExtension),
        customMetadata: {
          'ownerId': cleanOwnerId,
          'source': 'plan_banner',
        },
      );

      final uploadTask = await ref
          .putFile(bannerFile, metadata)
          .timeout(const Duration(seconds: 20));

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('Plan banner uploaded to Firebase Storage.');
      return downloadUrl;
    } catch (error) {
      debugPrint('Plan banner upload failed, using local file path: $error');
      return bannerFile.path;
    }
  }

  String _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
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
      final currentUserId =
          _currentUserCode ?? await _friendService.getMyCode();
      final fallbackUserId = await _authService.getCurrentUserIdentifier();
      final creatorId =
          currentUserId.isNotEmpty ? currentUserId : fallbackUserId;
      final storageOwnerId =
          FirebaseAuth.instance.currentUser?.uid ?? creatorId;

      final bannerImagePath = _bannerImage == null
          ? _firstDestinationImageUrl()
          : await _uploadBannerImageIfPossible(
              bannerFile: _bannerImage!,
              ownerId: storageOwnerId,
            );

      // Save with timeout to prevent hanging
      final savedPlan = await SimplePlanService.savePlan(
        title: _titleController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        itinerary: _itinerary,
        destinationTimes: _destinationStartTimes,
        destinationEndTimes: _destinationEndTimes,
        createdBy: creatorId,
        participantUids: _selectedCollaboratorCodes.toList(),
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
      final newTime = _formatDisplayTime(pickedTime);

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
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6)
                ],
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
                        color: Colors.white.withValues(alpha: 0.2),
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
                  color: Colors.black.withValues(alpha: 0.5),
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
                  onPressed: _hasPlanDateRangeSelected
                      ? () => _addPlace(1)
                      : _showDateRequiredMessage, // Default to Day 1
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
                  onPressed: _hasPlanDateRangeSelected
                      ? () => _addPlace(dayNumber)
                      : _showDateRequiredMessage,
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
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              _handleDrop(details.data, dayNumber, 0);
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
                  border:
                      isHovering ? Border.all(color: Colors.blue[300]!) : null,
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
                          color:
                              isHovering ? Colors.blue[600] : Colors.grey[400],
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
    final time = _formatTimeRangeForDestination(destination);

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
                        color: Colors.black.withValues(alpha: 0.4),
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
                              child: destination.imageUrl.isNotEmpty &&
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
                onWillAcceptWithDetails: (details) {
                  return details.data.destination.id != destination.id;
                },
                onAcceptWithDetails: (details) {
                  _handleDrop(details.data, day, index);
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
                                ? Colors.blue.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.08),
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
                                  child: destination.imageUrl.isNotEmpty &&
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
                                        Colors.black.withValues(alpha: 0.7),
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
      case DestinationCategory.malls:
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
