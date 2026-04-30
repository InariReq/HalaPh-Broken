import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/models/user.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/models/friend.dart';
import 'package:halaph/screens/explore_details_screen.dart';
import 'package:halaph/utils/navigation_utils.dart';

// Data models for easier implementation
class UserProfile {
  final String name;
  final String email;
  final String userCode;
  final String? avatarUrl;

  UserProfile({
    required this.name,
    required this.email,
    required this.userCode,
    this.avatarUrl,
  });
}

class FavoritePlace {
  final String id;
  final String name;
  final String location;
  final String type;
  final String? imageUrl;
  final Destination? destination;

  FavoritePlace({
    required this.id,
    required this.name,
    this.location = '',
    required this.type,
    this.imageUrl,
    this.destination,
  });
}

class ProfileScreen extends StatefulWidget {
  final UserProfile? userProfile;
  final List<FavoritePlace>? favorites;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onTripHistoryTap;
  final VoidCallback? onViewAllFavoritesTap;
  final Function(String)? onAddFriend;
  final VoidCallback? onLogout;
  final Function(String)? onEditProfile;

  const ProfileScreen({
    super.key,
    this.userProfile,
    this.favorites,
    this.onSettingsTap,
    this.onTripHistoryTap,
    this.onViewAllFavoritesTap,
    this.onAddFriend,
    this.onLogout,
    this.onEditProfile,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _friendCodeController = TextEditingController();
  final AuthService _auth = AuthService();
  final FriendService _friendService = FriendService();
  StreamSubscription<void>? _favoritesSubscription;
  User? _user;
  String? _myCode;
  int _selectedTab = 0;
  bool _friendsLoading = true;
  List<Friend> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadFavoritesFromService();
    _loadFriends();
    _favoritesSubscription = FavoritesNotifier().onFavoritesChanged.listen((_) {
      _loadFavoritesFromService();
    });
  }

  Future<void> _loadUser() async {
    try {
      final results = await Future.wait<dynamic>([
        _auth.getCurrentUser(),
        _friendService.getMyCode(),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as User?;
        _myCode = results[1] as String;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _myCode ??= 'HP-0000');
    }
  }

  UserProfile get _userProfile =>
      widget.userProfile ??
      UserProfile(
        name: _user?.name ?? 'User',
        email: _user?.email ?? '',
        userCode: _myCode ?? 'HP-0000',
      );

  final List<FavoritePlace> _favoritePlaces = [];

  List<FavoritePlace> get _favorites {
    if (widget.favorites != null) return widget.favorites!;
    if (_favoritePlaces.isNotEmpty) return _favoritePlaces;
    return const [];
  }

  Future<void> _handleAddFriend(String code) async {
    final result = await _friendService.addFriendByCode(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green[600] : Colors.red,
      ),
    );
    if (result.success) {
      _friendCodeController.clear();
      await _loadFriends();
    }
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendService.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _friendsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _friendsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => safeNavigateBack(context),
              )
            : null,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54, size: 24),
            onPressed:
                widget.onSettingsTap ??
                () {
                  GoRouter.of(context).push('/accounts');
                },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildProfileSection(),
              const SizedBox(height: 20),
              _buildProfileTabs(),
              const SizedBox(height: 20),
              if (_selectedTab == 0) ...[
                _buildUserCodeSection(),
                const SizedBox(height: 20),
                _buildFavoritesSection(),
                const SizedBox(height: 20),
                _buildTripHistoryButton(),
                const SizedBox(height: 20),
                _buildLogoutButton(),
                const SizedBox(height: 20),
                _buildAccountsButton(),
              ] else ...[
                _buildFriendsTab(),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadFavoritesFromService() async {
    try {
      final service = FavoritesService();
      final destinations = await service.getFavoriteDestinations(
        forceRefresh: true,
      );
      final ids = await service.getFavorites();
      final loaded = <FavoritePlace>[];
      final byId = {
        for (final destination in destinations) destination.id: destination,
      };
      for (final id in ids) {
        final destination = byId[id];
        if (destination == null) {
          loaded.add(
            FavoritePlace(
              id: id,
              name: 'Saved place',
              location: 'Details unavailable',
              type: 'Place',
            ),
          );
          continue;
        }
        loaded.add(
          FavoritePlace(
            id: id,
            name: destination.name,
            location: destination.location,
            type: DestinationService.getCategoryName(destination.category),
            imageUrl: destination.imageUrl,
            destination: destination,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _favoritePlaces.clear();
          _favoritePlaces.addAll(loaded);
        });
      }
    } catch (_) {
      // ignore and keep defaults
    }
  }

  Widget _buildProfileTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          _buildProfileTabButton('Profile', Icons.person_outline, 0),
          _buildProfileTabButton('Friends', Icons.people_outline, 1),
        ],
      ),
    );
  }

  Widget _buildProfileTabButton(String label, IconData icon, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2196F3) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAddFriendsSection(),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.people_outline, color: Color(0xFF2196F3)),
            const SizedBox(width: 8),
            const Text(
              'Your Friends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh friends',
              onPressed: _loadFriends,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_friendsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_friends.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: const Text(
              'No friends yet. Add a friend code to start planning together.',
              textAlign: TextAlign.center,
            ),
          )
        else
          Column(children: _friends.map(_buildFriendCard).toList()),
      ],
    );
  }

  Widget _buildFriendCard(Friend friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[200],
          backgroundImage: friend.avatarUrl != null
              ? NetworkImage(friend.avatarUrl!)
              : null,
          child: friend.avatarUrl == null
              ? Icon(Icons.person, color: Colors.grey[600])
              : null,
        ),
        title: Text(
          friend.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(friend.code),
        onTap: () => _showFriendProfile(friend),
        trailing: IconButton(
          tooltip: 'Unfriend',
          icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
          onPressed: () => _confirmUnfriend(friend),
        ),
      ),
    );
  }

  Future<void> _confirmUnfriend(Friend friend) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfriend'),
        content: Text('Remove ${friend.name} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unfriend', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (shouldRemove != true) return;
    await _friendService.removeFriend(friend.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${friend.name} removed')));
    await _loadFriends();
  }

  void _showFriendProfile(Friend friend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return FutureBuilder<List<FavoritePlace>>(
            future: _loadFriendFavoritePlaces(friend),
            builder: (context, snapshot) {
              final favorites = snapshot.data ?? const <FavoritePlace>[];
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: friend.avatarUrl != null
                        ? NetworkImage(friend.avatarUrl!)
                        : null,
                    child: friend.avatarUrl == null
                        ? Icon(Icons.person, size: 38, color: Colors.grey[600])
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    friend.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    friend.email?.isNotEmpty == true
                        ? '${friend.code} • ${friend.email}'
                        : friend.code,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Favorited Places',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (favorites.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'No public favorite places yet.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...favorites.map(
                      (favorite) => _buildFriendFavoriteTile(favorite),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<List<FavoritePlace>> _loadFriendFavoritePlaces(Friend friend) async {
    final destinations = await _friendService.getPublicFavoritePlaces(friend);
    if (destinations.isNotEmpty) {
      return destinations
          .take(20)
          .map((destination) {
            return FavoritePlace(
              id: destination.id,
              name: destination.name,
              location: destination.location,
              type: DestinationService.getCategoryName(destination.category),
              imageUrl: destination.imageUrl,
              destination: destination,
            );
          })
          .toList(growable: false);
    }

    final ids = await _friendService.getPublicFavoriteIds(friend);
    final favorites = <FavoritePlace>[];
    for (final id in ids.take(20)) {
      final destination = await DestinationService.getDestination(id);
      if (destination == null) {
        favorites.add(
          FavoritePlace(id: id, name: 'Saved place', type: 'Place'),
        );
        continue;
      }
      favorites.add(
        FavoritePlace(
          id: id,
          name: destination.name,
          location: destination.location,
          type: DestinationService.getCategoryName(destination.category),
          imageUrl: destination.imageUrl,
          destination: destination,
        ),
      );
    }
    return favorites;
  }

  Widget _buildFriendFavoriteTile(FavoritePlace favorite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            color: Colors.grey[200],
            child: favorite.imageUrl?.startsWith('http') == true
                ? Image.network(favorite.imageUrl!, fit: BoxFit.cover)
                : Icon(Icons.place, color: Colors.grey[600]),
          ),
        ),
        title: Text(
          favorite.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          favorite.location.isNotEmpty ? favorite.location : favorite.type,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: favorite.destination == null
            ? null
            : () {
                Navigator.pop(context);
                ExploreDetailsScreen.showAsBottomSheet(
                  context,
                  destinationId: favorite.id,
                  source: 'friend-profile',
                  destination: favorite.destination,
                );
              },
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.transparent, // Hidden box for alignment
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () => widget.onEditProfile?.call(_userProfile.name),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _userProfile.avatarUrl != null
                      ? NetworkImage(_userProfile.avatarUrl!)
                      : null,
                  child: _userProfile.avatarUrl == null
                      ? Icon(Icons.person, size: 52, color: Colors.grey[600])
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => widget.onEditProfile?.call(_userProfile.name),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _userProfile.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _userProfile.email,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCodeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // Light blue background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFBBDEFB),
        ), // Lighter blue border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR CODE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1976D2), // Darker blue text
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F9FF), // Very light blue
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF90CAF9),
                    ), // Medium blue border
                  ),
                  child: Text(
                    _userProfile.userCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0), // Dark blue text
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _userProfile.userCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Code copied to clipboard!'),
                      backgroundColor: Colors.green[600],
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Copy',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddFriendsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add, color: const Color(0xFF2196F3), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Add New Friends',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _friendCodeController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter friend\'s code (e.g. BB-0000)',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2196F3)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final friendCode = _friendCodeController.text.trim();
                  if (friendCode.isNotEmpty) {
                    widget.onAddFriend?.call(friendCode);
                    _handleAddFriend(friendCode);
                    _friendCodeController.clear();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a friend code'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your friend\'s code to add them as your travel buddy',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesSection() {
    if (_favorites.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_border, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Your Favorites',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed:
                  widget.onViewAllFavoritesTap ??
                  () {
                    GoRouter.of(context).push('/favorites');
                  },
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 174,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _favorites.length,
            itemBuilder: (context, index) {
              final favorite = _favorites[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => ExploreDetailsScreen.showAsBottomSheet(
                  context,
                  destinationId: favorite.id,
                  source: 'profile',
                  destination: favorite.destination,
                ),
                child: Container(
                  width: 148,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Container(
                          height: 82,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child:
                              favorite.imageUrl != null &&
                                  favorite.imageUrl!.startsWith('http')
                              ? Image.network(
                                  favorite.imageUrl!,
                                  width: double.infinity,
                                  height: 82,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.place,
                                      size: 30,
                                      color: Colors.grey[600],
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.place,
                                  size: 30,
                                  color: Colors.grey[600],
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              favorite.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              favorite.location,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              favorite.type,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w600,
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTripHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed:
            widget.onTripHistoryTap ??
            () {
              GoRouter.of(context).go('/my-plans');
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flight,
                  color: const Color(0xFF64B5F6), // Light blue
                  size: 18,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Trip History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final router = GoRouter.of(context);
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );

          if (shouldLogout == true) {
            if (widget.onLogout != null) {
              widget.onLogout!.call();
              return;
            }
            await _auth.logout();
            if (!mounted) return;
            router.go('/accounts');
          }
        },
        icon: const Icon(Icons.logout, size: 18),
        label: const Text(
          'Logout Account',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildAccountsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          GoRouter.of(context).push('/accounts');
        },
        icon: const Icon(Icons.account_circle),
        label: const Text('Accounts'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    _friendCodeController.dispose();
    super.dispose();
  }
}
