import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../config/api.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  String _currentServerUrl = ApiConfig.initialBaseUrl;
  bool _isServerOnline = false;
  bool _isCheckingHealth = true;
  Timer? _healthTimer;

  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadCurrentServerUrl();
    _healthTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkServerHealth();
    });

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  void _loadCurrentServerUrl() async {
    final url = await ApiClient().getBaseUrl();
    if (mounted) {
      setState(() => _currentServerUrl = url);
      _checkServerHealth();
    }
  }

  Future<void> _checkServerHealth() async {
    if (!mounted) return;
    final clean = _currentServerUrl.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(milliseconds: 1500),
          receiveTimeout: const Duration(milliseconds: 1500),
        ),
      );
      final resp = await dio.get('$clean/docs');
      if (mounted) {
        setState(() {
          _isServerOnline = resp.statusCode == 200;
          _isCheckingHealth = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isServerOnline = false;
          _isCheckingHealth = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      ref
          .read(authProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);
    }
  }

  void _showQuickLogin() {
    const accounts = [
      ('Admin', 'admin@routeos.local', 'admin123', Icons.admin_panel_settings),
      ('Operator', 'operator@routeos.local', 'operator123', Icons.alt_route),
      ('Driver', 'driver@routeos.local', 'driver123', Icons.local_shipping),
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Quick login'),
              subtitle: Text('Local development accounts'),
            ),
            ...accounts.map(
              (account) => ListTile(
                leading: Icon(account.$4, color: AppTheme.primary),
                title: Text(account.$1),
                subtitle: Text(account.$2),
                onTap: () {
                  _emailController.text = account.$2;
                  _passwordController.text = account.$3;
                  Navigator.pop(sheetContext);
                  _login();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showServerSettings() {
    final urlCtrl = TextEditingController(text: _currentServerUrl);
    String? pingStatus;
    bool isPinging = false;
    Color statusColor = AppTheme.textSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void testPing(String targetUrl) async {
            setModalState(() {
              isPinging = true;
              pingStatus = 'Pinging...';
              statusColor = AppTheme.neonCyan;
            });
            final sw = Stopwatch()..start();
            try {
              final clean = targetUrl.trim().replaceAll(RegExp(r'/+$'), '');
              final dio = Dio(
                BaseOptions(
                  connectTimeout: const Duration(seconds: 4),
                  receiveTimeout: const Duration(seconds: 4),
                ),
              );
              final resp = await dio.get('$clean/docs');
              sw.stop();
              setModalState(() {
                isPinging = false;
                pingStatus =
                    'Connected (${sw.elapsedMilliseconds}ms) - Code ${resp.statusCode}';
                statusColor = AppTheme.primary;
              });
            } catch (e) {
              sw.stop();
              setModalState(() {
                isPinging = false;
                pingStatus = 'Connection failed (${sw.elapsedMilliseconds}ms)';
                statusColor = AppTheme.error;
              });
            }
          }

          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF101524),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.hub_outlined,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Backend Connection',
                          style: GoogleFonts.outfit(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select connection mode or enter custom server URL:',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'QUICK PRESETS',
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetChip(
                      '⚡ USB (localhost:8000)',
                      'http://localhost:8000',
                      urlCtrl,
                      setModalState,
                      () => testPing('http://localhost:8000'),
                    ),
                    _presetChip(
                      '📱 Emulator (10.0.2.2)',
                      'http://10.0.2.2:8000',
                      urlCtrl,
                      setModalState,
                      () => testPing('http://10.0.2.2:8000'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: urlCtrl,
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Server Base URL',
                    labelStyle: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF171E30),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primary),
                    ),
                    suffixIcon: isPinging
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.bolt,
                              color: AppTheme.neonCyan,
                            ),
                            tooltip: 'Test Ping',
                            onPressed: () => testPing(urlCtrl.text),
                          ),
                  ),
                ),

                if (pingStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    pingStatus!,
                    style: GoogleFonts.jetBrainsMono(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.neonCyan,
                          side: const BorderSide(color: AppTheme.neonCyan),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => testPing(urlCtrl.text),
                        icon: const Icon(Icons.wifi_find, size: 18),
                        label: Text(
                          'Ping Test',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: const Color(0xFF0A0D14),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final clean = urlCtrl.text.trim();
                          if (clean.isNotEmpty) {
                            await ApiClient().updateBaseUrl(clean);
                            setState(() => _currentServerUrl = clean);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Server connected to $clean',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: AppTheme.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(
                          'Save & Apply',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _presetChip(
    String label,
    String url,
    TextEditingController ctrl,
    StateSetter setModalState,
    VoidCallback onPing,
  ) {
    final isSelected = ctrl.text.trim() == url;
    return GestureDetector(
      onTap: () {
        setModalState(() => ctrl.text = url);
        onPing();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : const Color(0xFF171E30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error!,
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });

    return Theme(
      data: AppTheme.driverTheme,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: Stack(
          children: [
            // ── animated background glow orbs ──────────────────
            _BackgroundOrbs(pulseAnim: _pulseAnim),

            // ── main content ───────────────────────────────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _slideCtrl,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 32),
                            // ── logo ──────────────────────────
                            _LogoBadge(pulseAnim: _pulseAnim),
                            const SizedBox(height: 28),
                            // ── title ─────────────────────────
                            Text(
                              'RouteOS',
                              style: GoogleFonts.outfit(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Distribution Intelligence System',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 40),
                            // ── glass card ────────────────────
                            Container(
                              decoration: AppTheme.glassCard(radius: 24),
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back',
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),

                                  const SizedBox(height: 4),
                                  Text(
                                    'Sign in to your account',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // email
                                  _PremiumField(
                                    controller: _emailController,
                                    label: 'Email address',
                                    icon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) =>
                                        v != null && v.contains('@')
                                        ? null
                                        : 'Enter valid email',
                                  ),
                                  const SizedBox(height: 16),
                                  // password
                                  _PremiumField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: _obscurePassword,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                    validator: (v) => v != null && v.length >= 6
                                        ? null
                                        : 'Min 6 characters',
                                    onFieldSubmitted: (_) => _login(),
                                  ),
                                  const SizedBox(height: 28),
                                  // sign in button
                                  _GlowButton(
                                    isLoading: auth.isLoading,
                                    onPressed: _login,
                                    label: 'Sign In',
                                    gradient: AppTheme.primaryGradient,
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: auth.isLoading
                                          ? null
                                          : _showQuickLogin,
                                      icon: const Icon(
                                        Icons.flash_on_outlined,
                                        size: 17,
                                      ),
                                      label: const Text('Quick login'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // ── register link ─────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "New driver? ",
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                                  child: Text(
                                    'Create account',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // ── location badge ────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Kozhikode, Kerala',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── top-right server connection status & config ──────
            Positioned(
              top: 48,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  _checkServerHealth();
                  _showServerSettings();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131828).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isCheckingHealth
                          ? AppTheme.warning.withValues(alpha: 0.5)
                          : (_isServerOnline
                                ? AppTheme.primary.withValues(alpha: 0.4)
                                : AppTheme.error.withValues(alpha: 0.7)),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isServerOnline
                                    ? AppTheme.primary
                                    : AppTheme.error)
                                .withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isCheckingHealth
                              ? AppTheme.warning
                              : (_isServerOnline
                                    ? AppTheme.primary
                                    : AppTheme.error),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isCheckingHealth
                                          ? AppTheme.warning
                                          : (_isServerOnline
                                                ? AppTheme.primary
                                                : AppTheme.error))
                                      .withValues(alpha: 0.7),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isCheckingHealth
                            ? 'Checking...'
                            : (_isServerOnline
                                  ? _currentServerUrl
                                        .replaceFirst('http://', '')
                                        .replaceFirst('https://', '')
                                  : 'Offline (Tap)'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: _isServerOnline
                              ? AppTheme.textSecondary
                              : AppTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isServerOnline
                            ? Icons.tune_rounded
                            : Icons.refresh_rounded,
                        size: 12,
                        color: _isServerOnline
                            ? AppTheme.textSecondary
                            : AppTheme.error,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ), // Scaffold
    ); // Theme
  }
}

// ── Background animated orbs ──────────────────────────────────────────────────
class _BackgroundOrbs extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _BackgroundOrbs({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // dark gradient base
        Container(
          decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        ),
        // top-right orb
        Positioned(
          top: -60,
          right: -60,
          child: AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: pulseAnim.value,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primary.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // bottom-left orb
        Positioned(
          bottom: -80,
          left: -80,
          child: AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: 2.0 - pulseAnim.value,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.purple.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Logo badge ────────────────────────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _LogoBadge({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF00E5A0), Color(0xFF4FC3F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4 * pulseAnim.value),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/branding/routeos_logo.png',
            width: 84,
            height: 84,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

// ── Premium form field ────────────────────────────────────────────────────────
class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ── Gradient glow button ──────────────────────────────────────────────────────
class _GlowButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String label;
  final LinearGradient gradient;

  const _GlowButton({
    required this.isLoading,
    required this.onPressed,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF0A0D14),
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: const Color(0xFF0A0D14),
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
