import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class PassengerComplaintScreen extends ConsumerStatefulWidget {
  const PassengerComplaintScreen({super.key});

  @override
  ConsumerState<PassengerComplaintScreen> createState() =>
      _PassengerComplaintScreenState();
}

class _PassengerComplaintScreenState
    extends ConsumerState<PassengerComplaintScreen>
    with SingleTickerProviderStateMixin {
  final _dio        = ApiClient.create();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  late TabController _tab;
  String _selectedType = 'COMPLAINT';
  bool _submitting = false;
  List<Map<String, dynamic>> _myComplaints = [];
  bool _loadingHistory = true;

  final _types = [
    ('COMPLAINT',  'Pengaduan', Icons.report_problem_rounded, Color(0xFFDC2626)),
    ('SUGGESTION', 'Saran',     Icons.lightbulb_outline_rounded, Color(0xFF0891B2)),
    ('PRAISE',     'Pujian',    Icons.thumb_up_alt_rounded, Color(0xFF059669)),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging && _tab.index == 1) _loadHistory(); });
    _loadHistory();
  }

  @override
  void dispose() {
    _tab.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final r = await _dio.get('/complaints/my');
      final list = (r.data as List?) ?? [];
      setState(() {
        _myComplaints = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loadingHistory = false;
      });
    } catch (_) {
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _dio.post('/complaints', data: {
        'type':    _selectedType,
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
      });
      _subjectCtrl.clear();
      _messageCtrl.clear();
      await _loadHistory();
      if (mounted) {
        _tab.animateTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terima kasih! Laporan kamu sudah diterima.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengirim, coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                    child: Row(children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                      Expanded(
                        child: Text('Saran & Kritik',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 18)),
                      ),
                      const SizedBox(width: 44),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text('Bantu kami menjadi lebih baik',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: AppColors.accentColor,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Kirim Laporan'),
                      Tab(text: 'Riwayat Saya'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildForm(),
                _buildHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            Text('Jenis Laporan',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 10),
            Row(
              children: _types.map((t) {
                final (val, label, icon, color) = t;
                final selected = _selectedType == val;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = val),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? color : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: selected
                                ? color
                                : const Color(0xFFDDE6FF),
                            width: selected ? 2 : 1),
                        boxShadow: selected
                            ? [BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 10, offset: const Offset(0, 4))]
                            : [],
                      ),
                      child: Column(children: [
                        Icon(icon,
                            color: selected ? Colors.white : color, size: 22),
                        const SizedBox(height: 6),
                        Text(label,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : color)),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            _FieldLabel('Subjek'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectCtrl,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Subjek tidak boleh kosong' : null,
              decoration: _inputDeco('Contoh: Driver tidak ramah'),
            ),
            const SizedBox(height: 16),

            _FieldLabel('Pesan'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 5,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              validator: (v) =>
                  v == null || v.trim().length < 10
                      ? 'Pesan minimal 10 karakter'
                      : null,
              decoration: _inputDeco('Ceritakan pengalamanmu secara detail...'),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  disabledBackgroundColor: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 4,
                  shadowColor: AppColors.primaryColor.withValues(alpha: 0.3),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: Text(
                  _submitting ? 'Mengirim...' : 'Kirim Laporan',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Laporan kamu akan direspons dalam 1×24 jam.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryColor));
    }
    if (_myComplaints.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.inbox_rounded, size: 56, color: AppColors.primaryLight),
          const SizedBox(height: 12),
          Text('Belum ada laporan yang dikirim',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary, fontSize: 14)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppColors.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _myComplaints.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _HistoryCard(complaint: _myComplaints[i]),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE6FF))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE6FF))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.primaryColor, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red)),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryDark));
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> complaint;
  const _HistoryCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final type    = complaint['type']?.toString() ?? 'COMPLAINT';
    final status  = complaint['status']?.toString() ?? 'OPEN';
    final subject = complaint['subject']?.toString() ?? '-';
    final message = complaint['message']?.toString() ?? '';
    final reply   = complaint['adminReply']?.toString();
    final date    = complaint['createdAt']?.toString().substring(0, 10) ?? '-';

    final (typeLabel, typeColor) = switch (type) {
      'SUGGESTION' => ('Saran', const Color(0xFF0891B2)),
      'PRAISE'     => ('Pujian', const Color(0xFF059669)),
      _            => ('Pengaduan', const Color(0xFFDC2626)),
    };
    final (statusLabel, statusColor) = switch (status) {
      'IN_REVIEW' => ('Diproses', const Color(0xFFD97706)),
      'RESOLVED'  => ('Dijawab', const Color(0xFF059669)),
      'CLOSED'    => ('Ditutup', Colors.grey),
      _           => ('Menunggu', AppColors.primaryColor),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryColor.withValues(alpha: 0.06),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Pill(label: typeLabel, color: typeColor),
              const SizedBox(width: 6),
              _Pill(label: statusLabel, color: statusColor),
              const Spacer(),
              Text(date,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text(subject,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold, fontSize: 14,
                    color: AppColors.primaryDark)),
            const SizedBox(height: 4),
            Text(message,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (reply != null && reply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.support_agent_rounded,
                        size: 16, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(reply,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: const Color(0xFF065F46))),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      );
}
