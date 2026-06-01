import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  static const _darkest = Color(0xFF0B0940);
  static const _dark    = Color(0xFF04198C);
  static const _primary = Color(0xFF0540F2);
  static const _bg      = Color(0xFFF0F4FF);

  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  int  _page    = 1;
  int  _total   = 0;
  bool _hasMore = true;

  static const _limit = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() { _loading = true; _page = 1; _logs = []; });
    }
    try {
      final resp = await ApiClient.create().get('/admin/audit-logs',
          queryParameters: {'page': _page, 'limit': _limit});
      final d = resp.data as Map<String, dynamic>;
      final newLogs = List<Map<String, dynamic>>.from(d['logs'] as List);
      setState(() {
        _total = (d['total'] as num?)?.toInt() ?? 0;
        _logs = reset ? newLogs : [..._logs, ...newLogs];
        _hasMore = _logs.length < _total;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat log audit')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    _page++;
    await _load(reset: false);
  }

  (String, Color) _actionMeta(String action) => switch (action) {
    'VERIFY_DRIVER'       => ('Verifikasi Driver',  const Color(0xFF059669)),
    'TOGGLE_USER_STATUS'  => ('Toggle Pengguna',    const Color(0xFF0891B2)),
    'REPLY_COMPLAINT'     => ('Balas Keluhan',       const Color(0xFF7C3AED)),
    'UPDATE_TARIFF'       => ('Update Tarif',        const Color(0xFFD97706)),
    _                     => (action,               const Color(0xFF0540F2)),
  };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkest, _dark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
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
                    Text('Log Audit',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 18)),
                    Text('$_total entri aktivitas',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _logs.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.manage_history_rounded,
                size: 64, color: Color(0xFFB0BFDF)),
            const SizedBox(height: 12),
            Text('Belum ada aktivitas tercatat',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF7B8FC0), fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(),
      color: _primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _logs.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _logs.length) {
            _loadMore();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: _primary)),
            );
          }
          return _AuditCard(log: _logs[i], actionMeta: _actionMeta);
        },
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  static const _shadow = Color(0x180540F2);

  final Map<String, dynamic> log;
  final (String, Color) Function(String) actionMeta;
  const _AuditCard({required this.log, required this.actionMeta});

  @override
  Widget build(BuildContext context) {
    final action    = log['action']    as String? ?? '-';
    final adminName = log['adminName'] as String? ?? 'Admin';
    final details   = log['details']  as String?;
    final targetType= log['targetType'] as String?;
    final createdAt = (log['createdAt'] as String? ?? '').replaceFirst('T', ' ').substring(0, 16);
    final (label, color) = actionMeta(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.manage_history_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: color)),
                      ),
                      if (targetType != null) ...[
                        const SizedBox(width: 6),
                        Text('• $targetType',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, color: const Color(0xFFB0BFDF))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(adminName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 13,
                      color: const Color(0xFF0D1240))),
                  if (details != null && details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: const Color(0xFF9AAAD0))),
                  ],
                  const SizedBox(height: 4),
                  Text(createdAt,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: const Color(0xFFB0BFDF))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
