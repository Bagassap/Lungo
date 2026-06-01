import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_client.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _dark    = Color(0xFF04198C);
  static const _darkest = Color(0xFF0B0940);
  static const _primary = Color(0xFF0540F2);
  static const _bg      = Color(0xFFF0F4FF);
  static const _shadow  = Color(0x180540F2);

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  int  _total   = 0;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.create().get('/admin/users', queryParameters: {
        if (_query.isNotEmpty) 'search': _query,
        'page': 1,
        'limit': 50,
      });
      final d = resp.data as Map<String, dynamic>;
      setState(() {
        _users = List<Map<String, dynamic>>.from(d['users'] as List);
        _total = (d['total'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data pengguna')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleStatus(String id, bool currentActive) async {
    try {
      await ApiClient.create().patch('/admin/users/$id/status',
          data: {'active': !currentActive});
      _loadUsers();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengubah status pengguna')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
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
                    Text('Kelola Pengguna',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 18)),
                    Text('$_total pengguna terdaftar',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: _shadow, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: TextField(
          controller: _searchCtrl,
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Cari nama atau nomor HP...',
            hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: const Color(0xFF9AAAD0)),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0xFF9AAAD0), size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                      _loadUsers();
                    })
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: (_) => _loadUsers(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _primary));
    }
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded,
                size: 64, color: Color(0xFFB0BFDF)),
            const SizedBox(height: 12),
            Text('Tidak ada pengguna ditemukan',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF7B8FC0), fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: _primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _users.length,
        itemBuilder: (_, i) => _UserCard(
          user: _users[i],
          onToggle: (id, active) => _toggleStatus(id, active),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  static const _primary = Color(0xFF0540F2);
  static const _shadow  = Color(0x180540F2);

  final Map<String, dynamic> user;
  final void Function(String id, bool active) onToggle;

  const _UserCard({required this.user, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final id      = user['id'] as String? ?? '';
    final name    = user['name'] as String? ?? '-';
    final phone   = user['phone'] as String? ?? '-';
    final role    = (user['role'] as String? ?? 'PASSENGER').toUpperCase();
    final active  = user['isVerified'] as bool? ?? false;

    final roleColor = role == 'DRIVER'
        ? const Color(0xFF059669)
        : const Color(0xFF0540F2);
    final roleBg = role == 'DRIVER'
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFE0E8FF);

    final initials = name.trim().split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

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
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: role == 'DRIVER'
                      ? [const Color(0xFF059669), const Color(0xFF047857)]
                      : [const Color(0xFF0540F2), const Color(0xFF2A6AFF)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initials.isEmpty ? '?' : initials,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? '(Belum ada nama)' : name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 14,
                      color: const Color(0xFF0D1240))),
                  const SizedBox(height: 2),
                  Text(phone,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: const Color(0xFF9AAAD0))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: roleBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(role,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: roleColor)),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch.adaptive(
                  value: active,
                  onChanged: (_) => onToggle(id, active),
                  activeTrackColor: _primary,
                ),
                Text(active ? 'Aktif' : 'Nonaktif',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: active
                        ? const Color(0xFF059669)
                        : const Color(0xFF9AAAD0))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
