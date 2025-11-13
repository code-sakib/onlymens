import 'package:cloud_firestore/cloud_firestore.dart';

/// Message model for chat messages
class MessageModel {
  final String message;
  final String senderId;
  final String receiverId;
  final Timestamp timestamp;
  final List<String> readBy;

  MessageModel({
    required this.message,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    this.readBy = const [],
  });

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': timestamp,
      'readBy': readBy,
    };
  }

  /// Create from Firestore document
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      message: map['message'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
      readBy: List<String>.from(map['readBy'] ?? []),
    );
  }

  /// Check if message was read by a specific user
  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }
}
