import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/patient_session.dart';
import 'screens/forgot_password_page.dart';
import 'screens/patient_home_page.dart';
import 'services/auth_service.dart';
import 'widgets/app_animations.dart';
import 'widgets/apple_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyPatinesApp());
}

class MyPatinesApp extends StatelessWidget {
  const MyPatinesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Clinic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppleColors.canvas,
        colorScheme: const ColorScheme.light(
          primary: AppleColors.blue,
          secondary: AppleColors.blue,
          surface: Colors.white,
          error: AppleColors.red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppleColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        dividerColor: AppleColors.border,
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeRisePageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _logoScale = Tween<double>(
    begin: 0.9,
    end: 1,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Motion.easeEnter),
    ),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );
  late final Animation<double> _ring = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait<Object?>([
      SessionStorage.load(),
      if (!reduceMotionOf(context)) _controller.forward(),
    ]);
    final session = results.first as PatientSession?;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      fadeRoute<void>(
        (_) => session != null
            ? PatientHomePage(session: session)
            : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.canvas,
      body: Center(
        child: SizedBox.square(
          dimension: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ring,
                builder: (context, _) => Container(
                  width: 96 + 144 * _ring.value,
                  height: 96 + 144 * _ring.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 2,
                      color: AppleColors.blue.withValues(
                        alpha: 0.35 * (1 - _ring.value),
                      ),
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Image.asset(
                    'assets/images/logo-mark.png',
                    width: 150,
                    height: 150,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<ShakeOnErrorState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = const AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      _shakeKey.currentState?.shake();
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (result.success) {
      if (!_isPatient(result.data)) {
        _shakeKey.currentState?.shake();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Access denied. This app is for patients only.'),
            backgroundColor: AppleColors.red,
          ),
        );
        return;
      }

      final name = _extractDisplayName(result.data) ?? _emailController.text.trim();
      final email = _extractEmail(result.data) ?? _emailController.text.trim();
      final token = result.token;
      final clinicId = _stringAt(result.data ?? const {}, const ['clinicId']) ??
          _stringAt(result.data ?? const {}, const ['clinic', 'clinicId']) ??
          _stringAt(result.data ?? const {}, const ['data', 'clinicId']);
      if (token == null || clinicId == null) {
        _shakeKey.currentState?.shake();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Signed in, but your clinic details were missing. Please try again.',
            ),
            backgroundColor: AppleColors.red,
          ),
        );
        return;
      }

      final session = PatientSession(
        clinicId: clinicId,
        token: token,
        patientId: _stringAt(result.data ?? const {}, const ['patientId']) ??
            _stringAt(result.data ?? const {}, const ['patient', 'patientId']) ??
            _stringAt(result.data ?? const {}, const ['data', 'patientId']),
        name: name,
        email: email,
        clinicName: _stringAt(result.data ?? const {}, const ['clinicName']) ??
            _stringAt(result.data ?? const {}, const ['clinic', 'name']),
      );

      await SessionStorage.save(session);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        fadeRoute<void>((_) => PatientHomePage(session: session)),
        (route) => false,
      );
      return;
    }

    _shakeKey.currentState?.shake();
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Login failed.'),
        backgroundColor: AppleColors.red,
      ),
    );
  }

  bool _isPatient(Map<String, dynamic>? data) {
    if (data == null) return true;
    final candidates = <String?>[
      _stringAt(data, const ['role']),
      _stringAt(data, const ['userRole']),
      _stringAt(data, const ['type']),
      _stringAt(data, const ['accountType']),
      _stringAt(data, const ['user', 'role']),
      _stringAt(data, const ['user', 'type']),
      _stringAt(data, const ['profile', 'role']),
      _stringAt(data, const ['data', 'role']),
      _stringAt(data, const ['data', 'user', 'role']),
    ];
    final role = candidates.whereType<String>().map((s) => s.toLowerCase()).firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
    if (role.isEmpty) return true;
    return role.contains('patient');
  }

  String? _extractDisplayName(Map<String, dynamic>? data) {
    if (data == null) return null;
    return _stringAt(data, const ['name']) ??
        _stringAt(data, const ['fullName']) ??
        _stringAt(data, const ['username']) ??
        _stringAt(data, const ['user', 'name']) ??
        _stringAt(data, const ['user', 'fullName']) ??
        _stringAt(data, const ['profile', 'name']) ??
        _stringAt(data, const ['data', 'name']) ??
        _stringAt(data, const ['data', 'user', 'name']);
  }

  String? _extractEmail(Map<String, dynamic>? data) {
    if (data == null) return null;
    return _stringAt(data, const ['email']) ??
        _stringAt(data, const ['user', 'email']) ??
        _stringAt(data, const ['profile', 'email']) ??
        _stringAt(data, const ['data', 'email']) ??
        _stringAt(data, const ['data', 'user', 'email']);
  }

  String? _stringAt(Map<String, dynamic> data, List<String> path) {
    dynamic current = data;
    for (final key in path) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    if (current is String && current.trim().isNotEmpty) return current.trim();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.canvas,
      body: Stack(
        children: [
          // Ambient soft Apple glow gradients in background
          Positioned(
            top: -120,
            right: -80,
            child: _AppleAmbientGlow(
              size: 340,
              color: AppleColors.blue.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _AppleAmbientGlow(
              size: 320,
              color: AppleColors.purple.withValues(alpha: 0.08),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: FadeSlideIn(
                          offset: const Offset(0, 28),
                          duration: const Duration(milliseconds: 560),
                          child: ShakeOnError(
                            key: _shakeKey,
                            child: _buildAppleCard(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppleColors.border, width: 0.8),
        boxShadow: AppleColors.elevatedShadow,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _staggered(
              1,
              Center(
                child: Image.asset(
                  'assets/images/logo-wordmark.png',
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 22),
            _staggered(
              2,
              const Text(
                'Welcome to My Clinic',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppleColors.textPrimary,
                  letterSpacing: -0.6,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _staggered(
              3,
              const Text(
                'Sign in to view your appointments, reports and bills.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppleColors.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Email id', style: _labelStyle),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(
                fontSize: 15,
                color: AppleColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: 'm@example.com',
                icon: Icons.alternate_email_rounded,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('Password', style: _labelStyle),
                ),
                AppleTapBounce(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ForgotPasswordPage(
                          initialIdentifier: _emailController.text.trim(),
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppleColors.blue,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              style: const TextStyle(
                fontSize: 15,
                color: AppleColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppleColors.textTertiary,
                    size: 20,
                  ),
                  tooltip:
                      _obscurePassword ? 'Show password' : 'Hide password',
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _staggered(
              4,
              AppleButton(
                label: 'Login',
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
                height: 50,
                borderRadius: 14,
              ),
            ),
            const SizedBox(height: 24),
            const Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: AppleColors.textTertiary,
                  height: 1.45,
                ),
                children: [
                  TextSpan(text: 'By clicking continue, you agree to our '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: AppleColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: AppleColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _staggered(int step, Widget child) {
    return FadeSlideIn(
      delay: Duration(milliseconds: 60 * step),
      offset: const Offset(0, 10),
      child: child,
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
      fillColor: const Color(0xFFFBFBFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      prefixIcon: Icon(icon, size: 20, color: AppleColors.textSecondary),
      prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppleColors.border, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppleColors.blue, width: 1.6),
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

class _AppleAmbientGlow extends StatelessWidget {
  const _AppleAmbientGlow({required this.size, required this.color});

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
