import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';

class _C {
  static const bg      = Color(0xFFF0F4FF);
  static const primary = Color(0xFF0540F2);
  static const dark    = Color(0xFF04198C);
  static const orange  = Color(0xFFD97706);
  static const green   = Color(0xFF059669);
  static const shadow  = Color(0x180540F2);
}

class AdminPendingDriversScreen extends StatefulWidget {
  const AdminPendingDriversScreen({super.key});

  @override
  State<AdminPendingDriversScreen> createState() => _AdminPendingDriversScreenState();
}

class _AdminPendingDriversScreenState extends State<AdminPendingDriversScreen> {
  final _dio = ApiClient.create();
  List<Map<String, dynamic>> _drivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _dio.get('/admin/drivers', queryParameters: {'filter': 'payment_pending'});
      final list = r.data as List? ?? [];
      setState(() {
        _drivers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _C.primary))
                : _drivers.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: _C.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: _drivers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _DriverCard(
                            data: _drivers[i],
                            onTap: () {
                              final id = _drivers[i]['id'] as String?;
                              if (id == null) return;
                              Navigator.pushNamed(
                                context, '/admin/driver-detail',
                                arguments: id,
                              ).then((_) => _load());
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0940), Color(0xFF0540F2), Color(0xFF056CF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 20),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Verifikasi Driver',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('${_drivers.length} menunggu verifikasi',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white60, fontSize: 12)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              onPressed: _load,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.assignment_turned_in_rounded, size: 64,
            color: _C.green.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text('Tidak ada driver yang menunggu verifikasi',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14, color: _C.dark.withValues(alpha: 0.5)),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _DriverCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user    = data['user']   as Map? ?? {};
    final name    = user['name']   as String? ?? '-';
    final phone   = user['phone']  as String? ?? '-';
    final plate   = data['vehiclePlate'] as String? ?? '-';
    final type    = data['vehicleType']  as String? ?? '-';
    final rawDate = data['createdAt'] as String?;
    final dateStr = rawDate != null
        ? DateFormat('dd MMM yyyy', 'id_ID')
              .format(DateTime.parse(rawDate).toLocal())
        : '-';
    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

    final hasKtp  = data['ktpPhotoUrl']  != null;
    final hasSim  = data['simPhotoUrl']  != null;
    final hasBpkb = data['bpkbPhotoUrl'] != null;
    final hasStnk = data['stnkPhotoUrl'] != null;
    final docCount = [hasKtp, hasSim, hasBpkb, hasStnk].where((v) => v).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.orange.withValues(alpha: 0.25)),
            boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle),
              child: Center(
                child: Text(initials,
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 15, color: _C.dark)),
              const SizedBox(height: 2),
              Text('$phone  •  $plate  •  $type',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _C.dark.withValues(alpha: 0.55))),
              const SizedBox(height: 6),
              Row(children: [
                _DocChip(label: 'KTP',  ok: hasKtp),
                const SizedBox(width: 4),
                _DocChip(label: 'SIM',  ok: hasSim),
                const SizedBox(width: 4),
                _DocChip(label: 'BPKB', ok: hasBpkb),
                const SizedBox(width: 4),
                _DocChip(label: 'STNK', ok: hasStnk),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _C.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('$docCount/4 dok',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.bold, color: _C.orange)),
              ),
              const SizedBox(height: 6),
              Text(dateStr,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: _C.dark.withValues(alpha: 0.4))),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded, color: _C.orange, size: 20),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _DocChip extends StatelessWidget {
  final String label;
  final bool ok;
  const _DocChip({required this.label, required this.ok});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ok
              ? const Color(0xFF059669).withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 9, fontWeight: FontWeight.bold,
                color: ok ? const Color(0xFF059669) : Colors.grey)),
      );
}
