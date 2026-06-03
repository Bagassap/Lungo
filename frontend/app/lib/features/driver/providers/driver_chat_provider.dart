import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../passenger/models/chat_message_model.dart';

enum DriverChatStatus { disconnected, connecting, connected, error }

class DriverChatState {
  final List<ChatMessageModel> messages;
  final DriverChatStatus status;
  final bool passengerIsTyping;
  final String? currentRideId;
  final String? passengerName;
  final String? passengerPhone;
  final String? error;

  const DriverChatState({
    this.messages        = const [],
    this.status          = DriverChatStatus.disconnected,
    this.passengerIsTyping = false,
    this.currentRideId,
    this.passengerName,
    this.passengerPhone,
    this.error,
  });

  DriverChatState copyWith({
    List<ChatMessageModel>? messages,
    DriverChatStatus?       status,
    bool?                   passengerIsTyping,
    String?                 currentRideId,
    String?                 passengerName,
    String?                 passengerPhone,
    String?                 error,
  }) =>
      DriverChatState(
        messages:           messages          ?? this.messages,
        status:             status            ?? this.status,
        passengerIsTyping:  passengerIsTyping ?? this.passengerIsTyping,
        currentRideId:      currentRideId     ?? this.currentRideId,
        passengerName:      passengerName     ?? this.passengerName,
        passengerPhone:     passengerPhone    ?? this.passengerPhone,
        error:              error,
      );
}

class DriverChatNotifier extends StateNotifier<DriverChatState> {
  sio.Socket? _socket;
  Timer?      _typingTimer;
  static const _prefKey = 'driver_chat_last_ride_id';

  DriverChatNotifier() : super(const DriverChatState()) {
    _autoLoadHistory();
  }

  Future<void> _autoLoadHistory() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    if (state.status == DriverChatStatus.connected) return;
    if (state.messages.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final savedRideId = prefs.getString(_prefKey);
    if (savedRideId != null) {
      await _loadHistoryFromApi(savedRideId);
    }
  }

  Future<void> _loadHistoryFromApi(String rideId) async {
    try {
      final resp = await ApiClient.create().get('/chat/$rideId/messages');
      if (!mounted) return;
      if (state.status == DriverChatStatus.connected) return;
      final raw = resp.data;
      if (raw == null) return;
      final list = (raw as List)
          .map((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (list.isNotEmpty) {
        state = state.copyWith(messages: list, currentRideId: rideId);
      }
    } catch (_) {}
  }

  Future<void> connect(
    String rideId, {
    String? passengerName,
    String? passengerPhone,
  }) async {
    if (state.status == DriverChatStatus.connected &&
        state.currentRideId == rideId) {
      return;
    }

    _disconnectSocket();

    state = state.copyWith(
      status:         DriverChatStatus.connecting,
      currentRideId:  rideId,
      passengerName:  passengerName,
      passengerPhone: passengerPhone,
      messages:       [],
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, rideId);

    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      state = state.copyWith(
        status: DriverChatStatus.error,
        error:  'Token tidak ditemukan.',
      );
      return;
    }

    _socket = sio.io(
      '${ApiClient.wsBaseUrl}/chat',
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        if (!mounted) { return; }
        state = state.copyWith(status: DriverChatStatus.connected);
        _socket!.emit('joinRoom', {'rideId': rideId});
      })
      ..onDisconnect((_) {
        if (mounted) state = state.copyWith(status: DriverChatStatus.disconnected);
      })
      ..onConnectError((_) {
        if (mounted) {
          state = state.copyWith(
            status: DriverChatStatus.error,
            error:  'Gagal terhubung ke server chat.',
          );
        }
      })
      ..on('chatHistory', (data) {
        if (!mounted) return;
        final list = (data as List)
            .map((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        state = state.copyWith(messages: list);
      })
      ..on('newMessage', (data) {
        if (!mounted) return;
        final msg = ChatMessageModel.fromJson(
            Map<String, dynamic>.from(data as Map));
        state = state.copyWith(messages: [...state.messages, msg]);
      })
      ..on('userTyping', (data) {
        if (!mounted) return;
        final d = Map<String, dynamic>.from(data as Map);
        final typing = d['isTyping'] as bool? ?? false;
        state = state.copyWith(passengerIsTyping: typing);
        if (typing) {
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) state = state.copyWith(passengerIsTyping: false);
          });
        }
      })
      ..on('messagesRead', (_) {
        if (!mounted) return;
        final updated = state.messages.map((m) => m.copyWith(isRead: true)).toList();
        state = state.copyWith(messages: updated);
      });

    _socket!.connect();
  }

  void sendMessage(String text) {
    final rideId = state.currentRideId;
    if (_socket == null || rideId == null || state.status != DriverChatStatus.connected) return;
    _socket!.emit('sendMessage', {
      'rideId':     rideId,
      'message':    text,
      'senderRole': 'DRIVER',
    });
  }

  void emitTyping(bool isTyping) {
    final rideId = state.currentRideId;
    if (_socket == null || rideId == null) return;
    _socket!.emit('typing', {'rideId': rideId, 'isTyping': isTyping});
  }

  void markRead() {
    final rideId = state.currentRideId;
    if (_socket == null || rideId == null) return;
    _socket!.emit('markRead', {'rideId': rideId});
  }

  void _disconnectSocket() {
    _typingTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void disconnect() {
    _disconnectSocket();

  }

  @override
  void dispose() {
    _disconnectSocket();
    super.dispose();
  }
}

final driverChatProvider =
    StateNotifierProvider<DriverChatNotifier, DriverChatState>(
        (_) => DriverChatNotifier());
