import 'package:flutter/material.dart';

import 'screens/patient_home_page.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyPatinesApp());
}

class MyPatinesApp extends StatelessWidget {
  const MyPatinesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyPatines',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      home: const LoginPage(),
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = const AuthService();
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Access denied. This app is for patients only.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }

      final name = _extractDisplayName(result.data) ?? _emailController.text.trim();
      final email = _extractEmail(result.data) ?? _emailController.text.trim();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => PatientHomePage(userName: name, email: email),
        ),
        (route) => false,
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message ?? 'Login failed.'),
        backgroundColor: const Color(0xFFDC2626),
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
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0xFFF8FAFC))),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
            child: ColoredBox(color: Color(0xFF90CAF9)),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 260,
            child: ColoredBox(color: Color(0xFFE3F2FD)),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 420,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xCC90CAF9),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x6690CAF9),
                        blurRadius: 120,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                'https://myclinic.myenum.in/logobg.png',
                                height: 120,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 120,
                                    width: 120,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.local_hospital_outlined,
                                      size: 56,
                                      color: Color(0xFF2196F3),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Welcome to My Clinic',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  "Don't have a clinic yet? ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {},
                                  child: const Text(
                                    'Create your clinic',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Email id',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration('m@example.com'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                  decoration: TextDecoration.underline,
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
                          onFieldSubmitted: (_) => _submit(),
                          decoration: _inputDecoration('••••••••').copyWith(
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
                                color: Colors.black,
                                size: 20,
                              ),
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 44,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF93C5FD),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Login'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(text: 'By clicking continue, you agree to our '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
