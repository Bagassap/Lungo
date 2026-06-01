class ChatMessageModel {
  final String id;
  final String rideId;
  final String senderId;
  final String senderRole;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  bool get isFromPassenger => senderRole == 'PASSENGER';

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      ChatMessageModel(
        id: json['id'] as String? ?? '',
        rideId: json['rideId'] as String? ?? '',
        senderId: json['senderId'] as String? ?? '',
        senderRole: json['senderRole'] as String? ?? 'DRIVER',
        message: json['message'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  ChatMessageModel copyWith({bool? isRead}) => ChatMessageModel(
        id: id,
        rideId: rideId,
        senderId: senderId,
        senderRole: senderRole,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
