import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class _C {
  static const primary   = AppColors.primaryColor;
  static const dark      = AppColors.primaryDark;
  static const light     = AppColors.primaryLight;
  static const accent    = AppColors.accentColor;
  static const bg        = Color(0xFFF8FAFF);
  static const bubble1   = Color(0xFF0540F2);
  static const bubble2   = Color(0xFFE8EEFF);
  static const textSub   = AppColors.textSecondary;
  static const readBlue  = Color(0xFF53BDEB);
}

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final _broadcastCtrl = TextEditingController();
  final _dio = ApiClient.create();

  bool _loading = true;
  List<_ChatSession> _chats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r    = await _dio.get('/admin/chats');
      final list = (r.data as List?) ?? [];
      setState(() {
        _chats = list.map((e) {
          final d  = Map<String, dynamic>.from(e as Map);
          final at = d['lastMsgAt'] as String?;
          String time = '';
          if (at != null) {
            try {
              time = DateFormat('HH:mm')
                  .format(DateTime.parse(at).toLocal());
            } catch (_) {}
          }
          return _ChatSession(
            rideId:    d['rideId']        as String? ?? '',
            passenger: d['passengerName'] as String? ?? '-',
            driver:    d['driverName']    as String? ?? '-',
            lastMsg:   d['lastMsg']       as String? ?? '',
            time:      time,
            unread:    (d['unread'] as num?)?.toInt() ?? 0,
          );
        }).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() { _chats = []; _loading = false; });
    }
  }

  void _showBroadcastDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Text('Broadcast Pesan',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: _C.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pesan akan dikirim ke SEMUA pengguna dan driver aktif.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: _C.textSub),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _broadcastCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ketik pesan broadcast...',
                hintStyle: GoogleFonts.plusJakartaSans(
                    color: _C.textSub, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: GoogleFonts.plusJakartaSans(color: _C.textSub)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _broadcastCtrl.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Broadcast terkirim'),
                  backgroundColor: _C.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
            ),
            child: Text('Kirim',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _ListAppBar(
            chatCount: _chats.length,
            onBroadcast: _showBroadcastDialog,
          ),
          _InfoBanner(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _C.primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _C.primary,
                    child: _chats.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _chats.length,
                            itemBuilder: (_, i) => _ChatTile(
                              session: _chats[i],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      _AdminChatDetailScreen(
                                          session: _chats[i]),
                                ),
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBroadcastDialog,
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.campaign_rounded),
        label: Text('Broadcast',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(
          height: 320,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                      color: _C.light, shape: BoxShape.circle),
                  child: const Icon(Icons.forum_outlined,
                      size: 38, color: _C.primary),
                ),
                const SizedBox(height: 16),
                Text('Tidak ada percakapan aktif',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, color: _C.textSub)),
                const SizedBox(height: 4),
                Text('Chat tersedia saat ada perjalanan berlangsung',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: _C.textSub)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ListAppBar extends StatelessWidget {
  final int chatCount;
  final VoidCallback onBroadcast;
  const _ListAppBar(
      {required this.chatCount, required this.onBroadcast});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0940), Color(0xFF04198C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, top + 12, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text('Monitor Chat',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$chatCount aktif',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: Colors.white)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onBroadcast,
            icon: const Icon(Icons.campaign_rounded, color: Colors.white),
            tooltip: 'Broadcast',
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: _C.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode monitoring — Admin hanya dapat melihat percakapan',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: _C.primary,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final _ChatSession session;
  final VoidCallback onTap;
  const _ChatTile({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pInit = session.passenger.isNotEmpty
        ? session.passenger[0].toUpperCase()
        : '?';
    final dInit = session.driver.isNotEmpty
        ? session.driver[0].toUpperCase()
        : '?';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: const BoxDecoration(
                        color: _C.light, shape: BoxShape.circle),
                    child: Center(
                      child: Text(pInit,
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: _C.primary)),
                    ),
                  ),
                  Positioned(
                    bottom: -2, right: -4,
                    child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: _C.accent, shape: BoxShape.circle),
                      child: Center(
                        child: Text(dInit,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _C.dark)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${session.passenger} ↔ ${session.driver}',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF0B0940))),
                    const SizedBox(height: 3),
                    Text(session.lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: session.unread > 0
                                ? const Color(0xFF0B0940)
                                : _C.textSub,
                            fontWeight: session.unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (session.time.isNotEmpty)
                    Text(session.time,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: session.unread > 0
                                ? _C.primary
                                : _C.textSub)),
                  const SizedBox(height: 5),
                  if (session.unread > 0)
                    Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Center(
                        child: Text('${session.unread}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminChatDetailScreen extends StatefulWidget {
  final _ChatSession session;
  const _AdminChatDetailScreen({required this.session});

  @override
  State<_AdminChatDetailScreen> createState() =>
      _AdminChatDetailScreenState();
}

class _AdminChatDetailScreenState extends State<_AdminChatDetailScreen> {
  final _scroll = ScrollController();
  final _dio    = ApiClient.create();
  Timer? _timer;

  bool _loading = true;
  List<_Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _dio.get('/chat/${widget.session.rideId}/messages');
      final list = (r.data as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _messages = list.map((e) {
          final d = Map<String, dynamic>.from(e as Map);
          return _Message(
            text:   d['message']    as String? ?? '',
            sender: d['senderRole'] as String? ?? 'DRIVER',
            isRead: d['isRead']     as bool?   ?? false,
            time: d['createdAt'] != null
                ? DateTime.parse(d['createdAt'] as String).toLocal()
                : DateTime.now(),
          );
        }).toList();
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _DetailAppBar(session: widget.session),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _C.primary))
                : _messages.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final showDate = i == 0 ||
                              !_sameDay(_messages[i - 1].time, msg.time);
                          return Column(
                            children: [
                              if (showDate) _DateChip(date: msg.time),
                              _MonitorBubble(
                                msg: msg,
                                passengerName: widget.session.passenger,
                                driverName:    widget.session.driver,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          _ReadOnlyBar(),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              size: 48, color: _C.light),
          const SizedBox(height: 12),
          Text('Belum ada pesan',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, color: _C.textSub)),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DetailAppBar extends StatelessWidget {
  final _ChatSession session;
  const _DetailAppBar({required this.session});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0940), Color(0xFF04198C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(4, top + 6, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    session.passenger.isNotEmpty
                        ? session.passenger[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                ),
              ),
              Positioned(
                bottom: -2, right: -4,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                      color: _C.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white, width: 1.5)),
                  child: Center(
                    child: Text(
                      session.driver.isNotEmpty
                          ? session.driver[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _C.dark),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${session.passenger} ↔ ${session.driver}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text('Ride: ${session.rideId.length > 8
                    ? session.rideId.substring(0, 8) : session.rideId}...',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text('Read-only',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8))),
          ),
        ],
      ),
    );
  }
}

class _MonitorBubble extends StatelessWidget {
  final _Message msg;
  final String passengerName, driverName;
  const _MonitorBubble({
    required this.msg,
    required this.passengerName,
    required this.driverName,
  });

  @override
  Widget build(BuildContext context) {
    final isPassenger = msg.sender == 'PASSENGER';
    final senderLabel = isPassenger ? passengerName : driverName;
    final time = DateFormat('HH:mm').format(msg.time);

    return Align(
      alignment:
          isPassenger ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            bottom: 6,
            left: isPassenger ? 60 : 0,
            right: isPassenger ? 0 : 60),
        decoration: BoxDecoration(
          color: isPassenger ? _C.bubble1 : _C.bubble2,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(isPassenger ? 18 : 4),
            bottomRight: Radius.circular(isPassenger ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Column(
            crossAxisAlignment: isPassenger
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(senderLabel,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPassenger
                          ? Colors.white.withValues(alpha: 0.75)
                          : _C.primary)),
              const SizedBox(height: 2),
              Text(msg.text,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: isPassenger
                          ? Colors.white
                          : const Color(0xFF1E293B),
                      height: 1.4)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: isPassenger
                              ? Colors.white.withValues(alpha: 0.6)
                              : const Color(0xFF9898CC))),
                  if (isPassenger) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isRead
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 14,
                      color: msg.isRead
                          ? _C.readBlue
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final now     = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final label =
        isToday ? 'Hari ini' : DateFormat('d MMMM yyyy', 'id').format(date);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFD8E3FF),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11, color: const Color(0xFF7B7CBB))),
      ),
    );
  }
}

class _ReadOnlyBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: _C.textSub),
          const SizedBox(width: 8),
          Text('Admin hanya dapat memantau percakapan ini',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: _C.textSub)),
        ],
      ),
    );
  }
}

class _ChatSession {
  final String rideId, passenger, driver, lastMsg, time;
  final int unread;
  const _ChatSession({
    required this.rideId,
    required this.passenger,
    required this.driver,
    required this.lastMsg,
    required this.time,
    required this.unread,
  });
}

class _Message {
  final String text, sender;
  final bool   isRead;
  final DateTime time;
  const _Message({
    required this.text, required this.sender,
    required this.isRead, required this.time,
  });
}
