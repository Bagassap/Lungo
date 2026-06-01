import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lungo_button.dart';
import '../../shared/providers/nav_tab_provider.dart';

class _DriverRegState {

  String birthPlace   = '';
  String birthDate    = '';
  String address      = '';
  String vehicleType  = 'MOTOR';
  String vehiclePlate = '';

  XFile? ktpFile;
  XFile? simFile;
  XFile? bpkbFile;
  XFile? stnkFile;

  String? qrisData;
  Map<String, dynamic>? bankTransfer;
  int    amount = 50000;
}

class DriverRegistrationScreen extends ConsumerStatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  ConsumerState<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState
    extends ConsumerState<DriverRegistrationScreen>
    with TickerProviderStateMixin {
  final _dio   = ApiClient.create();
  final _state = _DriverRegState();

  int  _step     = 0;
  bool _isLoading = false;

  final _step1Key        = GlobalKey<FormState>();
  final _birthPlaceCtrl  = TextEditingController();
  final _birthDateCtrl   = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _plateCtrl       = TextEditingController();

  late AnimationController _pageAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pageAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _pageAnim, curve: Curves.easeOut);
    _pageAnim.forward();
  }

  @override
  void dispose() {
    _pageAnim.dispose();
    _birthPlaceCtrl.dispose();
    _birthDateCtrl.dispose();
    _addressCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0) {
      if (!_step1Key.currentState!.validate()) return;
      _state.birthPlace   = _birthPlaceCtrl.text.trim();
      _state.birthDate    = _birthDateCtrl.text.trim();
      _state.address      = _addressCtrl.text.trim();
      _state.vehiclePlate = _plateCtrl.text.trim();
    }
    if (_step == 1) {
      if (_state.ktpFile == null ||
          _state.simFile == null ||
          _state.bpkbFile == null ||
          _state.stnkFile == null) {
        _showError('Harap upload semua dokumen yang diperlukan');
        return;
      }
    }
    _animateStep(_step + 1);
  }

  void _prevStep() {
    if (_step > 0) _animateStep(_step - 1);
  }

  void _animateStep(int target) {
    _pageAnim.reset();
    setState(() => _step = target);
    _pageAnim.forward();
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);
    try {
      final formData = FormData.fromMap({
        'birthPlace':   _state.birthPlace,
        'birthDate':    _state.birthDate,
        'address':      _state.address,
        'vehicleType':  _state.vehicleType,
        'vehiclePlate': _state.vehiclePlate,
        if (_state.ktpFile  != null) 'ktp':  await MultipartFile.fromFile(_state.ktpFile!.path,  filename: 'ktp.jpg'),
        if (_state.simFile  != null) 'sim':  await MultipartFile.fromFile(_state.simFile!.path,  filename: 'sim.jpg'),
        if (_state.bpkbFile != null) 'bpkb': await MultipartFile.fromFile(_state.bpkbFile!.path, filename: 'bpkb.jpg'),
        if (_state.stnkFile != null) 'stnk': await MultipartFile.fromFile(_state.stnkFile!.path, filename: 'stnk.jpg'),
      });

      final resp = await _dio.post('/drivers/submit-registration', data: formData);
      final data = Map<String, dynamic>.from(resp.data as Map);

      setState(() {
        _state.qrisData     = data['qrisData'] as String?;
        _state.amount       = (data['amount'] as num?)?.toInt() ?? 50000;
        _state.bankTransfer = data['bankTransfer'] as Map<String, dynamic>?;
      });
      _animateStep(2);
    } catch (e) {
      _showError('Gagal submit registrasi: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmPayment() async {
    setState(() => _isLoading = true);
    try {
      await _dio.post('/drivers/confirm-payment');
      _animateStep(3);
    } catch (e) {
      _showError('Gagal konfirmasi: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    setState(() {
      switch (type) {
        case 'ktp':  _state.ktpFile  = img;
        case 'sim':  _state.simFile  = img;
        case 'bpkb': _state.bpkbFile = img;
        case 'stnk': _state.stnkFile = img;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('id', 'ID'),
      initialDate: DateTime(1995, 8, 17),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 17)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    _state.birthDate = DateFormat('yyyy-MM-dd').format(picked);
    _birthDateCtrl.text = DateFormat('dd MMMM yyyy', 'id').format(picked);
  }

  void _showError(String msg) {
    if (!mounted) return;
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
    return Scaffold(
      backgroundColor: const Color(0xFF04198C),
      extendBody: true,
      body: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0540F2), Color(0xFF04198C), Color(0xFF056CF2)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    if (_step < 3)
                      GestureDetector(
                        onTap: _step == 0
                            ? () => Navigator.pop(context)
                            : _prevStep,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 36),
                    const Spacer(),
                    Text(
                      'Daftar Driver',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 36),
                  ],
                ),
              ),

              if (_step < 3) ...[
                const SizedBox(height: 20),
                _StepBar(currentStep: _step, totalSteps: 3),
              ],

              const SizedBox(height: 16),

              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: _buildStepContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    return switch (_step) {
      0 => _buildStep0(),
      1 => _buildStep1(),
      2 => _buildStep2(),
      _ => _buildStep3(),
    };
  }

  Widget _buildStep0() {
    return _CardShell(
      title: 'Data Diri',
      subtitle: 'Langkah 1 dari 3',
      icon: Icons.person_outline_rounded,
      child: Form(
        key: _step1Key,
        child: Column(
          children: [
            _FormField(
              label: 'Tempat Lahir',
              hint: 'Kota tempat lahir',
              icon: Icons.location_city_rounded,
              controller: _birthPlaceCtrl,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickDate,
              behavior: HitTestBehavior.opaque,
              child: AbsorbPointer(
                child: _FormField(
                  label: 'Tanggal Lahir',
                  hint: 'Pilih tanggal lahir',
                  icon: Icons.calendar_today_rounded,
                  controller: _birthDateCtrl,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _FormField(
              label: 'Alamat Lengkap',
              hint: 'Jl. Contoh No. 1, Kota',
              icon: Icons.home_rounded,
              controller: _addressCtrl,
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().length < 10 ? 'Alamat terlalu pendek' : null,
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Kendaraan'),
            const SizedBox(height: 12),
            Row(
              children: [
                _VehicleChip(
                  label: 'Motor',
                  emoji: '🛵',
                  selected: _state.vehicleType == 'MOTOR',
                  onTap: () => setState(() => _state.vehicleType = 'MOTOR'),
                ),
                const SizedBox(width: 12),
                _VehicleChip(
                  label: 'Mobil',
                  emoji: '🚗',
                  selected: _state.vehicleType == 'MOBIL',
                  onTap: () => setState(() => _state.vehicleType = 'MOBIL'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FormField(
              label: 'Nomor Polisi',
              hint: 'D 1234 XYZ',
              icon: Icons.confirmation_number_rounded,
              controller: _plateCtrl,
              validator: (v) =>
                  v == null || v.trim().length < 4 ? 'Nomor polisi tidak valid' : null,
            ),
            const SizedBox(height: 28),
            LungoButton(
              label: 'Lanjut: Upload Dokumen →',
              onPressed: _nextStep,
              isLoading: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return _CardShell(
      title: 'Upload Dokumen',
      subtitle: 'Langkah 2 dari 3',
      icon: Icons.upload_file_rounded,
      child: Column(
        children: [
          _DocUploadTile(
            label: 'KTP',
            desc: 'Kartu Tanda Penduduk',
            icon: Icons.credit_card_rounded,
            file: _state.ktpFile,
            onTap: () => _pickImage('ktp'),
          ),
          const SizedBox(height: 12),
          _DocUploadTile(
            label: 'SIM',
            desc: 'Surat Izin Mengemudi',
            icon: Icons.drive_eta_rounded,
            file: _state.simFile,
            onTap: () => _pickImage('sim'),
          ),
          const SizedBox(height: 12),
          _DocUploadTile(
            label: 'BPKB',
            desc: 'Buku Pemilik Kendaraan Bermotor',
            icon: Icons.book_rounded,
            file: _state.bpkbFile,
            onTap: () => _pickImage('bpkb'),
          ),
          const SizedBox(height: 12),
          _DocUploadTile(
            label: 'STNK',
            desc: 'Surat Tanda Nomor Kendaraan',
            icon: Icons.article_rounded,
            file: _state.stnkFile,
            onTap: () => _pickImage('stnk'),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentColor.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: Color(0xFF92400E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pastikan foto dokumen jelas, tidak buram, dan seluruh isi dokumen terlihat.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF92400E),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          LungoButton(
            label: _isLoading ? 'Mengirim...' : 'Kirim & Bayar Sekarang →',
            onPressed: _isLoading ? null : () {
              if (_state.ktpFile  == null ||
                  _state.simFile  == null ||
                  _state.bpkbFile == null ||
                  _state.stnkFile == null) {
                _showError('Harap upload semua dokumen terlebih dahulu');
                return;
              }
              _submitRegistration();
            },
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final qris = _state.qrisData ?? '';
    final bt   = _state.bankTransfer;
    final amtFormatted = NumberFormat.currency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0,
    ).format(_state.amount);

    return _CardShell(
      title: 'Pembayaran',
      subtitle: 'Langkah 3 dari 3',
      icon: Icons.qr_code_scanner_rounded,
      child: Column(
        children: [
          Text(
            'Biaya Pendaftaran Driver',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amtFormatted,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/QRIS_logo.svg/320px-QRIS_logo.svg.png',
                      height: 22,
                      errorBuilder: (_, e, s) => Text(
                        'QRIS',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lungo',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (qris.isNotEmpty)
                  QrImageView(
                    data: qris,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0540F2),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF04198C),
                    ),
                  )
                else
                  const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Scan dengan app mobile banking\natau dompet digital kamu',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (bt != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atau Transfer Bank',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TransferRow(label: 'Bank',       value: '${bt['bankName']}'),
                  _TransferRow(label: 'No. Rek',    value: '${bt['accountNumber']}'),
                  _TransferRow(label: 'Atas Nama',  value: '${bt['accountName']}'),
                  _TransferRow(label: 'Nominal',    value: amtFormatted),
                  _TransferRow(
                    label: 'Kode Unik',
                    value: '${bt['note']}',
                    highlight: true,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          _StepList(steps: const [
            '1. Buka aplikasi mobile banking / dompet digital',
            '2. Pilih menu Scan QRIS',
            '3. Scan kode QR di atas',
            '4. Konfirmasi nominal Rp 50.000',
            '5. Tekan tombol di bawah setelah bayar',
          ]),

          const SizedBox(height: 24),
          LungoButton(
            label: _isLoading ? 'Memproses...' : '✓  Saya Sudah Bayar',
            onPressed: _isLoading ? null : _confirmPayment,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 12),
          Text(
            'Pembayaran akan diverifikasi dalam 1×24 jam',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        const SizedBox(height: 40),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, value, child) =>
              Transform.scale(scale: value, child: child),
          child: Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x5522C55E),
                  blurRadius: 32,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Pendaftaran Berhasil!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Data dan dokumenmu sedang kami verifikasi.\nAkun driver aktif dalam 1×24 jam.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _SuccessItem(icon: Icons.assignment_turned_in_rounded, text: 'Dokumen diterima'),
              const SizedBox(height: 12),
              _SuccessItem(icon: Icons.payment_rounded, text: 'Pembayaran dikonfirmasi'),
              const SizedBox(height: 12),
              _SuccessItem(icon: Icons.notifications_active_rounded,
                  text: 'Kamu akan dapat notifikasi saat akun aktif'),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(navTabProvider.notifier).state = 0;
                Navigator.pushNamedAndRemoveUntil(
                  context, '/main', (_) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 6,
                shadowColor: const Color(0x5522C55E),
              ),
              child: Text(
                'Ke Beranda',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _CardShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepBar({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final labels = ['Data Diri', 'Dokumen', 'Bayar'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = (i - 1) ~/ 2;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                color: currentStep > stepIdx
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final isActive = currentStep == stepIdx;
          final isDone   = currentStep > stepIdx;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 32 : 28,
                height: isActive ? 32 : 28,
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF22C55E)
                      : isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${stepIdx + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? AppColors.primaryColor
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[stepIdx],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: isActive || isDone
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int maxLines;

  const _FormField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.primaryColor),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryColor),
        filled: true,
        fillColor: AppColors.primaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryColor : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocUploadTile extends StatelessWidget {
  final String label;
  final String desc;
  final IconData icon;
  final XFile? file;
  final VoidCallback onTap;

  const _DocUploadTile({
    required this.label,
    required this.desc,
    required this.icon,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = file != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: uploaded
              ? const Color(0xFF22C55E).withValues(alpha: 0.06)
              : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: uploaded
                ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                : AppColors.primaryColor.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: uploaded
                    ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                    : AppColors.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: uploaded
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(file!.path),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(icon, color: AppColors.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: uploaded ? const Color(0xFF166534) : AppColors.primaryColor,
                    ),
                  ),
                  Text(
                    uploaded ? 'Berhasil diupload ✓' : desc,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: uploaded
                          ? const Color(0xFF166534)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              uploaded ? Icons.check_circle_rounded : Icons.add_photo_alternate_rounded,
              color: uploaded ? const Color(0xFF22C55E) : AppColors.primaryColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _TransferRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.primaryColor : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  final List<String> steps;
  const _StepList({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cara Bayar',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          ...steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              s,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _SuccessItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SuccessItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF22C55E), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
