import 'package:flutter/material.dart';
import 'package:halaph/models/destination.dart';
import 'package:halaph/models/friend.dart';
import 'package:halaph/services/friend_service.dart';
import 'package:halaph/utils/navigation_utils.dart';

class FriendsScreen extends StatefulWidget {
  final bool selectionMode;
  final List<String> initialSelectedCodes;

  const FriendsScreen({
    super.key,
    this.selectionMode = false,
    this.initialSelectedCodes = const [],
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _profileCodeController = TextEditingController();
  final FriendService _friendService = FriendService();
  final Set<String> _selectedCodes = <String>{};
  List<Friend> _members = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  String _myCode = '';
  bool _isLoading = true;
  bool _isAddingFriend = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _selectedCodes.addAll(widget.initialSelectedCodes);
    _loadData();
  }

  Future<void> _loadData() async {
    debugPrint('FriendsScreen: Loading data...');
    try {
      final myCode = await _friendService.getMyCode();
      final friends = await _friendService.getFriends();
      final requests = await _loadPendingRequests();
      debugPrint(
        'FriendsScreen: Loaded ${friends.length} friends, ${requests.length} pending requests',
      );
      if (!mounted) return;
      setState(() {
        _myCode = myCode;
        _members = friends;
        _pendingRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('FriendsScreen: Error loading data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadPendingRequests() async {
    return await _friendService.getPendingFriendRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (widget.selectionMode) {
              safePopWithResult(context, _selectedCodes.toList());
            } else {
              safeNavigateBack(context);
            }
          },
        ),
        title: const Text(
          'Friends',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (widget.selectionMode)
            TextButton(
              onPressed: () =>
                  safePopWithResult(context, _selectedCodes.toList()),
              child: const Text('Done'),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildProfileCodeSection(),
                  ),
                  _buildFriendsTabs(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _selectedTab == 0
                          ? _buildMembersSection()
                          : _buildRequestsSection(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFriendsTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          _buildTabButton('Friends', 0, _members.length),
          _buildTabButton('Requests', 1, _pendingRequests.length),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, int count) {
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.grey[700],
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? const Color(0xFF2196F3) : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Requests (${_pendingRequests.length})',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        if (_pendingRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No pending friend requests.',
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
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
              children: _pendingRequests
                  .map((request) => _buildRequestTile(request))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> request) {
    final name = request['fromName'] as String? ?? 'Unknown';
    final code = request['fromCode'] as String? ?? '';
    final avatarUrl = request['fromAvatarUrl'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Icon(Icons.person, size: 28, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _acceptFriendRequest(request),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _rejectFriendRequest(request),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _acceptFriendRequest(Map<String, dynamic> request) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _friendService.acceptFriendRequest(request);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _pendingRequests
              .removeWhere((r) => r['fromUid'] == request['fromUid']);
        });
        await _loadData();
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to accept request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectFriendRequest(Map<String, dynamic> request) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final success = await _friendService.declineFriendRequest(request);
      if (!mounted) return;
      if (success) {
        setState(() {
          _pendingRequests
              .removeWhere((r) => r['fromUid'] == request['fromUid']);
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text('Request from ${request['fromName']} rejected'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to reject request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildProfileCodeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          const Text(
            'Your Friend Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBDEFB)),
            ),
            child: Text(
              _myCode,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Friend by Code',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _profileCodeController,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Enter profile code',
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
                onPressed: _isAddingFriend ? null : _inviteFriend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isAddingFriend
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Invite',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.selectionMode ? 'Select Collaborators' : 'Members',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        if (_members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No friends yet. Add one using their code.',
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
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
              children:
                  _members.map((friend) => _buildMemberTile(friend)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberTile(Friend friend) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.selectionMode
              ? () {
                  setState(() {
                    if (_selectedCodes.contains(friend.code)) {
                      _selectedCodes.remove(friend.code);
                    } else {
                      _selectedCodes.add(friend.code);
                    }
                  });
                }
              : () => _showFriendProfileSheet(friend),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: friend.avatarUrl != null
                      ? NetworkImage(friend.avatarUrl!)
                      : null,
                  child: friend.avatarUrl == null
                      ? Icon(Icons.person, size: 28, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        friend.code,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (widget.selectionMode)
                  Checkbox(
                    value: _selectedCodes.contains(friend.code),
                    onChanged: (_) {
                      setState(() {
                        if (_selectedCodes.contains(friend.code)) {
                          _selectedCodes.remove(friend.code);
                        } else {
                          _selectedCodes.add(friend.code);
                        }
                      });
                    },
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButton<String>(
                        value: friend.role,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                            value: 'Viewer',
                            child: Text('Viewer'),
                          ),
                          DropdownMenuItem(
                            value: 'Editor',
                            child: Text('Editor'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value == null) return;
                          await _friendService.updateFriendRole(
                            friend.id,
                            value,
                          );
                          _loadData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          await _friendService.removeFriend(friend.id);
                          _selectedCodes.remove(friend.code);
                          _loadData();
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFriendProfileSheet(Friend friend) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final hasAvatar =
            friend.avatarUrl != null && friend.avatarUrl!.trim().isNotEmpty;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      hasAvatar ? NetworkImage(friend.avatarUrl!) : null,
                  child: hasAvatar
                      ? null
                      : Icon(Icons.person, size: 48, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Text(
                  friend.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  friend.code.isNotEmpty ? friend.code : 'No friend code',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                if (friend.email?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    friend.email!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Plan role: ${friend.role}',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildFriendFavoritePlacesSection(friend),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendFavoritePlacesSection(Friend friend) {
    return FutureBuilder<List<Destination>>(
      future: _friendService.getPublicFavoritePlaces(friend),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _buildFavoritePlacesBox(
            title: 'Favorite Places',
            child: Text(
              'Favorites unavailable',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        final places = snapshot.data ?? const <Destination>[];

        if (places.isEmpty) {
          return _buildFavoritePlacesBox(
            title: 'Favorite Places',
            child: Text(
              'No public favorites yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return _buildFavoritePlacesBox(
          title: 'Favorite Places',
          child: Column(
            children: places.take(5).map((place) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (place.location.trim().isNotEmpty)
                            Text(
                              place.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFavoritePlacesBox({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Future<void> _inviteFriend() async {
    final profileCode = _profileCodeController.text.trim();
    if (profileCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a profile code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAddingFriend = true;
    });

    try {
      final result = await _friendService.addFriendByCode(profileCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green[600] : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      if (result.success) {
        _profileCodeController.clear();
        await _loadData();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingFriend = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _profileCodeController.dispose();
    super.dispose();
  }
}
