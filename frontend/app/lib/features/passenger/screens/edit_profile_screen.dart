import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lungo_snackbar.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey  = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await DioClient.create().patch('/users/profile/$userId', data: {'name': _nameCtrl.text.trim()});
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) {
        LungoSnackbar.success(context, 'Profil berhasil diperbarui');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) LungoSnackbar.error(context, 'Gagal menyimpan profil');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(authProvider).user;
    final rawName  = (user?.name ?? '').trim();
    final words    = rawName.isNotEmpty ? rawName.split(' ').where((w) => w.isNotEmpty).toList() : ['P'];
    final initials = words.map((w) => w[0]).take(2).join().toUpperCase();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Column(
          children: [

            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B0940), Color(0xFF04198C)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                      Expanded(
                        child: Text('Edit Profil',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 88, height: 88,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0540F2), Color(0xFF2A6AFF)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF2CB05), width: 3),
                            ),
                            child: Center(
                              child: Text(initials,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
                            ),
                          ),
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.accentColor, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: AppColors.primaryDark, size: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      _FieldLabel('Nama Lengkap'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: AppColors.primaryDark),
                        decoration: InputDecoration(
                          hintText: 'Masukkan nama lengkap',
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.primaryColor),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFFDDE6FF), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFFDDE6FF), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.primaryColor, width: 2),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
                      ),
                      const SizedBox(height: 16),

                      _FieldLabel('Nomor Telepon'),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: user?.phone ?? '',
                        readOnly: true,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, color: const Color(0xFF9AAAD0)),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.phone_outlined,
                              color: Color(0xFF9AAAD0)),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEFF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Terverifikasi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: AppColors.primaryColor)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FF),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFFEEF1FF), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFFEEF1FF), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentColor,
                            foregroundColor: AppColors.primaryDark,
                            elevation: 4,
                            shadowColor:
                                AppColors.accentColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.primaryColor))
                              : Text('Simpan Perubahan',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
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
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600, fontSize: 13,
        color: const Color(0xFF04198C))),
  );
}
