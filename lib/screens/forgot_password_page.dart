import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/app_animations.dart';
import '../widgets/apple_ui.dart';

/// Requests a password-reset link from the clinic.
///
/// Designed with Apple ID / Apple Account recovery aesthetics:
/// crisp typography, soft squircle card, and spring micro-interactions.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialIdentifier});

  /// Prefills the field with the email typed on the login screen.
  final String? initialIdentifier;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = const AuthService();
  late final TextEditingController _identifierController;

  bool _isLoading = false;
  bool _sent = false;
  String? _errorMessage;
  String? _sentMessage;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: (widget.initialIdentifier ?? '').trim(),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final identifier = _identifierController.text.trim();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.requestPasswordReset(
      identifier: identifier,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _sent = true;
        _sentMessage = result.message ??
            "If an account exists for those details, we've sent a password reset link to the email on file.";
      } else {
        _errorMessage =
            result.message ?? 'Could not send the reset link. Please try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.canvas,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -60,
            child: _AppleGlow(
              size: 300,
              color: AppleColors.brand.withValues(alpha: 0.10),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      AppleTapBounce(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppleColors.border,
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chevron_left_rounded,
                                color: AppleColors.brand,
                                size: 22,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppleColors.brand,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: FadeSlideIn(
                          offset: const Offset(0, 28),
                          duration: const Duration(milliseconds: 560),
                          child: _buildAppleCard(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppleColors.border, width: 0.8),
        boxShadow: AppleColors.elevatedShadow,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.topCenter,
            children: [...previousChildren, ?currentChild],
          ),
          child: KeyedSubtree(
            key: ValueKey<bool>(_sent),
            child: _sent ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppleColors.brandLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: AppleColors.brand,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Forgot your password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              color: AppleColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your email or phone number and we'll send a reset link to the email on file.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppleColors.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 26),
          const Text('Email or phone number', style: _labelStyle),
          const SizedBox(height: 8),
          TextFormField(
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [
              AutofillHints.email,
              AutofillHints.telephoneNumber,
            ],
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(
              fontSize: 15,
              color: AppleColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: _inputDecoration(
              hint: 'm@example.com or +91 98765 43210',
              icon: Icons.alternate_email_rounded,
            ),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) {
                return 'Please enter your email or phone number';
              }
              if (text.contains('@')) {
                final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailPattern.hasMatch(text)) {
                  return 'Please enter a valid email address';
                }
              } else {
                final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length < 7) {
                  return 'Please enter a valid phone number';
                }
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _AppleErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 24),
          AppleButton(
            label: 'Send reset link',
            onPressed: _isLoading ? null : _submit,
            isLoading: _isLoading,
            height: 50,
            borderRadius: 14,
          ),
          const SizedBox(height: 12),
          AppleTapBounce(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Back to sign in',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppleColors.brand,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: SuccessCheck(size: 76)),
        const SizedBox(height: 20),
        const Text(
          'Check your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppleColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _sentMessage ??
              "If an account exists for those details, we've sent a password reset link to the email on file.",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppleColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'The link expires in 30 minutes. Check your spam folder if you don\'t see it.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppleColors.textTertiary,
          ),
        ),
        const SizedBox(height: 26),
        AppleButton(
          label: 'Back to sign in',
          onPressed: () => Navigator.of(context).maybePop(),
          height: 50,
          borderRadius: 14,
        ),
        const SizedBox(height: 8),
        AppleTapBounce(
          onTap: () {
            setState(() {
              _sent = false;
              _sentMessage = null;
            });
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Use a different email or phone',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppleColors.brand,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const _labelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppleColors.textPrimary,
    letterSpacing: -0.1,
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppleColors.textTertiary, fontSize: 15),
      filled: true,
      fillColor: AppleColors.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      prefixIcon: Icon(icon, size: 20, color: AppleColors.textSecondary),
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppleColors.border, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppleColors.brand, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppleColors.red, width: 0.8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppleColors.red, width: 1.6),
      ),
      errorStyle: const TextStyle(fontSize: 12, color: AppleColors.red),
    );
  }
}

class _AppleErrorBanner extends StatelessWidget {
  const _AppleErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppleColors.redLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppleColors.red.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppleColors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppleColors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppleGlow extends StatelessWidget {
  const _AppleGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
