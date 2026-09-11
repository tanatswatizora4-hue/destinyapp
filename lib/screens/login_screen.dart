import 'package:destiny/resources/app_colors.dart';
import 'package:destiny/services/auth_service.dart';
import 'package:destiny/services/supabase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isForgot = false;
  bool _isLoading = false;
  String? _message;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();

    try {
      if (_isForgot) {
        await _authService.requestPasswordReset(email);
        if (mounted) {
          setState(() {
            _message =
                'If an account exists for that email, a reset link is on the way.';
            _isForgot = false;
            _isLogin = true;
          });
        }
      } else if (_isLogin) {
        await _authService.signInWithEmailAndPassword(email, password);
      } else {
        await _authService.createUserWithEmailAndPassword(
          fullName,
          email,
          password,
        );
        if (mounted) {
          setState(() {
            _message =
                'Account created. Check your email if confirmation is required, then sign in.';
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _message = destinyAuthErrorMessage(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = destinyAuthErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isForgot
        ? 'Reset password'
        : (_isLogin ? 'Explore Your Destiny' : 'Create your Destiny account');
    final subtitle = _isForgot
        ? 'We will email you a reset link'
        : (_isLogin
            ? 'Sign in to your Destiny account'
            : 'Create your Destiny account to continue');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE6F5FF),
              Color(0xFF8BC8FE),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 200,
                  ),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _message!.toLowerCase().contains('created') ||
                                  _message!.toLowerCase().contains('reset')
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4.0,
                    shadowColor: Colors.grey.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (!_isLogin && !_isForgot)
                              TextFormField(
                                controller: _fullNameController,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon:
                                      const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (val) =>
                                    val!.isEmpty ? 'Please enter your name' : null,
                              ),
                            if (!_isLogin && !_isForgot)
                              const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon:
                                    const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) =>
                                  val!.isEmpty ? 'Please enter an email' : null,
                            ),
                            if (!_isForgot) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                obscureText: true,
                                validator: (val) => val!.length < 6
                                    ? 'Password must be 6+ characters'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (_isLoading)
                              const CircularProgressIndicator()
                            else
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize:
                                      const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 5.0,
                                ),
                                onPressed: _submitForm,
                                child: Text(
                                  _isForgot
                                      ? 'Send reset link'
                                      : (_isLogin ? 'Sign In' : 'Sign Up'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_isForgot)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _message = null;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Don\'t have an account? Sign Up'
                            : 'Already have an account? Sign In',
                      ),
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isForgot = !_isForgot;
                        _message = null;
                      });
                    },
                    child: Text(
                      _isForgot ? 'Back to sign in' : 'Forgot password?',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
