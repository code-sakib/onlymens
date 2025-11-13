// lib/features/betterwbro/chat/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _getChatRoomId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  /// Create-or-merge the chat doc. Pass display meta so list can render immediately.
  Future<String> ensureChatRoom(
    String userId,
    String otherUserId, {
    Map<String, dynamic>? currentUserMeta, // e.g. {'name': 'You', 'img': '...'}
    Map<String, dynamic>? otherUserMeta,   // e.g. {'name': 'Jake', 'img': '...'}
  }) async {
    final chatRoomId = _getChatRoomId(userId, otherUserId);
    final ref = _firestore.collection('chats').doc(chatRoomId);

    await ref.set({
      'participants': [userId, otherUserId],
      'lastMessage': '',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastSender': '',
      'typing': null,
      'unread': {userId: 0, otherUserId: 0},        // <-- standardize here
      'createdAt': FieldValue.serverTimestamp(),
      if (currentUserMeta != null || otherUserMeta != null)
        'peers': {
          if (currentUserMeta != null) userId: {
            'name': currentUserMeta['name'],
            'img': currentUserMeta['img'],
            'mUsers': currentUserMeta['mUsers'] ?? false,
          },
          if (otherUserMeta != null) otherUserId: {
            'name': otherUserMeta['name'],
            'img': otherUserMeta['img'],
            'mUsers': otherUserMeta['mUsers'] ?? false,
          },
        },
    }, SetOptions(merge: true));

    return chatRoomId;
  }

  Future<void> sendMessage(
    String roomId,
    String fromId,
    String toId,
    String text,
  ) async {
    if (text.trim().isEmpty) return;
    final chatRef = _firestore.collection('chats').doc(roomId);
    final msgRef = chatRef.collection('messages');

    await msgRef.add({
      'message': text.trim(),
      'senderId': fromId,
      'receiverId': toId,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [fromId],
    });

    await chatRef.update({
      'lastMessage': text.trim(),
      'lastSender': fromId,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'typing': null,
      'unread.$toId': FieldValue.increment(1),      // <-- matches 'unread'
    });
  }

  Stream<QuerySnapshot> getMessages(String roomId) {
    return _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> chatMetaStream(String roomId) {
    return _firestore.collection('chats').doc(roomId).snapshots();
  }

  Future<void> markMessagesRead(String roomId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(roomId);
    await chatRef.update({'unread.$userId': 0});

    final unread = await chatRef
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (var d in unread.docs) {
      batch.update(d.reference, {'readBy': FieldValue.arrayUnion([userId])});
    }
    await batch.commit();
  }

  Future<void> setTyping(String roomId, String userId) async {
    await _firestore.collection('chats').doc(roomId).update({'typing': userId});
  }

  Future<void> clearTyping(String roomId) async {
    await _firestore.collection('chats').doc(roomId).update({'typing': null});
  }

  Stream<QuerySnapshot> getChats(String userId) {
    // Requires composite index: participants (array-contains), lastTimestamp (desc)
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  Future<void> deleteChat(String roomId) async {
    final ref = _firestore.collection('chats').doc(roomId);
    final msgs = await ref.collection('messages').get();
    final batch = _firestore.batch();
    for (var d in msgs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(ref);
    await batch.commit();
  }

  
}
