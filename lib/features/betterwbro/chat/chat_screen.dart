// ✅ FINAL PRODUCTION CHAT SCREEN ✅
// No more setState after dispose ✅
// Fully guarded async, stream, and timer operations ✅
// Added streak badge display ✅
// Updated report dialog ✅

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/betterwbro/chat/chat_service.dart';
import 'package:onlymens/utilis/size_config.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? imageUrl;
  final String status;
  final double? distance;
  final int streaks;
  final int totalStreaks;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.status,
    this.imageUrl,
    this.distance,
    this.streaks = 0,
    this.totalStreaks = 0,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  String? _chatRoomId;
  bool _otherTyping = false;
  StreamSubscription? _metaSub;
  Timer? _typingTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _setupChat();

    _focus.addListener(() {
      if (_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _metaSub?.cancel();
    _typingTimer?.cancel();
    _scroll.dispose();
    _messageController.dispose();
    _focus.dispose();

    if (_chatRoomId != null) {
      _chatService.clearTyping(_chatRoomId!);
    }
    super.dispose();
  }

  void _scrollToBottom() {
    if (_isDisposed || !_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// ✅ Setup chat safely
  Future<void> _setupChat() async {
    final me = auth.currentUser!.uid;

    // 1️⃣ Check existing chats
    final snap = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: me)
        .get();

    for (var doc in snap.docs) {
      final p = List<String>.from(doc['participants']);
      if (p.contains(widget.userId)) {
        _chatRoomId = doc.id;
        break;
      }
    }

    if (_isDisposed || !mounted) return;

    // 2️⃣ Listen if chat exists
    if (_chatRoomId != null) {
      await _chatService.markMessagesRead(_chatRoomId!, me);

      _metaSub = _chatService.chatMetaStream(_chatRoomId!).listen((snap) {
        if (_isDisposed || !mounted) return;
        if (!snap.exists) return;

        final typingId = snap.data()?['typing'];
        if (mounted) {
          setState(() => _otherTyping = typingId == widget.userId);
        }
      });

      if (mounted) setState(() {});
    }
  }

  /// ✅ Create chat only when sending first message
  Future<void> _ensureRoomIfNeeded() async {
    if (_chatRoomId != null) return;

    final me = auth.currentUser!.uid;

    _chatRoomId = await _chatService.ensureChatRoom(
      me,
      widget.userId,
      currentUserMeta: {
        'name': currentUser.displayName ?? me,
        'img': currentUser.photoURL,
      },
      otherUserMeta: {
        'name': widget.name,
        'img': widget.imageUrl,
        'mUsers': true,
      },
    );

    if (_isDisposed || !mounted) return;

    _metaSub?.cancel(); // cancel old listener if any
    _metaSub = _chatService.chatMetaStream(_chatRoomId!).listen((snap) {
      if (_isDisposed || !mounted) return;
      if (!snap.exists) return;
      final d = snap.data();
      if (mounted) {
        setState(() => _otherTyping = d?['typing'] == widget.userId);
      }
    });

    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    await _ensureRoomIfNeeded();
    if (_isDisposed || !mounted || _chatRoomId == null) return;

    final me = auth.currentUser!.uid;
    await _chatService.sendMessage(_chatRoomId!, me, widget.userId, text);

    _chatService.clearTyping(_chatRoomId!);
    _scrollToBottom();
  }

  void _onTyping() {
    if (_chatRoomId == null || _isDisposed) return;

    _chatService.setTyping(_chatRoomId!, auth.currentUser!.uid);
    _typingTimer?.cancel();

    _typingTimer = Timer(const Duration(seconds: 1), () {
      if (!_isDisposed && _chatRoomId != null) {
        _chatService.clearTyping(_chatRoomId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(
                widget.imageUrl ??
                    "https://cdn-icons-png.flaticon.com/512/2815/2815428.png",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.streaks > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrangeAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const HugeIcon(
                                icon: HugeIcons.strokeRoundedFire02,
                                color: Colors.deepOrangeAccent,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${widget.streaks}',
                                style: const TextStyle(
                                  color: Colors.deepOrangeAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (widget.distance != null)
                    Text(
                      widget.distance! < 1
                          ? '${(widget.distance! * 1000).toStringAsFixed(0)}m away'
                          : '${widget.distance!.toStringAsFixed(1)}km away',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: Colors.white70,
                size: 18,
              ),
              onPressed: _confirmBlockUser,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _messages()),
          if (_otherTyping) _typingBubble(),
          _inputBox(),
        ],
      ),
    );
  }

  Widget _messages() {
    if (_chatRoomId == null) {
      return const Center(
        child: Text(
          'Say Hi 👋',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(_chatRoomId!),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CupertinoActivityIndicator(color: Colors.white24),
          );
        }

        final docs = snap.data!.docs;
        if (!_isDisposed && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isDisposed) _scrollToBottom();
          });
        }

        return ListView.builder(
          controller: _scroll,
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          itemBuilder: (_, i) {
            final m = docs[i].data() as Map;
            final isMe = m['senderId'] == auth.currentUser!.uid;
            final t = (m['timestamp'] as Timestamp?)?.toDate();

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isMe ? Colors.deepPurple : Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['message'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (t != null)
                      Text(
                        "${t.hour}:${t.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.55),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _typingBubble() => Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Typing...",
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );

  Widget _inputBox() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Container(
            height: SizeConfig.blockHeight * 7,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.deepPurple),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focus,
                    onChanged: (_) => _onTyping(),
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.deepPurpleAccent,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      fillColor: Colors.transparent,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                FloatingActionButton(
                  shape: const CircleBorder(),
                  onPressed: _send,
                  backgroundColor: Colors.deepPurple,
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _confirmBlockUser() async {
    if (_isDisposed || !mounted) return;

    final reportController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Report and Block User',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: reportController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Describe the issue (optional)...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                "If you find any inappropriate behavior or content, you can block this user and they will never appear again.",
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFEF9A9A),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              reportController.dispose();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F1019).withOpacity(0.5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final message = reportController.text.trim();
              reportController.dispose();
              Navigator.of(context).pop();
              
              await _blockUser(message);
            },
            child: const Text(
              'Block User',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(String reportMessage) async {
    final me = auth.currentUser!.uid;
    final other = widget.userId;

    try {
      // Block the user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(me)
          .collection('blocked')
          .doc(other)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'reportMessage': reportMessage.isNotEmpty ? reportMessage : null,
      });

      // Clear unread count
      if (_chatRoomId != null) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(_chatRoomId)
            .update({'unread.$me': 0});
      }

      if (!_isDisposed && mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User blocked successfully ✅"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Block error: $e");
    }
  }
}