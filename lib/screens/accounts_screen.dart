import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:halaph/models/user.dart';
import 'package:halaph/services/auth_service.dart';
import 'package:halaph/services/saved_accounts_service.dart';
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
  final _savedAccountsService = SavedAccountsService();

  User? _user;
  List<SavedAccount> _savedAccounts = [];
  bool _loading = false;
  bool _isLogin = true;
  bool _showSignInForm = false;
  SavedAccount? _switchTargetAccount;

  @override
  void initState() {
    super.initState();
    _loadUserAndSavedAccounts();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndSavedAccounts() async {
    final user = await _auth.getCurrentUser();
    if (user != null) {
      await _savedAccountsService.saveCurrentFirebaseUser();
    }
    final saved = await _savedAccountsService.getSavedAccounts();
    if (!mounted) return;
    setState(() {
      _user = user;
      _savedAccounts = saved;
      _showSignInForm = user == null;
    });
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final user = await _auth.login(email, password);

    if (!mounted) return;

    if (user == null) {
      setState(() {
        _loading = false;
      });
      _showAuthError(
        _auth.lastAuthError ??
            'Could not log in. Check your email and password.',
      );
      return;
    }

    await SimplePlanService.initialize(forceRefresh: true);
    await _loadUserAndSavedAccounts();

    if (!mounted) return;
    setState(() {
      _loading = false;
      _showSignInForm = false;
      _switchTargetAccount = null;
      _passwordController.clear();
      _nameController.clear();
    });

    widget.onLoginSuccess?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Signed in as ${user.email}')),
    );
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    final user = await _auth.register(
      email,
      password,
      name: name.isNotEmpty ? name : null,
    );

    if (!mounted) return;

    if (user == null) {
      setState(() {
        _loading = false;
      });
      _showAuthError(
        _auth.lastAuthError ??
            'Could not create the account. Try another email.',
      );
      return;
    }

    await SimplePlanService.initialize(forceRefresh: true);
    await _loadUserAndSavedAccounts();

    if (!mounted) return;
    setState(() {
      _loading = false;
      _showSignInForm = false;
      _switchTargetAccount = null;
      _passwordController.clear();
      _nameController.clear();
    });

    widget.onLoginSuccess?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Signed in as ${user.email}')),
    );
  }

  Future<void> _switchToSavedAccount(SavedAccount account) async {
    final activeEmail = _user?.email.trim().toLowerCase();
    if (activeEmail == account.email.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This account is already active.')),
      );
      return;
    }

    setState(() {
      _switchTargetAccount = account;
      _showSignInForm = true;
      _isLogin = true;
      _emailController.text = account.email;
      _passwordController.clear();
      _nameController.clear();
    });
  }

  Future<void> _removeSavedAccount(SavedAccount account) async {
    final activeEmail = _user?.email.trim().toLowerCase();
    if (activeEmail == account.email.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot remove the active account.')),
      );
      return;
    }

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove saved account?'),
        content: Text(
          '${account.email} will be removed from this device. This will not delete the Firebase account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;

    await _savedAccountsService.removeSavedAccount(account.uid);
    await _loadUserAndSavedAccounts();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${account.email} removed from saved accounts.')),
    );
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool get _canLeaveAccountScreen {
    if (_user != null) return true;
    if (!_isLogin) return true;
    if (widget.onLoginSuccess == null) return true;
    return false;
  }

  void _handleClose() {
    if (!_isLogin) {
      setState(() => _isLogin = true);
      return;
    }
    if (_showSignInForm && _user != null) {
      setState(() {
        _showSignInForm = false;
        _switchTargetAccount = null;
        _passwordController.clear();
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingLogin = _showSignInForm || _user == null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          showingLogin ? 'Sign In' : 'Accounts',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: _canLeaveAccountScreen
            ? IconButton(
                icon: Icon(
                  showingLogin ? Icons.close : Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: _handleClose,
              )
            : null,
      ),
      body: SafeArea(
        child: showingLogin ? _buildLogin() : _buildAccountSwitcher(),
      ),
    );
  }

  Widget _buildAccountSwitcher() {
    final currentEmail = _user?.email.trim().toLowerCase();

    return RefreshIndicator(
      onRefresh: _loadUserAndSavedAccounts,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildAccountsEntrance(order: 0, child: _buildCurrentAccountHeader()),
          const SizedBox(height: 24),
          Text(
            'Saved Accounts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Switch accounts saved on this device. Passwords are never saved.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_savedAccounts.isEmpty)
            _buildAccountsEntrance(order: 1, child: _buildEmptySavedAccounts())
          else
            ..._savedAccounts.asMap().entries.map((entry) {
              final account = entry.value;
              final isCurrent =
                  currentEmail == account.email.trim().toLowerCase();
              return _buildAccountsEntrance(
                order: entry.key + 1,
                child: _buildSavedAccountCard(account, isCurrent: isCurrent),
              );
            }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _showSignInForm = true;
                      _switchTargetAccount = null;
                      _isLogin = true;
                      _emailController.clear();
                      _passwordController.clear();
                      _nameController.clear();
                    });
                  },
            icon: Icon(Icons.person_add_alt_1),
            label: Text('Add another account'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Colors.blue[700],
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.28),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsEntrance({
    required int order,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (order.clamp(0, 5) * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildCurrentAccountHeader() {
    final name = _user?.name ?? 'User';
    final email = _user?.email ?? '';
    final avatarUrl = _user?.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue[100],
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
            child:
                hasAvatar ? null : Icon(Icons.person, color: Colors.blue[600]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Current',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedAccountCard(
    SavedAccount account, {
    required bool isCurrent,
  }) {
    final avatarUrl = account.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? Theme.of(context).colorScheme.surfaceContainerHigh
            : Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? Colors.blue.withValues(alpha: 0.42)
              : Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.blue[100],
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
            child:
                hasAvatar ? null : Icon(Icons.person, color: Colors.blue[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name.isEmpty ? account.email : account.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  account.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isCurrent)
            Text(
              'Active',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            )
          else ...[
            TextButton(
              onPressed: _loading ? null : () => _switchToSavedAccount(account),
              child: Text('Switch'),
            ),
            IconButton(
              onPressed: () => _removeSavedAccount(account),
              icon: Icon(
                Icons.close,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptySavedAccounts() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        'No saved accounts yet.',
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildLogin() {
    final switchTarget = _switchTargetAccount;
    final isSwitchMode = switchTarget != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSwitchMode) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter the password for ${switchTarget.email} to switch accounts.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_user != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Your current account stays active until another sign-in succeeds.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.person, size: 40, color: Colors.blue[600]),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isSwitchMode
                ? 'Switch Account'
                : _isLogin
                    ? 'Sign In'
                    : 'Create Account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSwitchMode
                ? 'Confirm the password. HalaPH does not save passwords.'
                : _isLogin
                    ? 'Sign in to switch or continue using HalaPH.'
                    : 'Create another account for this device.',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
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
                  enabled: !isSwitchMode,
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
                          isSwitchMode
                              ? 'Switch Account'
                              : _isLogin
                                  ? 'Sign In'
                                  : 'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!isSwitchMode)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
          if (_isLogin && !isSwitchMode)
            Center(
              child: TextButton(
                onPressed: _showResetPasswordDialog,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(color: Colors.blue[600], fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ResetPasswordDialog(auth: _auth),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.auth});

  final AuthService auth;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_submitting) return;

    final email = _controller.text.trim();
    final validationMessage = _validateEmail(email);
    if (validationMessage != null) {
      _showMessage(validationMessage, isSuccess: false);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    var closeAfterReset = false;
    try {
      final success = await widget.auth.sendPasswordResetEmail(email);
      if (!mounted) return;

      if (success) {
        _showMessage(
          'Password reset email sent. Check your inbox.',
          isSuccess: true,
        );
        closeAfterReset = true;
        return;
      }

      _showMessage(
        widget.auth.lastAuthError ??
            'Could not send reset email. Check your connection and try again.',
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
        if (closeAfterReset) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Enter your email address.';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) return 'Enter a valid email address.';
    return null;
  }

  void _showMessage(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: _controller,
          enabled: !_submitting,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your email address',
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_submitting) _sendResetEmail();
          },
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _submitting ? null : _sendResetEmail,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send Email'),
          ),
        ],
      ),
    );
  }
}
