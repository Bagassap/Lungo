import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _loading = true;
  Map<String, dynamic>? _activeRide;

  @override
  void initState() {
    super.initState();
    _loadActiveRide();
  }

  Future<void> _loadActiveRide() async {
    try {
      final r = await DioClient.create().get('/drivers/active-ride');
      if (mounted) {
        setState(() {
          _activeRide = r.data is Map<String, dynamic>
              ? r.data as Map<String, dynamic>
              : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryColor))
                : _activeRide != null
                    ? _buildChatList()
                    : _buildEmpty(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0940), Color(0xFF04198C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.electric_moped_rounded,
                color: AppColors.primaryDark, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Chat',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'LUNGO',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: AppColors.primaryDark,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final rideId = _activeRide!['rideId'] as String? ?? '';
    final passengerName =
        _activeRide!['passengerName'] as String? ?? 'Penumpang';
    final initial = passengerName.isNotEmpty
        ? passengerName[0].toUpperCase()
        : 'P';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => _ChatDetailScreen(rideId: rideId)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0540F2), Color(0xFF6C5CE7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 1, bottom: 1,
                        child: Container(
                          width: 13, height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
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
                        Text(
                          passengerName,
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF0D1240),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Ketuk untuk mulai chat',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 12,
                            color: Color(0xFF7B8FC0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'AKTIF',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                      color: AppColors.primaryColor.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primaryColor.withValues(alpha: 0.1),
                          width: 1.5),
                    ),
                  ),
                  Container(
                    width: 90, height: 90,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0540F2), Color(0xFF04198C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x400540F2),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chat_bubble_rounded,
                        color: Colors.white, size: 38),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x40F2CB05), blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.electric_moped_rounded,
                          color: AppColors.primaryDark, size: 14),
                    ),
                  ),
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Chat',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: Color(0xFF0D1240),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chat dengan penumpang akan\nmuncul saat perjalanan aktif',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 13,
                height: 1.55,
                color: Color(0xFF7B8FC0),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0540F2), Color(0xFF04198C)],
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.electric_moped_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 7),
                  Text(
                    'Menunggu Perjalanan Aktif',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatDetailScreen extends StatefulWidget {
  final String rideId;
  const _ChatDetailScreen({required this.rideId});

  @override
  State<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<_ChatDetailScreen> {
  io.Socket? _socket;
  final List<_Msg> _messages = [];
  final _ctrl     = TextEditingController();
  final _scroll   = ScrollController();
  bool _connected = false;
  String? _myId;
  bool _isTyping  = false;
  Timer? _typingTimer;

  final _fmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _typingTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _myId = await SecureStorage.getUserId();

    try {
      final r = await DioClient.create()
          .get('/chat/${widget.rideId}/messages');
      final list = r.data is List ? r.data as List : <dynamic>[];
      if (mounted) {
        setState(() {
          _messages.addAll(list.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return _Msg(
              text: (m['message'] as String?) ?? '',
              isMe: (m['senderId'] as String?) == _myId,
              time: m['createdAt'] != null
                  ? DateTime.tryParse(m['createdAt'] as String) ??
                      DateTime.now()
                  : DateTime.now(),
            );
          }));
        });
      }
    } catch (_) {}

    final token = await SecureStorage.getAccessToken();
    _socket = io.io(
      '${ApiConstants.wsUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
    _socket!.on('connect', (_) {
      _socket!.emit('joinRoom', {'rideId': widget.rideId});
      if (mounted) setState(() => _connected = true);
    });
    _socket!.on('newMessage', (data) {
      if (!mounted) return;
      final m = Map<String, dynamic>.from(data as Map);
      setState(() {
        _messages.add(_Msg(
          text: (m['message'] as String?) ?? '',
          isMe: (m['senderId'] as String?) == _myId,
          time: DateTime.now(),
        ));
      });
      _scrollBottom();
    });
    _socket!.on('typing', (_) {
      if (!mounted) return;
      setState(() => _isTyping = true);
      _typingTimer?.cancel();
      _typingTimer = Timer(
          const Duration(seconds: 3), () {
        if (mounted) setState(() => _isTyping = false);
      });
    });
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || !_connected) return;
    _ctrl.clear();
    _socket!.emit('sendMessage', {
      'rideId': widget.rideId,
      'message': text,
      'senderRole': 'DRIVER',
    });
    setState(() {
      _messages.add(_Msg(text: text, isMe: true, time: DateTime.now()));
    });
    _scrollBottom();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  void _onTyping(String v) {
    if (v.isNotEmpty && _connected) {
      _socket!.emit('typing', {'rideId': widget.rideId});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 36,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.primaryColor),
        ),
        titleSpacing: 8,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryColor,
              child: const Text('P',
                  style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Penumpang',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  _connected ? 'Terhubung' : 'Menghubungkan...',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 11,
                    color: _connected
                        ? const Color(0xFF16A34A)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Mulai percakapan dengan penumpang',
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount:
                        _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_isTyping && i == _messages.length) {
                        return _TypingIndicator();
                      }
                      return _BubbleTile(
                        msg: _messages[i],
                        fmt: _fmt,
                      );
                    },
                  ),
          ),
          _InputBar(ctrl: _ctrl, onSend: _send, onTyping: _onTyping),
        ],
      ),
    );
  }
}

class _BubbleTile extends StatelessWidget {
  final _Msg msg;
  final DateFormat fmt;
  const _BubbleTile({required this.msg, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryColor,
              child: const Text('P',
                  style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primaryColor
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                      Radius.circular(isMe ? 18 : 4),
                  bottomRight:
                      Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor
                        .withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 13,
                      color: isMe
                          ? Colors.white
                          : AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fmt.format(msg.time),
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.65)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 34),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor
                        .withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Container(
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final ValueChanged<String> onTyping;

  const _InputBar({
    required this.ctrl,
    required this.onSend,
    required this.onTyping,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color:
                  AppColors.primaryColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: ctrl,
                  onChanged: onTyping,
                  style: const TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    color: AppColors.primaryDark,
                  ),
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Tulis pesan...',
                    hintStyle: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor
                          .withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );
}

class _Msg {
  final String text;
  final bool isMe;
  final DateTime time;
  const _Msg({required this.text, required this.isMe, required this.time});
}
