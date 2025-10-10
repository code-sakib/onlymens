import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/betterwbro/chat/domain/message_model.dart';
import 'package:onlymens/utilis/snackbar.dart';

class ChatService {
  // Future<DataState?>? getUsers() {
  //   firestore.collection('users').doc('mUsers').collection('m').doc('Users');
  // }

  Stream<QuerySnapshot> getMessages(String userId, String otherUserId) {
    final List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');
    return cloudDB
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  Future<void> sendMessages(
    String userId,
    String otherUserId,
    String message,
  ) async {
    final List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    final newMessage = MessageModel(
      message: message,
      timestamp: Timestamp.now(),
      senderId: userId,
      receiverId: otherUserId,
    );
    try {
      await cloudDB
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .add(newMessage.toMap());
    } on FirebaseException catch (err) {
      Utilis.showSnackBar(err.message.toString(), isErr: false);
    }
  }

  //send currentStatus of users whether offline, online or typing
  Future<void> sendImpFields(
    String userId,
    String otherUserId,
    String currentStatus,
  ) async {
    final List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');
    try {
      cloudDB.collection('chats').doc(chatRoomId).set({
        "usersCurrentStatus": {userId: currentStatus},
      }, SetOptions(merge: true));
    } on FirebaseException catch (err) {
      Utilis.showSnackBar(err.message.toString(), isErr: false);
    }
  }

  //getCurrentStatus
  Stream<DocumentSnapshot> getCurrentStatus(String userId, String otherUserId) {
    final List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    return cloudDB.collection('chats').doc(chatRoomId).snapshots();
  }
}
