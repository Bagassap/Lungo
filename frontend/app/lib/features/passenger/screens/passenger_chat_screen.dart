import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../booking/providers/booking_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message_model.dart';

// ─── colors ─────────────────────────────────────────────────────────────────
class _C {
  static const bg             = Color(0xFFF0F4FF);
  static const bubbleSent     = Color(0xFF0540F2);
  static const bubbleReceived = Colors.white;
  static const accent         = Color(0xFFF2CB05);
  static const primary        = Color(0xFF0540F2);
  static const primaryDark    = Color(0xFF04198C);
  static const primaryLight   = Color(0xFFE8EEFF);
  static const online         = Color(0xFF22C55E);
  static const divider        = Color(0xFFD8E3FF);
  static const inputBg        = Color(0xFFECF3FF);
  static const chip           = Color(0xFFECF3FF);
  static const shadow         = Color(0x140540F2);
  static const readBlue       = Color(0xFF53BDEB);
  static const listBg         = Color(0xFFF8FAFF);
}

// ═══════════════════════════════════════════════════════════════════════════
//  CHAT LIST SCREEN  (WhatsApp-style)
// ═══════════════════════════════════════════════════════════════════════════
class PassengerChatScreen extends ConsumerWidget {
  const PassengerChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider);
    final chat    = ref.watch(chatProvider);

    final hasRide = booking.ride != null &&
        (booking.status == BookingStatus.active ||
            booking.status == BookingStatus.searching);

    final driverName = chat.driverName ?? 'Driver Anda';
    final lastMsg    = chat.messages.isNotEmpty ? chat.messages.last : null;
    final lastMsgText = lastMsg?.message ?? (hasRide ? 'Ketuk untuk mulai chat' : '');
    final lastTime = lastMsg != null
        ? DateFormat('HH:mm').format(lastMsg.createdAt.toLocal())
        : '';
    final unread = hasRide
        ? chat.messages.where((m) => !m.isFromPassenger && !m.isRead).length
        : 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.listBg,
        body: Column(
          children: [
            _ListAppBar(),
            Expanded(
              child: (hasRide || chat.messages.isNotEmpty)
                  ? _buildChatList(context, ref, driverName, lastMsgText,
                      lastTime, unread, chat, booking)
                  : _buildEmpty(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(
    BuildContext context,
    WidgetRef ref,
    String driverName,
    String lastMsg,
    String time,
    int unread,
    ChatState chat,
    BookingState booking,
  ) {
    return ListView(
      children: [
        _ChatTile(
          name:    driverName,
          lastMsg: lastMsg,
          time:    time,
          unread:  unread,
          isOnline: chat.connectionStatus == ChatConnectionStatus.connected,
          onTap: () {
            final rideId = booking.ride?.id;
            if (rideId != null &&
                chat.connectionStatus != ChatConnectionStatus.connected) {
              ref.read(chatProvider.notifier).connect(rideId);
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PassengerChatDetail(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
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
                      color: _C.primaryLight.withValues(alpha: 0.6),
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
                          offset: Offset(0, 8),
                        ),
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
                              color: Color(0x40F2CB05),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: _C.primary, size: 16),
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
                      child: const Icon(Icons.notifications_active_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Chat',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: _C.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesan ojek terlebih dahulu\nuntuk bisa chat dengan driver',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.55,
                color: const Color(0xFF9898CC),
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/destination'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0540F2), Color(0xFF6C5CE7)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x380540F2),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.motorcycle_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 7),
                    Text(
                      'Pesan Ojek Sekarang',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
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
          colors: [Color(0xFF0B0940), Color(0xFF04198C)],
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
              borderRadius: BorderRadius.circular(20),
            ),
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
                            color: const Color(0xFF0B0940))),
                    const SizedBox(height: 3),
                    Text(lastMsg,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: unread > 0
                                ? const Color(0xFF0B0940)
                                : const Color(0xFF9898CC),
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
                            color: unread > 0
                                ? _C.primary
                                : const Color(0xFF9898CC))),
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

// ═══════════════════════════════════════════════════════════════════════════
//  CHAT DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class PassengerChatDetail extends ConsumerStatefulWidget {
  const PassengerChatDetail({super.key});

  @override
  ConsumerState<PassengerChatDetail> createState() =>
      PassengerChatDetailState();
}

class PassengerChatDetailState extends ConsumerState<PassengerChatDetail>
    with TickerProviderStateMixin {
  final _msgController   = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker     = ImagePicker();

  late final AnimationController _bannerAnim;
  late final AnimationController _dotAnim;

  Timer? _typingDebounce;
  bool   _isTyping = false;

  static const _quickReplies = [
    'Tolong segera 🙏',
    'Saya tunggu di sini',
    'Sudah dekat?',
    'OK siap!',
    'OK, siap!',
    'Terima kasih 🙏',
  ];

  @override
  void initState() {
    super.initState();
    _bannerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _dotAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryConnect();
      _scrollToBottom();
    });
  }

  void _tryConnect() {
    final booking = ref.read(bookingProvider);
    final rideId  = booking.ride?.id;
    if (rideId != null &&
        (booking.status == BookingStatus.active ||
            booking.status == BookingStatus.searching)) {
      ref.read(chatProvider.notifier).connect(rideId);
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _bannerAnim.dispose();
    _dotAnim.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String v) {
    final typing = v.trim().isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      ref.read(chatProvider.notifier).emitTyping(typing);
    }
    _typingDebounce?.cancel();
    if (typing) {
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        _isTyping = false;
        ref.read(chatProvider.notifier).emitTyping(false);
      });
    }
  }

  void _send([String? preset]) {
    final text = (preset ?? _msgController.text).trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();

    final booking = ref.read(bookingProvider);
    final hasRide = booking.ride != null &&
        (booking.status == BookingStatus.active ||
            booking.status == BookingStatus.searching);
    if (!hasRide) return;
    ref.read(chatProvider.notifier).sendMessage(text);
    if (preset == null) _msgController.clear();
    _isTyping = false;
    ref.read(chatProvider.notifier).emitTyping(false);
    Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _pickMedia() async {
    final result = await showModalBottomSheet<_MediaType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MediaSheet(),
    );
    if (result == null || !mounted) return;
    HapticFeedback.lightImpact();

    final booking = ref.read(bookingProvider);
    final hasRide = booking.ride != null &&
        (booking.status == BookingStatus.active ||
            booking.status == BookingStatus.searching);
    if (!hasRide) return;

    if (result == _MediaType.videoGallery) {
      await _imagePicker.pickVideo(source: ImageSource.gallery);
    } else {
      final source = result == _MediaType.camera
          ? ImageSource.camera
          : ImageSource.gallery;
      await _imagePicker.pickImage(source: source, imageQuality: 70);
    }
    Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
  }

  Future<void> _sendLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Izin lokasi ditolak',
                style: GoogleFonts.plusJakartaSans()),
            backgroundColor: _C.primaryDark),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final link =
          'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
      _send('📍 Lokasi saya: $link');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Gagal mendapatkan lokasi',
                style: GoogleFonts.plusJakartaSans()),
            backgroundColor: _C.primaryDark),
      );
    }
  }

  Future<void> _callDriver() async {
    final rawPhone = ref.read(chatProvider).driverPhone ?? '';
    if (rawPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nomor driver tidak tersedia',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: _C.primaryDark,
        ),
      );
      return;
    }
    if (!mounted) return;
    final name = ref.read(chatProvider).driverName ?? 'Driver';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallSheet(name: name, phone: rawPhone),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    final chat    = ref.watch(chatProvider);
    final hasRide = booking.ride != null &&
        (booking.status == BookingStatus.active ||
            booking.status == BookingStatus.searching);

    ref.listen(chatProvider.select((s) => s.messages.length), (_, _) {
      Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
    });

    final isConnecting =
        chat.connectionStatus == ChatConnectionStatus.connecting;
    final isError = chat.connectionStatus == ChatConnectionStatus.error;

    if (isConnecting || isError) {
      _bannerAnim.forward();
    } else {
      _bannerAnim.reverse();
    }

    final hasHistory = !hasRide && chat.messages.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            _buildAppBar(booking, chat, hasRide),
            if (hasRide) _buildConnectionBanner(chat),
            Expanded(
              child: hasRide
                  ? _buildLiveChat(chat, booking)
                  : hasHistory
                      ? _buildHistoryView(chat)
                      : _buildNoRideState(),
            ),
            if (hasRide) _buildInputBar(hasRide, chat),
            if (hasHistory) _buildHistoryHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryView(ChatState chat) {
    final messages = chat.messages;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (_, i) => _buildBubble(messages[i], i, messages),
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
          const Icon(Icons.history_rounded, size: 14, color: Color(0xFF9898CC)),
          const SizedBox(width: 6),
          Text(
            'Perjalanan selesai · Riwayat chat',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: const Color(0xFF9898CC)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BookingState booking, ChatState chat, bool hasRide) {
    final driverName = chat.driverName ?? (hasRide ? 'Driver Anda' : 'Chat');
    final isOnline =
        hasRide && chat.connectionStatus == ChatConnectionStatus.connected;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0940), Color(0xFF04198C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              _DriverAvatar(name: driverName, isOnline: isOnline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverName,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _PulseDot(active: isOnline),
                        const SizedBox(width: 5),
                        Text(
                          hasRide
                              ? _connectionLabel(chat.connectionStatus)
                              : 'Online',
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
                  onTap: _callDriver,
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

  String _connectionLabel(ChatConnectionStatus s) => switch (s) {
        ChatConnectionStatus.connected    => 'Online',
        ChatConnectionStatus.connecting   => 'Menghubungkan...',
        ChatConnectionStatus.error        => 'Gagal terhubung',
        ChatConnectionStatus.disconnected => 'Offline',
      };

  Widget _buildConnectionBanner(ChatState chat) {
    final isError = chat.connectionStatus == ChatConnectionStatus.error;
    return SizeTransition(
      sizeFactor:
          CurvedAnimation(parent: _bannerAnim, curve: Curves.easeOut),
      child: Container(
        width: double.infinity,
        color: isError ? const Color(0xFFFF3B30) : _C.primary,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isError)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            if (isError)
              const Icon(Icons.wifi_off_rounded,
                  color: Colors.white, size: 14),
            const SizedBox(width: 8),
            Text(
              isError
                  ? (chat.errorMessage ?? 'Tidak dapat terhubung')
                  : 'Menghubungkan ke chat...',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRideState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: _C.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('Belum ada perjalanan aktif',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9898CC))),
          const SizedBox(height: 6),
          Text('Chat akan tersedia saat kamu memesan ojek',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: const Color(0xFFB0B4D8))),
        ],
      ),
    );
  }

  Widget _buildLiveChat(ChatState chat, BookingState booking) {
    final messages = chat.messages;
    return Column(
      children: [
        _RideInfoBanner(booking: booking),
        Expanded(
          child: messages.isEmpty
              ? _buildMessagesPlaceholder()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount:
                      messages.length + (chat.driverIsTyping ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == messages.length && chat.driverIsTyping) {
                      return _TypingIndicator(dotAnim: _dotAnim);
                    }
                    return _buildBubble(messages[i], i, messages);
                  },
                ),
        ),
        _QuickRepliesBar(replies: _quickReplies, onTap: _send),
      ],
    );
  }

  Widget _buildMessagesPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.waving_hand_rounded,
              size: 40, color: _C.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Mulai percakapan dengan driver Anda',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: const Color(0xFF9898CC))),
        ],
      ),
    );
  }

  Widget _buildBubble(
      ChatMessageModel msg, int index, List<ChatMessageModel> all) {
    final isMe   = msg.isFromPassenger;
    final showDate = index == 0 ||
        !_sameDay(all[index - 1].createdAt, msg.createdAt);
    return Column(
      children: [
        if (showDate) _DateChip(date: msg.createdAt),
        _LiveBubble(msg: msg, isMe: isMe),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildInputBar(bool hasRide, ChatState chat) {
    final connected = !hasRide ||
        chat.connectionStatus == ChatConnectionStatus.connected;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: _C.shadow, blurRadius: 12, offset: Offset(0, -3))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Material(
                color: _C.primaryLight,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _pickMedia,
                  borderRadius: BorderRadius.circular(24),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.attach_file_rounded,
                        color: _C.primary, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: _C.primaryLight,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _sendLocation,
                  borderRadius: BorderRadius.circular(24),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.location_on_rounded,
                        color: _C.primary, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.inputBg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextField(
                    controller: _msgController,
                    onChanged: _onTextChanged,
                    enabled: connected,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: const Color(0xFF1A1A3E)),
                    decoration: InputDecoration(
                      hintText: connected
                          ? 'Ketik pesan...'
                          : 'Menghubungkan...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF9898CC), fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: connected
                      ? const LinearGradient(
                          colors: [Color(0xFFF2CB05), Color(0xFFC4E040)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: connected ? null : const Color(0xFFDDDDEE),
                  shape: BoxShape.circle,
                  boxShadow: connected
                      ? [
                          BoxShadow(
                              color: _C.accent.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: connected ? _send : null,
                    borderRadius: BorderRadius.circular(24),
                    child: const Center(
                      child: Icon(Icons.send_rounded,
                          color: _C.primary, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── shared widgets ──────────────────────────────────────────────────────────

class _DriverAvatar extends StatelessWidget {
  final String? name;
  final bool isOnline;
  const _DriverAvatar({this.name, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final initials = name != null
        ? name!
            .trim()
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0])
            .take(2)
            .join()
        : '?';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _C.accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(initials.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                    color: _C.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _C.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  final bool active;
  const _PulseDot({required this.active});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
              color: Color(0xFF9898CC), shape: BoxShape.circle));
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: Color.lerp(_C.online, _C.accent, _ctrl.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _C.online.withValues(alpha: 0.5 * _ctrl.value),
              blurRadius: 6,
            )
          ],
        ),
      ),
    );
  }
}

class _RideInfoBanner extends StatelessWidget {
  final BookingState booking;
  const _RideInfoBanner({required this.booking});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.divider),
          boxShadow: const [
            BoxShadow(color: _C.shadow, blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.motorcycle_rounded,
                  color: _C.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Perjalanan Aktif',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: _C.primary)),
                  Text(
                    booking.ride?.id != null
                        ? 'ID: ${booking.ride!.id.substring(0, 8)}...'
                        : '-',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: const Color(0xFF9898CC)),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _C.online.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                booking.status.name.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.online),
              ),
            ),
          ],
        ),
      );
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
            color: _C.divider,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 11, color: const Color(0xFF7B7CBB))),
      ),
    );
  }
}

class _LiveBubble extends StatelessWidget {
  final ChatMessageModel msg;
  final bool isMe;
  const _LiveBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(msg.createdAt.toLocal());
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            bottom: 6, left: isMe ? 60 : 0, right: isMe ? 0 : 60),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: isMe ? _C.bubbleSent : _C.bubbleReceived,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(18),
            topRight:    const Radius.circular(18),
            bottomLeft:  Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: isMe
                  ? _C.primary.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(msg.message,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: isMe ? Colors.white : const Color(0xFF1A1A3E),
                    height: 1.4)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.65)
                            : const Color(0xFF9898CC))),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 14,
                    color: msg.isRead
                        ? _C.readBlue
                        : Colors.white.withValues(alpha: 0.65),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final AnimationController dotAnim;
  const _TypingIndicator({required this.dotAnim});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6, right: 60),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(18),
              topRight:    Radius.circular(18),
              bottomLeft:  Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: dotAnim,
                builder: (_, child) {
                  final offset =
                      ((dotAnim.value * 3 - i) % 1.0).clamp(0.0, 1.0);
                  final bounce =
                      offset < 0.5 ? offset * 2 : (1 - offset) * 2;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    transform:
                        Matrix4.translationValues(0, -6 * bounce, 0),
                    decoration: BoxDecoration(
                      color: Color.lerp(_C.primaryLight, _C.primary, bounce),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ),
      );
}

class _QuickRepliesBar extends StatelessWidget {
  final List<String> replies;
  final void Function(String) onTap;
  const _QuickRepliesBar({required this.replies, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: replies.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => onTap(replies[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _C.chip,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.divider),
              ),
              child: Text(replies[i],
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _C.primary)),
            ),
          ),
        ),
      );
}

// ─── media picker sheet ───────────────────────────────────────────────────────
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
                  color: _C.primaryDark)),
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
  final String label;
  final VoidCallback onTap;
  const _MediaBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: _C.primaryLight,
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

// ─── in-app call sheet ────────────────────────────────────────────────────────

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
          colors: [Color(0xFF0B0940), Color(0xFF04198C)],
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
                      foregroundColor: _C.primary,
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
