import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class _NotifItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  bool isRead;

  _NotifItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  factory _NotifItem.fromJson(Map<String, dynamic> m) => _NotifItem(
        id: m['id'] as String,
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        type: m['type'] as String? ?? 'info',
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        isRead: m['isRead'] as bool? ?? false,
      );
}

IconData _typeIcon(String type) => switch (type) {
      'ride' => Icons.motorcycle_rounded,
      'promo' => Icons.local_offer_rounded,
      'payment' => Icons.payment_rounded,
      _ => Icons.notifications_rounded,
    };

Color _typeColor(String type) => switch (type) {
      'ride' => const Color(0xFF0540F2),
      'promo' => const Color(0xFFD97706),
      'payment' => const Color(0xFF7C3AED),
      _ => const Color(0xFF059669),
    };

Color _typeBg(String type) => switch (type) {
      'ride' => const Color(0xFFE0E8FF),
      'promo' => const Color(0xFFFEF3C7),
      'payment' => const Color(0xFFF0E8FF),
      _ => const Color(0xFFDCFCE7),
    };

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});
  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  List<_NotifItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final res = await DioClient.create().get('/users/notifications/$userId');
      final list = (res.data as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _items = list.map(_NotifItem.fromJson).toList();
          _loading = false;
        });
        _anim..reset()..forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> _markAllRead() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    setState(() { for (final n in _items) { n.isRead = true; } });
    try {
      await DioClient.create().patch('/users/notifications/$userId/read-all');
    } catch (_) {}
  }

  Future<void> _markRead(int index) async {
    if (_items[index].isRead) return;
    final id = _items[index].id;
    setState(() => _items[index].isRead = true);
    try {
      await DioClient.create().patch('/users/notifications/$id/read');
    } catch (_) {}
  }

  Future<void> _delete(int index) async {
    final id = _items[index].id;
    setState(() => _items.removeAt(index));
    try {
      await DioClient.create().delete('/users/notifications/$id');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
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
          colors: [Color(0xFF0B0940), Color(0xFF04198C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 18),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Notifikasi',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                    if (_unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.accentColor,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('$_unreadCount baru',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark)),
                      ),
                    ],
                  ],
                ),
              ),
              if (_unreadCount > 0)
                TextButton(
                  onPressed: _markAllRead,
                  child: Text('Baca semua',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                )
              else
                const SizedBox(width: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: const BoxDecoration(
                  color: Color(0xFFE0E8FF), shape: BoxShape.circle),
              child: const Icon(Icons.notifications_off_rounded,
                  color: AppColors.primaryColor, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Tidak ada notifikasi',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.primaryDark)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final delay = i * 0.06;
        return AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            final t = ((_anim.value - delay) / 0.3).clamp(0.0, 1.0);
            return Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: child),
            );
          },
          child: RepaintBoundary(
            child: _NotifTile(
              notif: _items[i],
              onTap: () => _markRead(i),
              onDismiss: () => _delete(i),
            ),
          ),
        );
      },
    );
  }
}

class _NotifTile extends StatelessWidget {
  final _NotifItem notif;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotifTile({required this.notif, required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isNew = !notif.isRead &&
        DateTime.now().difference(notif.createdAt).inMinutes < 5;
    final tc = _typeColor(notif.type);

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4E4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 24),
      ),
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: notif.isRead ? Colors.white : const Color(0xFFEEF3FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notif.isRead
                  ? const Color(0xFFEEF1FF)
                  : tc.withValues(alpha: 0.28),
              width: notif.isRead ? 1 : 1.5,
            ),
            boxShadow: notif.isRead
                ? const [BoxShadow(color: Color(0x100540F2), blurRadius: 8, offset: Offset(0, 2))]
                : [BoxShadow(color: tc.withValues(alpha: 0.14), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!notif.isRead)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 4,
                      color: tc,
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: _typeBg(notif.type),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: notif.isRead ? null : [
                                BoxShadow(
                                  color: tc.withValues(alpha: 0.3),
                                  blurRadius: 10, spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(_typeIcon(notif.type), color: tc, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(notif.title,
                                          style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: const Color(0xFF0D1240))),
                                    ),
                                    if (!notif.isRead) ...[
                                      if (isNew) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFFF6B35), Color(0xFFFFB800)],
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('BARU',
                                              style: TextStyle(
                                                  fontFamily: 'Satoshi',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white)),
                                        ),
                                      ],
                                      Container(
                                        width: 10, height: 10,
                                        decoration: BoxDecoration(
                                          color: tc,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: tc.withValues(alpha: 0.55),
                                              blurRadius: 7,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(notif.body,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: const Color(0xFF7B8FC0),
                                        height: 1.4)),
                                const SizedBox(height: 5),
                                Text(_relativeTime(notif.createdAt),
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: const Color(0xFFB0BFDF))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
