import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lungo_button.dart';
import '../../../core/widgets/lungo_logo.dart';
import '../../../core/widgets/lungo_snackbar.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  int _secondsLeft = 60;
  Timer? _timer;
  late String _phone;
  bool _isNewUser = false;

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
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _phone      = args['phone']     as String? ?? '';
      _isNewUser  = args['isNewUser'] as bool?   ?? false;
    } else {
      _phone = args as String? ?? '';
    }

  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final otp = _otpValue;
    if (otp.length < 6) {
      LungoSnackbar.warning(context, 'Masukkan 6 digit kode OTP');
      return;
    }

    final result = await ref.read(authProvider.notifier).verifyOtp(otp);
    if (!mounted) return;

    if (result.success) {
      if (result.multipleRoles) {
        final roles = ref.read(authProvider).availableRoles;
        _showRolePicker(roles);
      } else if (result.isNewUser) {
        Navigator.pushReplacementNamed(context, '/register');
      } else {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } else {
      final err = ref.read(authProvider).errorMessage;
      LungoSnackbar.error(context, err ?? 'OTP salah, coba lagi');
    }
  }

  void _showRolePicker(List<String> roles) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RolePickerSheet(
        roles: roles,
        onSelect: (role) async {
          Navigator.pop(context);
          final ok = await ref.read(authProvider.notifier).selectRole(role);
          if (!mounted) return;
          if (ok) {
            Navigator.pushReplacementNamed(context, '/main');
          } else {
            final err = ref.read(authProvider).errorMessage;
            LungoSnackbar.error(context, err ?? 'Gagal memilih role');
          }
        },
      ),
    );
  }

  Future<void> _resend() async {
    _startTimer();
    for (final c in _controllers) { c.clear(); }
    setState(() {});
    await ref.read(authProvider.notifier).requestOtp(_phone);
  }

  Widget _buildOtpBox(int index) {
    final isFilled = _controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 46,
      height: 56,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryColor,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: isFilled
              ? AppColors.primaryColor.withValues(alpha: 0.08)
              : AppColors.primaryLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: isFilled
                ? const BorderSide(color: AppColors.primaryColor, width: 1.5)
                : BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).status == AuthStatus.loading;
    final maskedPhone = _phone.length > 4
        ? '${_phone.substring(0, _phone.length - 4)}****'
        : _phone;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background gradient
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

          // Decorative circles
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

          // Logo + back button (upper area)
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
                      // Back button
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
                        'Kode OTP dikirim ke\n$maskedPhone',
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

          // Bottom card
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
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Handle bar
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
                                  Icons.sms_rounded,
                                  color: AppColors.primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                _isNewUser ? 'Daftar Akun Baru' : 'Masuk ke Akun',
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
                            'Kode dikirim untuk ${_isNewUser ? 'mendaftar' : 'masuk'} ke Lungo',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // OTP boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, _buildOtpBox),
                          ),
                          const SizedBox(height: 28),

                          LungoButton(
                            label: 'Verifikasi',
                            onPressed: _otpValue.length == 6 ? _verify : null,
                            isLoading: isLoading,
                          ),
                          const SizedBox(height: 16),

                          Center(
                            child: _secondsLeft > 0
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 14,
                                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Kirim ulang dalam $_secondsLeft detik',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  )
                                : TextButton(
                                    onPressed: _resend,
                                    child: Text(
                                      'Kirim Ulang OTP',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryColor,
                                      ),
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
        ],
      ),
    );
  }
}

class _RolePickerSheet extends StatelessWidget {
  final List<String> roles;
  final ValueChanged<String> onSelect;
  const _RolePickerSheet({required this.roles, required this.onSelect});

  static const _cfg = {
    'PASSENGER': (Icons.person_rounded,         'Penumpang', Color(0xFF0540F2)),
    'DRIVER':    (Icons.electric_moped_rounded, 'Driver',    Color(0xFF059669)),
    'ADMIN':     (Icons.admin_panel_settings_rounded, 'Admin', Color(0xFF7C3AED)),
  };

  // Hanya PASSENGER yang bisa di-auto-create oleh backend melalui selectRole.
  // DRIVER butuh proses registrasi + approval admin, jadi tidak bisa langsung ditambahkan.
  static const _addableRoles = ['PASSENGER'];

  @override
  Widget build(BuildContext context) {
    // Role baru yang belum dimiliki user (selain ADMIN)
    final newRoles = _addableRoles.where((r) => !roles.contains(r)).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Masuk Sebagai',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800, fontSize: 18,
              color: const Color(0xFF1F2937)),
          ),
          const SizedBox(height: 6),
          Text(
            roles.length > 1
                ? 'Nomor ini terdaftar di beberapa akun.\nPilih akun yang ingin kamu gunakan.'
                : 'Pilih akun atau tambah akun baru\nuntuk nomor ini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13, height: 1.5, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),

          // Akun yang sudah terdaftar
          ...roles.map((role) {
            final cfg = _cfg[role] ?? (Icons.person_rounded, role, AppColors.primaryColor);
            return GestureDetector(
              onTap: () => onSelect(role),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cfg.$3.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cfg.$3.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: cfg.$3.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cfg.$1, color: cfg.$3, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      cfg.$2,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 15,
                        color: const Color(0xFF1F2937)),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: cfg.$3),
                  ],
                ),
              ),
            );
          }),

          // Opsi daftar akun baru (jika ada role yang belum dimiliki)
          if (newRoles.isNotEmpty) ...[
            if (roles.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('atau',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: const Color(0xFF9CA3AF))),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
            ],
            ...newRoles.map((role) {
              final cfg = _cfg[role] ?? (Icons.person_rounded, role, AppColors.primaryColor);
              final label = role == 'PASSENGER' ? 'Daftar sebagai Penumpang'
                          : role == 'DRIVER'    ? 'Daftar sebagai Driver'
                          : 'Daftar sebagai ${cfg.$2}';
              return GestureDetector(
                onTap: () => onSelect(role),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cfg.$3.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: cfg.$3.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.add_circle_outline_rounded,
                            color: cfg.$3, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700, fontSize: 15,
                                color: cfg.$3),
                            ),
                            Text(
                              'Buat akun baru dengan nomor ini',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, color: const Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: cfg.$3),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
