import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/chat_message_model.dart';

enum ChatConnectionStatus { disconnected, connecting, connected, error }

class ChatState {
  final List<ChatMessageModel> messages;
  final ChatConnectionStatus connectionStatus;
  final bool driverIsTyping;
  final String? currentRideId;
  final String? errorMessage;
  final String? driverName;
  final String? driverPhone;

  const ChatState({
    this.messages = const [],
    this.connectionStatus = ChatConnectionStatus.disconnected,
    this.driverIsTyping = false,
    this.currentRideId,
    this.errorMessage,
    this.driverName,
    this.driverPhone,
  });

  ChatState copyWith({
    List<ChatMessageModel>? messages,
    ChatConnectionStatus? connectionStatus,
    bool? driverIsTyping,
    String? currentRideId,
    String? errorMessage,
    String? driverName,
    String? driverPhone,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        connectionStatus: connectionStatus ?? this.connectionStatus,
        driverIsTyping: driverIsTyping ?? this.driverIsTyping,
        currentRideId: currentRideId ?? this.currentRideId,
        errorMessage: errorMessage,
        driverName: driverName ?? this.driverName,
        driverPhone: driverPhone ?? this.driverPhone,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  sio.Socket? _socket;
  Timer? _typingTimer;
  static const _prefKey = 'chat_last_ride_id';

  ChatNotifier() : super(const ChatState()) {
    _autoLoadHistory();
  }

  Future<void> _autoLoadHistory() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    if (state.connectionStatus == ChatConnectionStatus.connected) return;
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
      if (state.connectionStatus == ChatConnectionStatus.connected) return;
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

  Future<void> connect(String rideId) async {
    if (state.connectionStatus == ChatConnectionStatus.connected &&
        state.currentRideId == rideId) {
      return;
    }

    _disconnectSocket();

    state = state.copyWith(
      connectionStatus: ChatConnectionStatus.connecting,
      currentRideId: rideId,
      messages: [],
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, rideId);

    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      state = state.copyWith(
        connectionStatus: ChatConnectionStatus.error,
        errorMessage: 'Token tidak ditemukan, silakan login ulang.',
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
        state = state.copyWith(
            connectionStatus: ChatConnectionStatus.connected);
        _socket!.emit('joinRoom', {'rideId': rideId});
      })
      ..onDisconnect((_) {
        if (mounted) {
          state = state.copyWith(
              connectionStatus: ChatConnectionStatus.disconnected);
        }
      })
      ..onConnectError((_) {
        if (mounted) {
          state = state.copyWith(
            connectionStatus: ChatConnectionStatus.error,
            errorMessage: 'Gagal terhubung ke server chat.',
          );
        }
      })
      ..on('chatHistory', (data) {
        if (!mounted) return;
        final list = (data as List)
            .map((e) =>
                ChatMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
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
        final isTyping = d['isTyping'] as bool? ?? false;
        state = state.copyWith(driverIsTyping: isTyping);
        if (isTyping) {
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) state = state.copyWith(driverIsTyping: false);
          });
        }
      })
      ..on('messagesRead', (_) {
        if (!mounted) return;
        final updated = state.messages
            .map((m) => m.copyWith(isRead: true))
            .toList();
        state = state.copyWith(messages: updated);
      });

    _socket!.connect();
  }

  void sendMessage(String text) {
    final rideId = state.currentRideId;
    if (_socket == null ||
        rideId == null ||
        state.connectionStatus != ChatConnectionStatus.connected) {
      return;
    }

    _socket!.emit('sendMessage', {
      'rideId': rideId,
      'message': text,
      'senderRole': 'PASSENGER',
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

  void setDriverInfo(String name, String phone) {
    state = state.copyWith(driverName: name, driverPhone: phone);
  }

  void _disconnectSocket() {
    _typingTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void disconnect() {
    _disconnectSocket();
    // Preserve messages and currentRideId for history display
  }

  @override
  void dispose() {
    _disconnectSocket();
    super.dispose();
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((_) => ChatNotifier());
