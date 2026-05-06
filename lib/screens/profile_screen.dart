import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/commuter_type_service.dart';
import 'package:halaph/services/fare_service.dart';
import 'package:halaph/models/user.dart';
import 'package:halaph/models/destination.dart';
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
  final VoidCallback? onLogout;

  const ProfileScreen({
    super.key,
    this.userProfile,
    this.favorites,
    this.onSettingsTap,
    this.onTripHistoryTap,
    this.onViewAllFavoritesTap,
    this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final FriendService _friendService = FriendService();
  final CommuterTypeService _commuterTypeService = CommuterTypeService();
  StreamSubscription<firebase_auth.User?>? _authSubscription;
  User? _user;
  String? _myCode;
  bool _isUploadingProfilePicture = false;
  PassengerType _commuterType = PassengerType.regular;
  bool _isSavingCommuterType = false;
  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCommuterType();
    _authSubscription =
        firebase_auth.FirebaseAuth.instance.userChanges().listen((_) {
      if (!mounted) return;
      CommuterTypeService().clearCache();
      setState(() {
        _user = null;
        _myCode = null;
        _commuterType = PassengerType.regular;
      });
      _loadUser();
      _loadCommuterType();
    });
  }

  Future<void> _loadCommuterType() async {
    final commuterType =
        await _commuterTypeService.loadCommuterType(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _commuterType = commuterType;
    });
  }

  Future<void> _updateCommuterType(PassengerType type) async {
    final normalized = CommuterTypeService.normalize(type);
    setState(() {
      _commuterType = normalized;
      _isSavingCommuterType = true;
    });

    await _commuterTypeService.saveCommuterType(normalized);

    if (!mounted) return;
    setState(() {
      _isSavingCommuterType = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Commuter type set to ${CommuterTypeService.labelFor(normalized)}.',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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
        avatarUrl: _user?.avatarUrl,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => safeNavigateBack(context),
              )
            : null,
        title: Text(
          'My Profile',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54, size: 24),
            onPressed: widget.onSettingsTap ??
                () {
                  GoRouter.of(context).push('/settings');
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
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildCommuterTypeSection(),
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

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: _pickAndUploadProfilePicture,
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
                  onTap: _pickAndUploadProfilePicture,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Theme.of(context).cardColor, width: 3),
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _userProfile.email,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCommuterTypeSection() {
    final options = <PassengerType>[
      PassengerType.regular,
      PassengerType.student,
      PassengerType.senior,
      PassengerType.pwd,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CommuterTypeService.iconFor(_commuterType),
                color: const Color(0xFF1976D2),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Commuter Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (_isSavingCommuterType)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    CommuterTypeService.labelFor(_commuterType),
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This is used as your default fare type in route estimates.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((type) {
              final selected =
                  CommuterTypeService.normalize(type) == _commuterType;
              return ChoiceChip(
                selected: selected,
                label: Text(CommuterTypeService.labelFor(type)),
                avatar: Icon(
                  CommuterTypeService.iconFor(type),
                  size: 16,
                  color: selected ? Colors.white : const Color(0xFF1976D2),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.grey[800],
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: const Color(0xFF1976D2),
                backgroundColor: const Color(0xFFF5F9FF),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF1976D2)
                      : const Color(0xFFBBDEFB),
                ),
                onSelected: _isSavingCommuterType
                    ? null
                    : (_) => _updateCommuterType(type),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTripHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onTripHistoryTap ??
            () {
              GoRouter.of(context).push('/trip-history');
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
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
                Text(
                  'Trip History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
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
              title: Text('Logout'),
              content: Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
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
        label: Text(
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
        label: Text('Accounts'),
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

  Future<void> _pickAndUploadProfilePicture() async {
    if (_isUploadingProfilePicture) return;

    setState(() => _isUploadingProfilePicture = true);

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image == null || !mounted) return;

      final user = await _auth.getCurrentUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Please log in before updating your profile photo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      try {
        final imageBytes = await image.readAsBytes();
        final contentType = _contentTypeForPickedImage(image);
        final extension = _extensionForContentType(contentType);
        final fileName = _profilePictureFileName(user, extension);

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child(fileName);

        await storageRef.putData(
          imageBytes,
          SettableMetadata(contentType: contentType),
        );
        final downloadUrl = await storageRef.getDownloadURL();

        final updatedUser = await _auth.updateProfile(avatarUrl: downloadUrl);
        if (updatedUser != null && mounted) {
          setState(() {
            _user = updatedUser;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile picture updated!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } on FirebaseException catch (e) {
        final code = e.code.toLowerCase();
        if (code.contains('bucket-not-found') ||
            code.contains('unauthorized') ||
            code.contains('permission-denied')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Firebase Storage is not ready or permission was denied.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfilePicture = false);
      }
    }
  }

  String _contentTypeForPickedImage(XFile image) {
    final name = image.name.toLowerCase();
    final path = image.path.toLowerCase();
    if (name.endsWith('.png') || path.endsWith('.png')) {
      return 'image/png';
    }
    if (name.endsWith('.heic') ||
        path.endsWith('.heic') ||
        name.endsWith('.heif') ||
        path.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  String _extensionForContentType(String contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/heic':
        return 'heic';
      default:
        return 'jpg';
    }
  }

  String _profilePictureFileName(User user, String extension) {
    final identity = (user.email.isNotEmpty ? user.email : 'user')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'profile_${identity}_$timestamp.$extension';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
