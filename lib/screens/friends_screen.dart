import 'package:flutter/material.dart';
import 'package:halaph/models/friend.dart';
import 'package:halaph/services/friend_service.dart';

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
  String _myCode = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCodes.addAll(widget.initialSelectedCodes);
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait<dynamic>([
      _friendService.getMyCode(),
      _friendService.getFriends(),
    ]);
    if (!mounted) return;
    setState(() {
      _myCode = results[0] as String;
      _members = results[1] as List<Friend>;
      _isLoading = false;
    });
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
              Navigator.of(context).pop(_selectedCodes.toList());
            } else {
              Navigator.of(context).pop();
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
                  Navigator.of(context).pop(_selectedCodes.toList()),
              child: const Text('Done'),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileCodeSection(),
                    const SizedBox(height: 24),
                    _buildMembersSection(),
                  ],
                ),
              ),
      ),
    );
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
            color: Colors.black.withOpacity(0.05),
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
                onPressed: _inviteFriend,
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
                child: const Text(
                  'Invite',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _members
                  .map((friend) => _buildMemberTile(friend))
                  .toList(),
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
          onTap: () {
            // Handle member tap
          },
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
      _loadData();
    }
  }

  @override
  void dispose() {
    _profileCodeController.dispose();
    super.dispose();
  }
}
