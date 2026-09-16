import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        _showSuccess();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('400') ? 'Email already registered.' : 'Registration failed. Try again.',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5A0), Color(0xFF4FC3F7)],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(Icons.check_rounded, size: 36, color: Color(0xFF0A0D14)),
              ),
              const SizedBox(height: 20),
              Text(
                'Account Created!',
                style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your account is pending admin approval.\nYou will be notified once activated.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14, color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context); // close dialog
                      Navigator.pop(context); // back to login
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: const SizedBox(
                      width: double.infinity, height: 48,
                      child: Center(
                        child: Text(
                          'Back to Sign In',
                          style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15,
                            color: Color(0xFF0A0D14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.driverTheme,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: Stack(
          children: [
            // bg gradient
            Container(decoration: const BoxDecoration(gradient: AppTheme.bgGradient)),
            Positioned(
              top: -80, right: -80,
              child: Container(
                width: 280, height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppTheme.purple.withOpacity(0.12), Colors.transparent,
                  ]),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: AppTheme.textSecondary, size: 20),
                        ),
                        Expanded(
                          child: Text(
                            'Driver Registration',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 20, fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _slideCtrl,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── status pill ────────────────────────────
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.schedule_rounded,
                                            size: 14, color: AppTheme.warning),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Requires admin approval after sign up',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11, color: AppTheme.warning,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                // ── form card ──────────────────────────────
                                Container(
                                  decoration: AppTheme.glassCard(radius: 20),
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      _Field(ctrl: _nameCtrl, label: 'Full Name',
                                          icon: Icons.person_outline_rounded,
                                          validator: (v) => v != null && v.length >= 2
                                              ? null : 'Enter your name'),
                                      const SizedBox(height: 14),
                                      _Field(ctrl: _emailCtrl, label: 'Email Address',
                                          icon: Icons.alternate_email_rounded,
                                          type: TextInputType.emailAddress,
                                          validator: (v) => v != null && v.contains('@')
                                              ? null : 'Enter valid email'),
                                      const SizedBox(height: 14),
                                      _Field(ctrl: _phoneCtrl, label: 'Phone (optional)',
                                          icon: Icons.phone_outlined,
                                          type: TextInputType.phone),
                                      const SizedBox(height: 14),
                                      _Field(ctrl: _passwordCtrl, label: 'Password',
                                          icon: Icons.lock_outline_rounded,
                                          obscure: _obscure,
                                          suffix: IconButton(
                                            icon: Icon(
                                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                              color: AppTheme.textSecondary, size: 20,
                                            ),
                                            onPressed: () => setState(() => _obscure = !_obscure),
                                          ),
                                          validator: (v) => v != null && v.length >= 6
                                              ? null : 'Min 6 characters'),
                                      const SizedBox(height: 14),
                                      _Field(ctrl: _confirmCtrl, label: 'Confirm Password',
                                          icon: Icons.lock_outline_rounded,
                                          obscure: _obscureConfirm,
                                          suffix: IconButton(
                                            icon: Icon(
                                              _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                              color: AppTheme.textSecondary, size: 20,
                                            ),
                                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                          ),
                                          validator: (v) => v == _passwordCtrl.text
                                              ? null : 'Passwords do not match'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // ── register button ────────────────────────
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(0.4),
                                        blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _loading ? null : _register,
                                      borderRadius: BorderRadius.circular(14),
                                      child: SizedBox(
                                        width: double.infinity, height: 52,
                                        child: Center(
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 22, height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5, color: Color(0xFF0A0D14),
                                                  ),
                                                )
                                              : Text(
                                                  'Create Driver Account',
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.w700, fontSize: 16,
                                                    color: const Color(0xFF0A0D14),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
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
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType? type;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.type,
    this.obscure = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}
