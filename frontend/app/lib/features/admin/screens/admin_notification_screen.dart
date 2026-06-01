import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';

class _C {
  static const bg      = Color(0xFFF0F4FF);
  static const primary = Color(0xFF0540F2);
  static const dark    = Color(0xFF04198C);
  static const green   = Color(0xFF059669);
  static const orange  = Color(0xFFD97706);
  static const red     = Color(0xFFDC2626);
  static const shadow  = Color(0x180540F2);
}

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() => _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  final _dio = ApiClient.create();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _dio.get('/admin/notifications', queryParameters: {'limit': '100'});
      final list = r.data as List? ?? [];
      setState(() {
        _notifications = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _dio.patch('/admin/notifications/read-all');
      setState(() {
        for (final n in _notifications) {
          n['isRead'] = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _markRead(String id, int index) async {
    if (_notifications[index]['isRead'] == true) return;
    try {
      await _dio.patch('/admin/notifications/$id/read');
      setState(() => _notifications[index]['isRead'] = true);
    } catch (_) {}
  }

  Future<void> _showBroadcastDialog() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl  = TextEditingController();
    String role = 'ALL';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B0940), Color(0xFF0540F2)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Kirim Broadcast',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF04198C))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target Penerima', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF04198C))),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _C.primary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: role,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    borderRadius: BorderRadius.circular(10),
                    items: const [
                      DropdownMenuItem(value: 'ALL',       child: Text('Semua Pengguna')),
                      DropdownMenuItem(value: 'PASSENGER', child: Text('Penumpang')),
                      DropdownMenuItem(value: 'DRIVER',    child: Text('Driver')),
                    ],
                    onChanged: (v) => setS(() => role = v ?? 'ALL'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Judul',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Isi Pesan',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Kirim'),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final body  = bodyCtrl.text.trim();
                if (title.isEmpty || body.isEmpty) return;
                try {
                  final res = await _dio.post('/admin/broadcast', data: {
                    'role': role, 'title': title, 'body': body,
                  });
                  final sent = res.data['sent'] as int? ?? 0;
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: _C.green,
                    content: Text('Broadcast terkirim ke $sent pengguna'),
                  ));
                  _load();
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(Map<String, dynamic> notif, int index) {
    _markRead(notif['id'] as String, index);
    final type     = notif['type'] as String? ?? '';
    final targetId = notif['targetId'] as String?;
    if (type == 'NEW_DRIVER_REGISTRATION' && targetId != null) {
      Navigator.pushNamed(context, '/admin/driver-detail', arguments: targetId)
          .then((_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['isRead'] != true).length;

    return Scaffold(
      backgroundColor: _C.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBroadcastDialog,
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text('Broadcast',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      ),
      body: Column(
        children: [
          _buildHeader(unread),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _C.primary))
                : _notifications.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: _C.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) => _NotifCard(
                            data: _notifications[i],
                            onTap: () => _handleTap(_notifications[i], i),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int unread) {
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
                Text('Notifikasi',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                if (unread > 0)
                  Text('$unread belum dibaca',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white60, fontSize: 12)),
              ]),
            ),
            if (unread > 0)
              TextButton(
                onPressed: _markAllRead,
                child: Text('Tandai Semua Dibaca',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.notifications_none_rounded, size: 64,
            color: _C.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('Belum ada notifikasi',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15, color: _C.dark.withValues(alpha: 0.4))),
      ]),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _NotifCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type    = data['type']   as String? ?? '';
    final title   = data['title']  as String? ?? '';
    final body    = data['body']   as String? ?? '';
    final isRead  = data['isRead'] as bool?   ?? false;
    final rawDate = data['createdAt'] as String?;
    final date    = rawDate != null
        ? DateFormat('dd MMM yyyy, HH:mm', 'id_ID')
              .format(DateTime.parse(rawDate).toLocal())
        : '';

    final (icon, color) = switch (type) {
      'NEW_DRIVER_REGISTRATION' => (Icons.assignment_ind_rounded, _C.orange),
      'DRIVER_PAYMENT'          => (Icons.payments_rounded,       _C.green),
      _                         => (Icons.person_add_rounded,     _C.primary),
    };

    final hasTap = type == 'NEW_DRIVER_REGISTRATION';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasTap ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : _C.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: isRead
                ? Border.all(color: Colors.grey.shade100)
                : Border.all(color: _C.primary.withValues(alpha: 0.2)),
            boxShadow: const [BoxShadow(color: _C.shadow, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                          fontSize: 13, color: _C.dark)),
                ),
                if (!isRead)
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: _C.red, shape: BoxShape.circle),
                  ),
              ]),
              const SizedBox(height: 3),
              Text(body,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: _C.dark.withValues(alpha: 0.6)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Row(children: [
                Text(date,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, color: _C.dark.withValues(alpha: 0.4))),
                if (hasTap) ...[
                  const Spacer(),
                  Text('Lihat Detail →',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                ],
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}
