// ─── Auth Sheet ──────────────────────────────────────────────────────────────
//
// Sign-in / Create-account bottom sheet used wherever authentication is
// required (e.g. before the Pro paywall purchase flow).
//
// Usage:
//   final signedIn = await showAuthSheet(
//     context,
//     ref.read(authRepositoryProvider),
//   );

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/auth/domain/repositories/auth_repository.dart';

// ─── Public helper ────────────────────────────────────────────────────────────

/// Presents [AuthSheet] as a modal bottom sheet.
///
/// Returns `true` if the user successfully authenticates, `false` if they
/// dismiss the sheet without signing in.
Future<bool> showAuthSheet(
  BuildContext context,
  AuthRepository repo,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AuthSheet(repo: repo),
  );
  return result ?? false;
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class AuthSheet extends StatefulWidget {
  const AuthSheet({super.key, required this.repo});

  final AuthRepository repo;

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

enum _AuthMode { signIn, signUp }

class _AuthSheetState extends State<AuthSheet> {
  _AuthMode _mode = _AuthMode.signIn;
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0F1E2D) : cs.surface;

    return Padding(
      // Lift sheet above keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(cs),
                  _buildHeader(cs),
                  const SizedBox(height: 24),
                  _buildGoogleButton(cs, isDark),
                  const SizedBox(height: 16),
                  _buildOrDivider(cs),
                  const SizedBox(height: 16),
                  _buildModeToggle(cs, isDark),
                  const SizedBox(height: 20),
                  _buildForm(cs),
                  if (_mode == _AuthMode.signIn) ...[
                    const SizedBox(height: 8),
                    _buildForgotPassword(cs),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorBanner(cs),
                  ],
                  const SizedBox(height: 20),
                  _buildSubmitButton(cs, isDark),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Handle ──────────────────────────────────────────────────────────────────

  Widget _buildHandle(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                cs.primary.withValues(alpha: 0.22),
                cs.primary.withValues(alpha: 0.04),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Icon(Icons.lock_open_rounded, color: cs.primary, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          _mode == _AuthMode.signIn ? 'Welcome back' : 'Create your account',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to access Prayer Lock Pro and\nsync your progress across devices.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Google Button ────────────────────────────────────────────────────────────

  Widget _buildGoogleButton(ColorScheme cs, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1C2B38) : Colors.white,
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" mark
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              child: const Text(
                'G',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4285F4),
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? cs.onSurface : const Color(0xFF3C4043),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Or divider ───────────────────────────────────────────────────────────────

  Widget _buildOrDivider(ColorScheme cs) {
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ],
    );
  }

  // ── Mode toggle ──────────────────────────────────────────────────────────────

  Widget _buildModeToggle(ColorScheme cs, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          _ModeTab(
            label: 'Sign In',
            selected: _mode == _AuthMode.signIn,
            cs: cs,
            isDark: isDark,
            onTap: () => setState(() {
              _mode = _AuthMode.signIn;
              _errorMessage = null;
            }),
          ),
          _ModeTab(
            label: 'Create Account',
            selected: _mode == _AuthMode.signUp,
            cs: cs,
            isDark: isDark,
            onTap: () => setState(() {
              _mode = _AuthMode.signUp;
              _errorMessage = null;
            }),
          ),
        ],
      ),
    );
  }

  // ── Form ─────────────────────────────────────────────────────────────────────

  Widget _buildForm(ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Name — sign-up only
          if (_mode == _AuthMode.signUp) ...[
            _AuthField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              cs: cs,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
          ],

          // Email
          _AuthField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            cs: cs,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Password
          _AuthField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            cs: cs,
            obscureText: _obscurePassword,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your password';
              if (_mode == _AuthMode.signUp && v.length < 6) {
                return 'Minimum 6 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ── Forgot password ──────────────────────────────────────────────────────────

  Widget _buildForgotPassword(ColorScheme cs) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: _sendPasswordReset,
        child: Text(
          'Forgot password?',
          style: TextStyle(
            fontSize: 12,
            color: cs.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Error banner ─────────────────────────────────────────────────────────────

  Widget _buildErrorBanner(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: cs.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit button ────────────────────────────────────────────────────────────

  Widget _buildSubmitButton(ColorScheme cs, bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _isLoading ? null : _submitForm,
        style: FilledButton.styleFrom(
          backgroundColor: cs.secondary,
          foregroundColor: isDark ? const Color(0xFF1A1A00) : Colors.white,
          disabledBackgroundColor: cs.secondary.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isDark ? const Color(0xFF1A1A00) : Colors.white,
                ),
              )
            : Text(
                _mode == _AuthMode.signIn ? 'Sign In' : 'Create Account',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    _setLoading(true);
    try {
      await widget.repo.signInWithGoogle();
      if (mounted) Navigator.pop(context, true);
    } on AuthCancelledException {
      // User dismissed Google picker — no error needed.
    } catch (e) {
      _setError(_friendlyError(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _setLoading(true);
    try {
      if (_mode == _AuthMode.signIn) {
        await widget.repo.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.repo.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _setError(_friendlyError(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setError('Enter your email address above first.');
      return;
    }
    _setLoading(true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _setError(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _setError(_friendlyError(e));
    } finally {
      _setLoading(false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    if (mounted) setState(() => _isLoading = value);
  }

  void _setError(String? message) {
    if (mounted) setState(() => _errorMessage = message);
  }

  String _friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found for this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for this email.';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'network-request-failed':
          return 'Check your internet connection and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment.';
        default:
          AppLogger.error('FirebaseAuthException', e);
          return e.message ?? 'Authentication failed. Please try again.';
      }
    }
    AppLogger.error('Auth unexpected error', e);
    return 'Something went wrong. Please try again.';
  }
}

// ─── Private widgets ──────────────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? cs.surfaceContainerHigh : cs.surface)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? cs.onSurface : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.cs,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ColorScheme cs;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: TextStyle(fontSize: 14, color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        prefixIcon: Icon(icon, size: 20, color: cs.onSurfaceVariant),
        suffixIcon: suffix,
        filled: true,
        fillColor: cs.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
      ),
    );
  }
}
