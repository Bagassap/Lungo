import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lungo_button.dart';
import '../../../core/widgets/lungo_logo.dart';
import '../../../core/widgets/lungo_text_field.dart';
import '../providers/auth_provider.dart';
import '../../shared/providers/nav_tab_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey        = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _selectedRole = '';
  bool _roleError      = false;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole.isEmpty) {
      setState(() => _roleError = true);
      return;
    }
    setState(() => _roleError = false);

    final success = await ref.read(authProvider.notifier).completeRegistration(
      name: _nameController.text.trim(),
      role: _selectedRole,
    );
    if (!mounted) return;

    if (!success) {
      final err = ref.read(authProvider).errorMessage;
      _showError(err ?? 'Pendaftaran gagal');
      return;
    }

    if (_selectedRole == 'PASSENGER') {
      await _showSuccessAndNavigate();
    } else {
      Navigator.pushReplacementNamed(context, '/driver-register');
    }
  }

  Future<void> _showSuccessAndNavigate() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SuccessDialog(
        title: 'Selamat Datang!',
        message: 'Akun penumpang kamu berhasil dibuat.\nSelamat menikmati layanan Lungo!',
        buttonLabel: 'Mulai Perjalanan',
        icon: Icons.check_circle_rounded,
        iconColor: Color(0xFF22C55E),
      ),
    );
    if (!mounted) return;
    ref.read(navTabProvider.notifier).state = 0;
    Navigator.pushNamedAndRemoveUntil(context, '/main', (_) => false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading     = ref.watch(authProvider).status == AuthStatus.loading;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight  = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [

          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0540F2),
                  Color(0xFF04198C),
                  Color(0xFF056CF2),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const LungoLogo(
                        iconColor: Color(0xFFF2CB05),
                        titleColor: Colors.white,
                        subtitleColor: Color(0xFFB0B4E8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sebentar lagi kamu siap\nmemulai perjalanan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: screenHeight * 0.78,
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 40,
                            offset: Offset(0, -8),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E0E0),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),

                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person_add_rounded,
                                      color: AppColors.primaryColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    'Buat Akun',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Lengkapi info dasar kamu untuk memulai',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),

                              Form(
                                key: _formKey,
                                child: LungoTextField(
                                  controller: _nameController,
                                  label: 'Nama Lengkap',
                                  hint: 'Masukkan nama kamu',
                                  prefixIcon: const Icon(Icons.person_rounded),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
                                    if (v.trim().length < 2) return 'Nama terlalu pendek';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

                              Text(
                                'Saya bergabung sebagai',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _RoleCard(
                                    selected: _selectedRole == 'PASSENGER',
                                    title: 'Penumpang',
                                    subtitle: 'Pesan ojek kapan saja',
                                    icon: Icons.person_pin_circle_rounded,
                                    gradient: const [Color(0xFF0540F2), Color(0xFF056CF2)],
                                    onTap: () => setState(() {
                                      _selectedRole = 'PASSENGER';
                                      _roleError = false;
                                    }),
                                  ),
                                  const SizedBox(width: 12),
                                  _RoleCard(
                                    selected: _selectedRole == 'DRIVER',
                                    title: 'Driver',
                                    subtitle: 'Bergabung & cari penumpang',
                                    icon: Icons.electric_moped_rounded,
                                    gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                                    onTap: () => setState(() {
                                      _selectedRole = 'DRIVER';
                                      _roleError = false;
                                    }),
                                  ),
                                ],
                              ),
                              if (_roleError) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Pilih satu peran terlebih dahulu',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.red.shade600,
                                  ),
                                ),
                              ],

                              if (_selectedRole == 'DRIVER') ...[
                                const SizedBox(height: 16),
                                _InfoChip(
                                  icon: Icons.info_outline_rounded,
                                  text: 'Kamu akan mengisi form persyaratan driver dan membayar biaya pendaftaran Rp 50.000',
                                  color: const Color(0xFFF59E0B),
                                ),
                              ] else if (_selectedRole == 'PASSENGER') ...[
                                const SizedBox(height: 16),
                                _InfoChip(
                                  icon: Icons.check_circle_outline_rounded,
                                  text: 'Gratis! Langsung bisa memesan ojek setelah daftar.',
                                  color: const Color(0xFF22C55E),
                                ),
                              ],

                              const SizedBox(height: 28),
                              LungoButton(
                                label: _selectedRole == 'DRIVER'
                                    ? 'Lanjut Daftar Driver →'
                                    : 'Daftar Sekarang',
                                onPressed: _submit,
                                isLoading: isLoading,
                              ),
                              const SizedBox(height: 16),

                              Center(
                                child: Text(
                                  'Dengan melanjutkan, kamu menyetujui\nSyarat & Ketentuan Lungo',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
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
}

class _RoleCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  )
                : null,
            color: selected ? null : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? null
                : Border.all(color: AppColors.primaryColor.withValues(alpha: 0.15)),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: gradient.first.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppColors.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 8),
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: color.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessDialog extends StatefulWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final IconData icon;
  final Color iconColor;

  const _SuccessDialog({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.icon,
    required this.iconColor,
  });

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 44),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.buttonLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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
}
