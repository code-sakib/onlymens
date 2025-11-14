// lib/features/chat/messages_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/betterwbro/chat/chat_service.dart';
import 'package:onlymens/features/betterwbro/chat/chat_screen.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final ChatService _chatService = ChatService();
  final String currentUid = auth.currentUser!.uid;

  Set<String> blockedUsers = {};
  bool _loadedBlock = false;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  /// ✅ Load blocked list first then rebuild UI
  Future<void> _loadBlockedUsers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('blocked')
        .get();

    setState(() {
      blockedUsers = snap.docs.map((e) => e.id).toSet();
      _loadedBlock = true;
    });
  }

  Future<void> _refresh() async {
    await _loadBlockedUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedBlock) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      CupertinoIcons.back,
                      color: Colors.white60,
                    ),
                  ),
                  SizedBox(width: 12.r),
                  Text(
                    "Messages",
                    style: TextStyle(color: Colors.white, fontSize: 18.sp),
                  ),
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: Colors.deepPurple,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getChats(currentUid),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            "Failed loading messages",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white24,
                          ),
                        );
                      }

                      // ✅ Filter out blocked users before UI
                      final chats = snapshot.data!.docs.where((chatDoc) {
                        final data = chatDoc.data() as Map<String, dynamic>;
                        final parts =
                            (data['participants'] as List?)?.cast<String>() ??
                            [];

                        final otherId = parts.firstWhere(
                          (id) => id != currentUid,
                          orElse: () => "",
                        );

                        return otherId.isNotEmpty &&
                            !blockedUsers.contains(otherId);
                      }).toList();

                      if (chats.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: 100.h),
                            Center(
                              child: Text(
                                "No conversations",
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ],
                        );
                      }

                      return ListView.separated(
                        itemCount: chats.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10),
                        itemBuilder: (context, i) {
                          final chatDoc = chats[i];
                          final data =
                              chatDoc.data() as Map<String, dynamic>? ?? {};
                          final parts =
                              (data['participants'] as List<dynamic>? ?? [])
                                  .cast<String>();
                          final otherId = parts.firstWhere(
                            (id) => id != currentUid,
                            orElse: () => '',
                          );

                          final peers =
                              (data['peers'] as Map<String, dynamic>?) ?? {};
                          final otherMeta =
                              (peers[otherId] as Map?) ?? const {};
                          final title =
                              (otherMeta['name'] as String?) ?? "Unknown";
                          final imageUrl = (otherMeta['img'] as String?) ?? '';

                          final lastMsg = data['lastMessage'] as String? ?? '';
                          final lastTs = data['lastTimestamp'] as Timestamp?;
                          final unreadMap = (data['unread'] as Map?) ?? {};
                          final unreadCount =
                              (unreadMap[currentUid] ?? 0) as int;
                          final hasUnread = unreadCount > 0;

                          return ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    userId: otherId,
                                    name: title,
                                    status: "online",
                                    imageUrl: imageUrl,
                                  ),
                                ),
                              ).then((_) => _loadBlockedUsers());
                            },
                            leading: CircleAvatar(
                              backgroundImage: imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: imageUrl.isEmpty ? Text(title[0]) : null,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
                              ),
                            ),
                            subtitle: Text(
                              lastMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _timeAgo(lastTs),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                SizedBox(height: 4.h),
                                if (hasUnread) _unreadPill(unreadCount),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return "";
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m";
    return "now";
  }

  Widget _unreadPill(int c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.deepPurple,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      c > 99 ? "99+" : "$c",
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
