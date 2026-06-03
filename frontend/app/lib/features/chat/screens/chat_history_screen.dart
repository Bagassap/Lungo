import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../passenger/models/chat_message_model.dart';

class ChatHistoryArgs {
  final String rideId;
  final String title;
  const ChatHistoryArgs({required this.rideId, required this.title});
}

class ChatHistoryScreen extends StatefulWidget {
  final ChatHistoryArgs args;
  const ChatHistoryScreen({super.key, required this.args});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final _dio = ApiClient.create();
  List<ChatMessageModel> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    try {
      final resp = await _dio.get('/chat/${widget.args.rideId}/messages');
      if (!mounted) return;
      final list = (resp.data as List<dynamic>?) ?? [];
      setState(() {
        _messages = list
            .map((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat riwayat chat.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0940),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.args.title,
              style: const TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            const Text(
              'Riwayat Chat',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _messages.isEmpty
                  ? _buildEmpty()
                  : _buildMessages(),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(
                fontFamily: 'Satoshi', fontSize: 14, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() { _loading = true; _error = null; });
                _fetchMessages();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0540F2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Coba Lagi',
                  style: TextStyle(fontFamily: 'Satoshi', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 36, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            const Text('Tidak ada pesan', style: TextStyle(
                fontFamily: 'Satoshi', fontWeight: FontWeight.w700,
                fontSize: 15, color: Color(0xFF374151))),
            const SizedBox(height: 6),
            const Text('Belum ada percakapan pada perjalanan ini.',
                style: TextStyle(fontFamily: 'Satoshi', fontSize: 13,
                    color: Color(0xFF9CA3AF))),
          ],
        ),
      );

  Widget _buildMessages() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPad),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final isPassenger = msg.senderRole == 'PASSENGER';

        final showDate = i == 0 ||
            !_sameDay(_messages[i - 1].createdAt, msg.createdAt);
        return Column(
          children: [
            if (showDate) _DateSeparator(date: msg.createdAt),
            _MessageBubble(msg: msg, isPassenger: isPassenger),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        const Expanded(child: Divider(color: Color(0xFFD1D5DB))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(
              fontFamily: 'Satoshi', fontSize: 11,
              color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
        ),
        const Expanded(child: Divider(color: Color(0xFFD1D5DB))),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel msg;
  final bool isPassenger;
  const _MessageBubble({required this.msg, required this.isPassenger});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(msg.createdAt.toLocal());
    final align = isPassenger ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isPassenger
        ? const Color(0xFF0540F2)
        : const Color(0xFF0B0940);
    final textColor = Colors.white;
    final radius = isPassenger
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment:
                isPassenger ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isPassenger) ...[
                Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(right: 6, bottom: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B0940),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_bike_rounded,
                      size: 14, color: Colors.white),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: bubbleColor.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(msg.message,
                      style: TextStyle(
                        fontFamily: 'Satoshi',
                        fontSize: 14,
                        color: textColor,
                        height: 1.4,
                      )),
                ),
              ),
              if (isPassenger) ...[
                Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(left: 6, bottom: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0540F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 14, color: Colors.white),
                ),
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: isPassenger ? 0 : 36,
              right: isPassenger ? 36 : 0,
              top: 2,
            ),
            child: Text(timeStr, style: const TextStyle(
                fontFamily: 'Satoshi', fontSize: 10,
                color: Color(0xFF9CA3AF))),
          ),
        ],
      ),
    );
  }
}
