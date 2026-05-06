import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/models/user.dart';
import 'package:halaph/services/plan_notification_service.dart';
import 'package:halaph/services/simple_plan_service.dart';

class AccountsScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AccountsScreen({super.key, this.onLoginSuccess});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _auth = AuthService();
  User? _user;
  bool _loading = false;
  bool _isLogin = true;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadPlanReminderSetting();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await _auth.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = u;
    });
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
    });
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final user = await _auth.login(email, pass);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _user = user;
    });
    if (user != null) {
      widget.onLoginSuccess?.call();
    } else {
      _showAuthError(
        _auth.lastAuthError ??
            'Could not log in. Check your email and password.',
      );
    }
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
    });
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final user = await _auth.register(
      email,
      pass,
      name: name.isNotEmpty ? name : null,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _user = user;
    });
    if (user != null) {
      widget.onLoginSuccess?.call();
    } else {
      _showAuthError(
        _auth.lastAuthError ??
            'Could not create the account. Try another email.',
      );
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
    });
  }

  Future<void> _loadPlanReminderSetting() async {
    final enabled = await PlanNotificationService.arePlanRemindersEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });

    await PlanNotificationService.setPlanRemindersEnabled(value);

    if (value) {
      await SimplePlanService.refreshPlanReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan reminders turned on')),
      );
    } else {
      await SimplePlanService.cancelAllPlanReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan reminders turned off')),
      );
    }
  }

  bool get _canLeaveAccountScreen {
    if (!_isLogin) return true;
    if (_user != null) return true;
    if (widget.onLoginSuccess == null) return true;
    return false;
  }

  void _handleClose() {
    if (!_isLogin) {
      setState(() => _isLogin = true);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: Text(
          _user == null ? 'Accounts' : 'Account',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: _canLeaveAccountScreen
            ? IconButton(
                icon: Icon(
                  _isLogin ? Icons.arrow_back : Icons.close,
                  color: Colors.black87,
                ),
                onPressed: _handleClose,
                tooltip: _isLogin ? 'Back' : 'Close',
              )
            : null,
      ),
      body: SafeArea(
        child: _user == null ? _buildLogin() : _buildAccountDetails(),
      ),
    );
  }

  Widget _buildLogin() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.blue[600],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isLogin ? 'Welcome Back!' : 'Create Account',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLogin
                ? 'Sign in to continue planning your trips'
                : 'Register to start planning your trips',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isLogin) ...[
                  _buildTextField(
                    controller: _nameController,
                    label: 'Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : (_isLogin ? _login : _register),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isLogin ? 'Sign In' : 'Create Account',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  children: [
                    TextSpan(
                      text: _isLogin
                          ? "Don't have an account? "
                          : 'Already have an account? ',
                    ),
                    TextSpan(
                      text: _isLogin ? 'Register' : 'Sign In',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLogin) ...[
            TextButton(
              onPressed: _showResetPasswordDialog,
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: Colors.blue[600],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your email address',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );

    if (email != null && email.trim().isNotEmpty) {
      final success = await _auth.sendPasswordResetEmail(email.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Password reset email sent to $email'
                : _auth.lastAuthError ?? 'Failed to send reset email',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildAccountDetails() {
    final name = _user?.name ?? '';
    final email = _user?.email ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue[100],
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.blue[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Welcome, $name',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              email,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notification Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_outlined,
                            color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        const Text(
                          'Plan Reminder',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      activeThumbColor: Colors.blue[600],
                      activeTrackColor:
                          Colors.blue[600]?.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                if (_notificationsEnabled) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Plan reminders will notify you 1 hour before the first stop and 30 minutes before each next stop.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
