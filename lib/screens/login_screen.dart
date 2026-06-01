import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();
  final _api = ApiService();

  bool _rememberMe = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final remember = await _auth.getRememberMe();
    if (remember) {
      final creds = await _auth.getSavedCredentials();
      if (creds != null && mounted) {
        setState(() {
          _emailCtrl.text = creds['email']!;
          _passCtrl.text = creds['password']!;
          _rememberMe = true;
        });
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.login(_emailCtrl.text.trim(), _passCtrl.text);
      final data = response.data['data'] ?? response.data;
      await _auth.saveToken(data['token'] ?? '');
      if (data['user'] != null) {
        final userJson = Map<String, dynamic>.from(data['user']);
        userJson['_allowedModules'] = List<String>.from(
          data['allowedModules'] ?? [],
        );
        final user = UserModel.fromJson(userJson);
        await _auth.saveUser(user);
        await _auth.saveAllowedModules(user.allowedModules);
      }
      if (_rememberMe) {
        await _auth.setRememberMe(true);
        await _auth.saveCredentials(_emailCtrl.text.trim(), _passCtrl.text);
      } else {
        await _auth.setRememberMe(false);
      }
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
    } catch (e) {
      setState(() {
        final msg = e.toString();
        if (msg.contains('SocketException') || msg.contains('Connection refused') || msg.contains('Network')) {
          _error = 'Cannot connect to server. Check your WiFi or server IP.';
        } else if (msg.contains('401') || msg.contains('Invalid credentials')) {
          _error = 'Invalid email or password';
        } else if (msg.contains('500')) {
          _error = 'Server error. Please try again or contact support.';
        } else {
          _error = 'Login failed: $msg';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Indigo gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                  Color(0xFF4338CA),
                  Color(0xFF4F46E5),
                ],
                stops: [0.0, 0.3, 0.65, 1.0],
              ),
            ),
          ),
          // Decorative orbs
          Positioned(
            top: -60,
            right: -40,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Transform.scale(
                scale: 0.95 + _pulseCtrl.value * 0.1,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryLight.withValues(alpha: 0.2),
                        AppColors.primaryLight.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.1),
                    AppColors.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 20,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 36),
                          _buildCard(),
                          const SizedBox(height: 24),
                          _buildFooter(),
                        ],
                      ),
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

  Widget _buildLogo() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Transform.scale(
            scale: 0.97 + _pulseCtrl.value * 0.03,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFC7D2FE)],
          ).createShader(bounds),
          child: const Text(
            'MysteryMentor',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: AppColors.accent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 5),
              Text(
                'AI Sales Intelligence',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sign in to continue',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'you@company.com',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.email_outlined,
                      color: AppColors.primary.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                if (!RegExp(
                  r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
                ).hasMatch(v.trim()))
                  return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Password
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter password',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.lock_outlined,
                      color: AppColors.primary.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your password';
                if (v.length < 6) return 'Min 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            // Remember me
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: _rememberMe
                          ? const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryLight,
                              ],
                            )
                          : null,
                      color: _rememberMe ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _rememberMe
                            ? AppColors.primary
                            : AppColors.textHint.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: _rememberMe
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Remember me',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Sign in
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _loading ? null : _login,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'Powered by AI',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.35),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          width: 28,
          height: 1,
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ],
    );
  }
}
