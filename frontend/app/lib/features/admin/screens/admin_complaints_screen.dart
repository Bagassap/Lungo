import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen>
    with SingleTickerProviderStateMixin {
  static const _darkest = Color(0xFF0B0940);
  static const _dark    = Color(0xFF04198C);
  static const _primary = Color(0xFF0540F2);
  static const _bg      = Color(0xFFF0F4FF);

  final _dio = ApiClient.create();
  late final TabController _tab;

  final _statusFilters = ['', 'OPEN', 'IN_REVIEW', 'RESOLVED'];
  final _statusLabels  = ['Semua', 'Terbuka', 'Diproses', 'Selesai'];

  List<Map<String, dynamic>> _complaints = [];
  bool _loading = true;
  int  _total   = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _statusFilters.length, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final filter = _statusFilters[_tab.index];
      final resp = await _dio.get('/admin/complaints', queryParameters: {
        if (filter.isNotEmpty) 'status': filter,
        'limit': 50,
        'page': 1,
      });
      final d = Map<String, dynamic>.from(resp.data as Map);
      final list = (d['complaints'] as List?) ?? [];
      setState(() {
        _complaints = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _total = (d['total'] as num?)?.toInt() ?? _complaints.length;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data keluhan')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showReplyDialog(Map<String, dynamic> c) async {
    final ctrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReplySheet(ctrl: ctrl, complaint: c),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      try {
        await _dio.patch('/admin/complaints/${c['id']}/reply',
            data: {'reply': ctrl.text.trim()});
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Balasan berhasil dikirim'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengirim balasan')));
        }
      }
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            _buildHeaderWithTabs(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithTabs() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkest, _dark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Color(0x380B0940), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Saran & Pengaduan',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                        Text('$_total laporan masuk',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tab,
              indicatorColor: const Color(0xFFF2CB05),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
              labelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle:
                  GoogleFonts.plusJakartaSans(fontSize: 12),
              dividerColor: Colors.transparent,
              tabs: _statusLabels.map((l) => Tab(text: l)).toList(),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _primary));
    }
    if (_complaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded,
                size: 64, color: Color(0xFFB0BFDF)),
            const SizedBox(height: 12),
            Text('Tidak ada pengaduan pada kategori ini',
              style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF7B8FC0), fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _complaints.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ComplaintCard(
          complaint: _complaints[i],
          onReply: () => _showReplyDialog(_complaints[i]),
        ),
      ),
    );
  }
}

class _ReplySheet extends StatelessWidget {
  static const _dark    = Color(0xFF04198C);
  static const _primary = Color(0xFF0540F2);

  final TextEditingController ctrl;
  final Map<String, dynamic> complaint;
  const _ReplySheet({required this.ctrl, required this.complaint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE8EEFF),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.reply_rounded,
                      color: _primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Balas Pengaduan',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 17, color: _dark)),
                      Text(complaint['subject']?.toString() ?? '',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF9AAAD0)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(14)),
              child: Text(complaint['message']?.toString() ?? '',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF4B5380),
                    height: 1.5)),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: ctrl,
              maxLines: 4,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tulis balasan admin...',
                hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF9AAAD0), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFF),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE6FF))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFDDE6FF))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFDDE6FF), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Batal',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, color: _primary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Kirim Balasan',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  static const _shadow  = Color(0x180540F2);
  static const _primary = Color(0xFF0540F2);
  static const _dark    = Color(0xFF04198C);

  final Map<String, dynamic> complaint;
  final VoidCallback onReply;
  const _ComplaintCard({required this.complaint, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final type    = complaint['type']?.toString() ?? 'COMPLAINT';
    final status  = complaint['status']?.toString() ?? 'OPEN';
    final subject = complaint['subject']?.toString() ?? '-';
    final message = complaint['message']?.toString() ?? '-';
    final reply   = complaint['adminReply']?.toString();
    final pName   = complaint['passengerName']?.toString() ?? 'Penumpang';
    final pPhone  = complaint['passengerPhone']?.toString() ?? '-';
    final date    = (complaint['createdAt']?.toString() ?? '').length >= 10
        ? complaint['createdAt'].toString().substring(0, 10)
        : '-';
    final isResolved =
        status == 'RESOLVED' || status == 'CLOSED';

    final (typeLabel, typeColor) = switch (type) {
      'SUGGESTION' => ('Saran',    const Color(0xFF0891B2)),
      'PRAISE'     => ('Pujian',   const Color(0xFF059669)),
      _            => ('Pengaduan', const Color(0xFFDC2626)),
    };

    final (statusLabel, statusColor) = switch (status) {
      'IN_REVIEW' => ('Diproses', const Color(0xFFD97706)),
      'RESOLVED'  => ('Selesai',  const Color(0xFF059669)),
      'CLOSED'    => ('Ditutup',  Colors.grey),
      _           => ('Terbuka',  _primary),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: _shadow, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                _Badge(typeLabel, typeColor,
                    typeColor.withValues(alpha: 0.1)),
                const SizedBox(width: 6),
                _Badge(statusLabel, statusColor,
                    statusColor.withValues(alpha: 0.1)),
                const Spacer(),
                Text(date,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFFB0BFDF))),
              ],
            ),
            const SizedBox(height: 10),

            Text(subject,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 14,
                  color: const Color(0xFF0D1240))),
            const SizedBox(height: 5),
            Text(message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: const Color(0xFF4B5380), height: 1.45)),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: _primary),
                  const SizedBox(width: 5),
                  Text('$pName  ·  $pPhone',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: _dark)),
                ],
              ),
            ),

            if (reply != null && reply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.reply_rounded,
                        size: 16, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(reply,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: const Color(0xFF065F46),
                            height: 1.45)),
                    ),
                  ],
                ),
              ),
            ],

            if (!isResolved) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onReply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.reply_rounded, size: 16),
                  label: Text('Balas Pengaduan',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;
  const _Badge(this.label, this.textColor, this.bgColor);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(8)),
    child: Text(label,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: textColor)),
  );
}
