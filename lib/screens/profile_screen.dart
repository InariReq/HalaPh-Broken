import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/destination_service.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/services/favorites_service.dart';
import 'package:halaph/services/favorites_notifier.dart';
import 'package:halaph/services/commuter_type_service.dart';
import 'package:halaph/services/fare_service.dart';
import 'package:halaph/models/user.dart';
import 'package:halaph/models/destination.dart';
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
  StreamSubscription<void>? _favoritesSubscription;
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
    _loadFavoritesFromService();
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
      _loadFavoritesFromService();
    });
    _favoritesSubscription = FavoritesNotifier().onFavoritesChanged.listen((_) {
      _loadFavoritesFromService();
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

  final List<FavoritePlace> _favoritePlaces = [];

  List<FavoritePlace> get _favorites {
    if (widget.favorites != null) return widget.favorites!;
    if (_favoritePlaces.isNotEmpty) return _favoritePlaces;
    return const [];
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
        color: Colors.white,
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
              const Expanded(
                child: Text(
                  'Commuter Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
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
                    style: const TextStyle(
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
              color: Colors.grey[600],
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
              onPressed: widget.onViewAllFavoritesTap ??
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
                          child: favorite.imageUrl != null &&
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
        onPressed: widget.onTripHistoryTap ??
            () {
              GoRouter.of(context).push('/trip-history');
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
    _favoritesSubscription?.cancel();
    super.dispose();
  }
}
