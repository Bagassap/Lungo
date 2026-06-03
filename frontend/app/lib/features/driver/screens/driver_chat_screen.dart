import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../passenger/models/chat_message_model.dart';
import '../providers/driver_chat_provider.dart';
import '../providers/driver_provider.dart';

class _C {
  static const bg         = Color(0xFFF0F4FF);
  static const darkest    = Color(0xFF0B0940);
  static const dark       = Color(0xFF04198C);
  static const primary    = Color(0xFF0540F2);
  static const light      = Color(0xFFE8EEFF);
  static const accent     = Color(0xFFF2CB05);
  static const inputBg    = Color(0xFFECF3FF);
  static const divider    = Color(0xFFD8E3FF);
  static const textSub    = Color(0xFF6B7DB3);
  static const bubbleSent = Color(0xFF0540F2);
  static const online     = Color(0xFF22C55E);
  static const readBlue   = Color(0xFF53BDEB);
  static const listBg     = Color(0xFFF8FAFF);
}

class DriverChatScreen extends ConsumerWidget {
  const DriverChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds       = ref.watch(driverProvider);
    final chatState = ref.watch(driverChatProvider);

    final hasRide   = ds.activeTrip?.rideId != null;
    final hasHistory = !hasRide && chatState.messages.isNotEmpty;
    final pName     = chatState.passengerName
        ?? ds.activeTrip?.passengerName
        ?? 'Penumpang';

    final lastMsg = chatState.messages.isNotEmpty
        ? chatState.messages.last
        : null;
    final lastMsgText = lastMsg?.message
        ?? (hasRide ? 'Ketuk untuk mulai chat' : '');
    final lastTime = lastMsg != null
        ? DateFormat('HH:mm').format(lastMsg.createdAt.toLocal())
        : '';
    final unread = hasRide
        ? chatState.messages
            .where((m) => m.senderRole == 'PASSENGER' && !m.isRead)
            .length
        : 0;

    return Scaffold(
      backgroundColor: _C.listBg,
      body: Column(
        children: [
          _ListAppBar(),
          Expanded(
            child: (hasRide || hasHistory)
                ? _buildChatList(
                    context, ref, pName, lastMsgText, lastTime, unread,
                    chatState, ds)
                : _buildEmpty(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(
    BuildContext context,
    WidgetRef ref,
    String pName,
    String lastMsg,
    String time,
    int unread,
    DriverChatState chatState,
    DriverState ds,
  ) {
    return ListView(
      children: [
        _ChatTile(
          name:    pName,
          lastMsg: lastMsg,
          time:    time,
          unread:  unread,
          isOnline: chatState.status == DriverChatStatus.connected,
          onTap: () {
            final rideId = ds.activeTrip?.rideId;
            if (rideId != null &&
                chatState.status != DriverChatStatus.connected) {
              ref.read(driverChatProvider.notifier).connect(
                rideId,
                passengerName:  ds.activeTrip?.passengerName,
                passengerPhone: chatState.passengerPhone,
              );
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DriverChatDetail(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 130, height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      color: _C.light.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _C.primary.withValues(alpha: 0.12),
                          width: 1.5),
                    ),
                  ),
                  Container(
                    width: 86, height: 86,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0540F2), Color(0xFF6C5CE7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x450540F2),
                            blurRadius: 24,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.chat_bubble_rounded,
                        color: Colors.white, size: 38),
                  ),
                  Positioned(
                    top: 8, right: 6,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _C.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x40F2CB05), blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.two_wheeler_rounded,
                          color: _C.primary, size: 14),
                    ),
                  ),
                  Positioned(
                    bottom: 8, left: 6,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _C.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.people_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Belum Ada Chat',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: _C.darkest)),
            const SizedBox(height: 8),
            Text(
              'Chat tersedia saat ada\nperjalanan aktif dari penumpang',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, height: 1.55, color: _C.textSub),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.darkest, _C.dark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Text('Chat',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _C.accent,
                borderRadius: BorderRadius.circular(20)),
            child: Text('LUNGO',
                style: GoogleFonts.plusJakartaSans(
                    color: _C.primary, fontWeight: FontWeight.w900,
                    fontSize: 11, letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String name, lastMsg, time;
  final int unread;
  final bool isOnline;
  final VoidCallback onTap;

  const _ChatTile({
    required this.name, required this.lastMsg, required this.time,
    required this.unread, required this.isOnline, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ')
        .where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

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
                        color: _C.accent, shape: BoxShape.circle),
                    child: Center(
                      child: Text(initials,
                          style: GoogleFonts.plusJakartaSans(
                              color: _C.primary, fontWeight: FontWeight.w800,
                              fontSize: 18)),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 1, bottom: 1,
                      child: Container(
                        width: 13, height: 13,
                        decoration: BoxDecoration(
                          color: _C.online, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
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
                    Text(name,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: _C.darkest)),
                    const SizedBox(height: 3),
                    Text(lastMsg,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: unread > 0 ? _C.darkest : _C.textSub,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (time.isNotEmpty)
                    Text(time,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: unread > 0 ? _C.primary : _C.textSub)),
                  const SizedBox(height: 5),
                  if (unread > 0)
                    Container(
                      width: 20, height: 20,
                      decoration: const BoxDecoration(
                          color: _C.primary, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$unread',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11,
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

class DriverChatDetail extends ConsumerStatefulWidget {
  const DriverChatDetail({super.key});

  @override
  ConsumerState<DriverChatDetail> createState() => DriverChatDetailState();
}

class DriverChatDetailState extends ConsumerState<DriverChatDetail>
    with WidgetsBindingObserver {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  Timer? _typingDebounce;

  final List<_LocalMedia> _localMedia = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tryConnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingDebounce?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _tryConnect() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ds     = ref.read(driverProvider);
      final rideId = ds.activeTrip?.rideId;
      if (rideId == null) return;

      String? pName  = ds.activeTrip?.passengerName;
      String? pPhone;
      try {
        final r = await ApiClient.create().get('/drivers/active-ride');
        if (r.data != null) {
          final d   = Map<String, dynamic>.from(r.data as Map);
          pName  = d['passengerName']  as String? ?? pName;
          pPhone = d['passengerPhone'] as String?;
        }
      } catch (_) {}

      if (!mounted) return;
      await ref.read(driverChatProvider.notifier).connect(
        rideId,
        passengerName:  pName,
        passengerPhone: pPhone,
      );
      _scrollToBottom();
    });
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

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    ref.read(driverChatProvider.notifier).sendMessage(text);
    _ctrl.clear();
    _typingDebounce?.cancel();
    ref.read(driverChatProvider.notifier).emitTyping(false);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _onTyping(String _) {
    ref.read(driverChatProvider.notifier).emitTyping(true);
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      ref.read(driverChatProvider.notifier).emitTyping(false);
    });
  }

  void _quickReply(String text) {
    _ctrl.text = text;
    _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length));
  }

  Future<void> _pickMedia() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<_MediaType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MediaSheet(),
    );
    if (result == null || !mounted) return;

    try {
      if (result == _MediaType.videoGallery) {
        final xf = await _picker.pickVideo(source: ImageSource.gallery);
        if (xf == null || !mounted) return;
        setState(() {
          _localMedia.add(_LocalMedia(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            path: xf.path,
            isVideo: true,
            time: DateTime.now(),
          ));
        });
      } else {
        final src = result == _MediaType.camera
            ? ImageSource.camera
            : ImageSource.gallery;
        final xf = await _picker.pickImage(source: src, imageQuality: 75);
        if (xf == null || !mounted) return;
        setState(() {
          _localMedia.add(_LocalMedia(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            path: xf.path,
            isVideo: false,
            time: DateTime.now(),
          ));
        });
      }
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (_) {}
  }

  Future<void> _callPassenger() async {
    final phone = ref.read(driverChatProvider).passengerPhone;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Nomor telepon tidak tersedia',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: _C.primary,
        ));
      }
      return;
    }
    if (!mounted) return;
    final name = ref.read(driverChatProvider).passengerName
        ?? ref.read(driverProvider).activeTrip?.passengerName
        ?? 'Penumpang';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallSheet(name: name, phone: phone),
    );
  }

  Future<void> _sendLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Izin lokasi ditolak',
            style: GoogleFonts.plusJakartaSans()),
        backgroundColor: _C.primary,
      ));
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final link =
          'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
      ref.read(driverChatProvider.notifier).sendMessage('📍 Lokasi saya: $link');
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal mendapatkan lokasi',
            style: GoogleFonts.plusJakartaSans()),
        backgroundColor: _C.primary,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(driverChatProvider);
    final ds        = ref.watch(driverProvider);

    final messages    = chatState.messages;
    final pName       = chatState.passengerName
        ?? ds.activeTrip?.passengerName
        ?? 'Penumpang';
    final isTyping    = chatState.passengerIsTyping;
    final isConnected = chatState.status == DriverChatStatus.connected;
    final isHistoryMode = ds.activeTrip?.rideId == null && messages.isNotEmpty;

    if (isConnected) {
      ref.read(driverChatProvider.notifier).markRead();
    }

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _AppBar(
            name:   pName,
            online: isConnected,
            onCall: _callPassenger,
            onBack: () => Navigator.maybePop(context),
          ),
          _StatusBanner(status: chatState.status),
          Expanded(
            child: messages.isEmpty && _localMedia.isEmpty
                ? _EmptyChat()
                : _buildMessageList(messages, isTyping),
          ),
          if (!isHistoryMode) _QuickReplies(onTap: _quickReply),
          if (isHistoryMode) _buildHistoryHint(),
          if (!isHistoryMode) _InputBar(
            ctrl:       _ctrl,
            onSend:     _send,
            onMedia:    _pickMedia,
            onLocation: _sendLocation,
            onTyping:   _onTyping,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded, size: 14, color: _C.textSub),
          const SizedBox(width: 6),
          Text(
            'Perjalanan selesai · Riwayat chat',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: _C.textSub),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessageModel> messages, bool isTyping) {
    final List<_ChatItem> items = [
      ...messages.map((m) => _ChatItem.message(m)),
      ..._localMedia.map((m) => _ChatItem.media(m)),
    ]..sort((a, b) => a.time.compareTo(b.time));

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: items.length + (isTyping ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == items.length) return const _TypingBubble();
        final item = items[i];
        if (item.media != null) {
          return _MediaBubble(media: item.media!, isMe: true);
        }
        return _Bubble(msg: item.message!);
      },
    );
  }
}

class _LocalMedia {
  final String id, path;
  final bool   isVideo;
  final DateTime time;
  const _LocalMedia(
      {required this.id, required this.path,
       required this.isVideo, required this.time});
}

class _ChatItem {
  final ChatMessageModel? message;
  final _LocalMedia?      media;
  DateTime get time => message?.createdAt ?? media!.time;

  const _ChatItem._({this.message, this.media});
  factory _ChatItem.message(ChatMessageModel m) => _ChatItem._(message: m);
  factory _ChatItem.media(_LocalMedia m)        => _ChatItem._(media: m);
}

class _AppBar extends StatelessWidget {
  final String name;
  final bool   online;
  final VoidCallback onCall;
  final VoidCallback onBack;
  const _AppBar({
    required this.name, required this.online,
    required this.onCall, required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ')
        .where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_C.darkest, _C.dark],
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x330B0940),
              blurRadius: 12,
              offset: Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: onBack,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _C.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(initials,
                          style: GoogleFonts.plusJakartaSans(
                              color: _C.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ),
                  ),
                  if (online)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: _C.online,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
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
                    Text(name,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _AnimatedStatusDot(online: online),
                        const SizedBox(width: 5),
                        Text(
                          online ? 'Online' : 'Offline',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onCall,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.phone_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('LUNGO',
                    style: GoogleFonts.plusJakartaSans(
                        color: _C.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedStatusDot extends StatefulWidget {
  final bool online;
  const _AnimatedStatusDot({required this.online});
  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.online) {
      return Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(
              color: Colors.grey, shape: BoxShape.circle));
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: Color.lerp(_C.online, _C.accent, _ctrl.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _C.online.withValues(alpha: 0.5 * _ctrl.value),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final DriverChatStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    String text;
    Color  bg;
    Color  fg;

    if (status == DriverChatStatus.connecting) {
      text = 'Menghubungkan ke chat...';
      bg   = _C.light;
      fg   = _C.dark;
    } else if (status == DriverChatStatus.connected) {
      text = 'Terhubung — chat dengan penumpang aktif';
      bg   = const Color(0xFFDCFCE7);
      fg   = const Color(0xFF16A34A);
    } else if (status == DriverChatStatus.error) {
      text = 'Koneksi gagal — coba lagi nanti';
      bg   = const Color(0xFFFFE4E6);
      fg   = const Color(0xFFDC2626);
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: bg,
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: fg,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessageModel msg;
  const _Bubble({required this.msg});

  bool get _isMe => msg.senderRole == 'DRIVER';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: _isMe ? _C.bubbleSent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(_isMe ? 18 : 4),
            bottomRight: Radius.circular(_isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: _C.primary.withValues(alpha: 0.08),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              _isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(msg.message,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: _isMe ? Colors.white : const Color(0xFF1E293B))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 10, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('HH:mm').format(msg.createdAt),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: _isMe
                              ? Colors.white.withValues(alpha: 0.6)
                              : _C.textSub)),
                  if (_isMe) ...[
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
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaBubble extends StatelessWidget {
  final _LocalMedia media;
  final bool        isMe;
  const _MediaBubble({required this.media, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: isMe ? _C.bubbleSent : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(18),
            topRight:    Radius.circular(18),
            bottomLeft:  Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: _C.primary.withValues(alpha: 0.08),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: media.isVideo
            ? ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft:    Radius.circular(18),
                  topRight:   Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                child: Container(
                  width: 220, height: 160,
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(Icons.play_circle_fill_rounded,
                        color: Colors.white, size: 48),
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft:    Radius.circular(18),
                  topRight:   Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                child: Image.file(
                  File(media.path),
                  width: 220, height: 160, fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(18),
            topRight:    Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft:  Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: _C.primary.withValues(alpha: 0.08),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [1, 2, 3].map((i) => _Dot(delay: i * 200)).toList(),
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Container(
          width: 8, height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _C.textSub.withValues(alpha: 0.4 + _ctrl.value * 0.6),
            shape: BoxShape.circle,
          ),
        ),
      );
}

class _EmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: _C.light, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: _C.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Belum ada pesan',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: _C.dark)),
            const SizedBox(height: 6),
            Text('Mulai percakapan dengan penumpang',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: _C.textSub)),
          ],
        ),
      );
}

class _QuickReplies extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _QuickReplies({required this.onTap});

  static const _replies = [
    'Saya sudah di lokasi 📍',
    'Mohon tunggu sebentar',
    'Sedang menuju lokasi 🏍️',
    'Terima kasih 🙏',
    'Perjalanan dimulai ✅',
  ];

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        color: Colors.white,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: _replies.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => onTap(_replies[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _C.light,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.divider),
              ),
              alignment: Alignment.center,
              child: Text(_replies[i],
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _C.dark,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback          onSend;
  final VoidCallback          onMedia;
  final VoidCallback          onLocation;
  final ValueChanged<String>  onTyping;
  const _InputBar({
    required this.ctrl, required this.onSend,
    required this.onMedia, required this.onLocation,
    required this.onTyping,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
        child: Row(
          children: [
            _IconBtn(icon: Icons.attach_file_rounded, onTap: onMedia),
            const SizedBox(width: 6),
            _IconBtn(icon: Icons.location_on_outlined, onTap: onLocation),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: ctrl,
                onChanged: onTyping,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ketik pesan...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                      color: _C.textSub, fontSize: 14),
                  filled: true,
                  fillColor: _C.inputBg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                    color: _C.accent, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded,
                    color: _C.dark, size: 20),
              ),
            ),
          ],
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: _C.light, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: _C.primary, size: 20),
        ),
      );
}

enum _MediaType { gallery, camera, videoGallery }

class _MediaSheet extends StatelessWidget {
  const _MediaSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Kirim Media',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _C.darkest)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MediaBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Foto\nGaleri',
                  onTap: () =>
                      Navigator.pop(context, _MediaType.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MediaBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Foto\nKamera',
                  onTap: () =>
                      Navigator.pop(context, _MediaType.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MediaBtn(
                  icon: Icons.videocam_rounded,
                  label: 'Video\nGaleri',
                  onTap: () =>
                      Navigator.pop(context, _MediaType.videoGallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _MediaBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: _C.light,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: _C.primary, size: 28),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _C.primary)),
              ],
            ),
          ),
        ),
      );
}

class _CallSheet extends StatelessWidget {
  final String name, phone;
  const _CallSheet({required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ')
        .where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.darkest, _C.dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: _C.primary.withValues(alpha: 0.3),
              blurRadius: 32,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _C.accent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 3),
              ),
              child: Center(
                child: Text(initials,
                    style: GoogleFonts.plusJakartaSans(
                        color: _C.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 28)),
              ),
            ),
            const SizedBox(height: 14),
            Text(name,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            const SizedBox(height: 4),
            Text(phone,
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13)),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Batal',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text('Panggil',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    onPressed: () async {
                      Navigator.pop(context);
                      final clean =
                          phone.replaceAll(RegExp(r'[^\d+]'), '');
                      try {
                        await launchUrl(Uri(scheme: 'tel', path: clean),
                            mode: LaunchMode.platformDefault);
                      } catch (_) {}
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.accent,
                      foregroundColor: _C.dark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
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
