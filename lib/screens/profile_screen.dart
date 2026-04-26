import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/models/user.dart';

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
  final String type;
  final String? imageUrl;

  FavoritePlace({
    required this.id,
    required this.name,
    required this.type,
    this.imageUrl,
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
  User? _user;
  String? _myCode;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final results = await Future.wait<dynamic>([
      _auth.getCurrentUser(),
      _friendService.getMyCode(),
    ]);
    if (!mounted) return;
    setState(() {
      _user = results[0] as User?;
      _myCode = results[1] as String;
    });
  }

  UserProfile get _userProfile =>
      widget.userProfile ??
      UserProfile(
        name: _user?.name ?? 'User',
        email: _user?.email ?? '',
        userCode: _myCode ?? 'HP-0000',
      );

  List<FavoritePlace> get _favorites =>
      widget.favorites ??
      [
        FavoritePlace(id: '1', name: 'Place 1', type: 'Place'),
        FavoritePlace(id: '2', name: 'Place 2', type: 'Place'),
        FavoritePlace(id: '3', name: 'Place 3', type: 'Place'),
        FavoritePlace(id: '4', name: 'Place 4', type: 'Place'),
        FavoritePlace(id: '5', name: 'Place 5', type: 'Place'),
      ];

  Future<void> _handleAddFriend(String code) async {
    final result = await _friendService.addFriendByCode(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green[600] : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                  // Default action - can be overridden
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
              _buildUserCodeSection(),
              const SizedBox(height: 20),
              _buildAddFriendsSection(),
              const SizedBox(height: 20),
              _buildFavoritesSection(),
              const SizedBox(height: 20),
              _buildTripHistoryButton(),
              const SizedBox(height: 20),
              _buildLogoutButton(),
              const SizedBox(height: 20),
              _buildAccountsButton(),
              const SizedBox(height: 30),
            ],
          ),
        ),
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
            color: Colors.black.withOpacity(0.05),
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
                    // Default action
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
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _favorites.length,
            itemBuilder: (context, index) {
              final favorite = _favorites[index];
              return Container(
                width: 110,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: favorite.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                favorite.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.place,
                                    size: 28,
                                    color: Colors.grey[600],
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.place,
                              size: 28,
                              color: Colors.grey[600],
                            ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        favorite.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      favorite.type,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTripHistoryButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed:
            widget.onTripHistoryTap ??
            () {
              // Default action
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
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
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
            if (!context.mounted) return;
            context.go('/accounts');
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
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // Navigate to accounts screen
          GoRouter.of(context).go('/accounts');
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
    _friendCodeController.dispose();
    super.dispose();
  }
}
