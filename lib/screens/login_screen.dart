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

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  final _api = ApiService();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _fadeController.forward();
    _slideController.forward();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final remember = await _auth.getRememberMe();
    if (remember) {
      final creds = await _auth.getSavedCredentials();
      if (creds != null) {
        setState(() {
          _emailController.text = creds['email']!;
          _passwordController.text = creds['password']!;
          _rememberMe = true;
        });
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });
    try {
      final response = await _api.login(
        _emailController.text.trim(), _passwordController.text,
      );
      final responseData = response.data;
      final data = responseData['data'] ?? responseData;
      final token = data['token'] ?? '';
      await _auth.saveToken(token);
      if (data['user'] != null) {
        final userJson = Map<String, dynamic>.from(data['user']);
        userJson['_allowedModules'] = List<String>.from(data['allowedModules'] ?? []);
        final user = UserModel.fromJson(userJson);
        await _auth.saveUser(user);
        await _auth.saveAllowedModules(user.allowedModules);
      }
      if (_rememberMe) {
        await _auth.setRememberMe(true);
        await _auth.saveCredentials(_emailController.text.trim(), _passwordController.text);
      } else {
        await _auth.setRememberMe(false);
      }
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      setState(() { _errorMessage = 'Invalid email or password. Please try again.'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient with pattern
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF060E21),
                  Color(0xFF0A1A3A),
                  Color(0xFF0D2B5E),
                  Color(0xFF1A4B8C),
                ],
                stops: [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -80, right: -60,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.15),
                        AppColors.primary.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -80,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withOpacity(0.1),
                    AppColors.accent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: -40,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryLight.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogoSection(),
                          const SizedBox(height: 36),
                          _buildLoginCard(),
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

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Animated logo container
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value * 0.98 + 0.02,
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A73E8), Color(0xFF00BCD4)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inner glow
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  const Icon(Icons.psychology_rounded, size: 48, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // App name
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFF90CAF9)],
          ).createShader(bounds),
          child: const Text(
            'MysteryMentor',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.0,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Tagline
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.accent.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text(
                'AI Sales Intelligence',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.75),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 16)),
          BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 80, offset: const Offset(0, 30)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome text
            const Text('Welcome Back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Sign in to your account', style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withOpacity(0.8))),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.error.withOpacity(0.08), AppColors.error.withOpacity(0.04)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.error.withOpacity(0.15)),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500))),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // Email field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'you@company.com',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.email_outlined, color: AppColors.primary.withOpacity(0.7), size: 18),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Please enter your email';
                if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(value.trim())) return 'Please enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Password field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.lock_outlined, color: AppColors.primary.withOpacity(0.7), size: 18),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textHint, size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter your password';
                if (value.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Remember me
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    gradient: _rememberMe
                        ? const LinearGradient(colors: [AppColors.primary, Color(0xFF1565C0)])
                        : null,
                    color: _rememberMe ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: _rememberMe ? AppColors.primary : AppColors.textHint.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: _rememberMe ? [
                      BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                    ] : [],
                  ),
                  child: _rememberMe
                      ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                const Text('Remember me', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 28),

            // Sign in button
            SizedBox(
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF1565C0)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 32, height: 1, color: Colors.white.withOpacity(0.15)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Powered by AI',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500, letterSpacing: 0.5),
              ),
            ),
            Container(width: 32, height: 1, color: Colors.white.withOpacity(0.15)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFeatureChip(Icons.mic_rounded, 'Call Recording'),
            const SizedBox(width: 8),
            _buildFeatureChip(Icons.analytics_rounded, 'AI Analysis'),
            const SizedBox(width: 8),
            _buildFeatureChip(Icons.insights_rounded, 'Insights'),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
