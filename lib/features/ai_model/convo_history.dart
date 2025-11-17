import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onlymens/features/ai_model/model/model.dart';

class ConversationHistoryWidget extends StatefulWidget {
  final Function(String sessionId)? onConversationTap;

  const ConversationHistoryWidget({super.key, this.onConversationTap});

  @override
  State<ConversationHistoryWidget> createState() =>
      _ConversationHistoryWidgetState();
}

class _ConversationHistoryWidgetState extends State<ConversationHistoryWidget> {
  final AIModelDataService _aiService = AIModelDataService();

  String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime); // Today: show time
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime); // This week: show day
    } else {
      return DateFormat('MMM dd').format(dateTime); // Older: show date
    }
  }

  Future<void> _deleteConversation(String sessionId) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete Conversation'),
        content: Text('Are you sure you want to delete this conversation?'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _aiService.deleteConversation(sessionId);
      setState(() {}); // Refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConversationModel>>(
      future: _aiService.fetchAllConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CupertinoActivityIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading conversations',
                  style: TextStyle(color: Colors.red),
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.chat_bubble_2,
                  size: 64,
                  color: Colors.grey[600],
                ),
                SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Start a new chat to begin!',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          );
        }

        final conversations = snapshot.data!;

        return ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: Colors.grey[800]),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final lastMessage = conversation.messages.isNotEmpty
                ? conversation.messages.last.text
                : 'No messages';

            return Dismissible(
              key: Key(conversation.sessionId),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: 20),
                child: Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showCupertinoDialog<bool>(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: Text('Delete Conversation'),
                    content: Text('This action cannot be undone.'),
                    actions: [
                      CupertinoDialogAction(
                        child: Text('Cancel'),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        child: Text('Delete'),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) {
                _aiService.deleteConversation(conversation.sessionId);
              },
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  conversation.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    lastMessage,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDateTime(conversation.lastUpdatedDate),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${conversation.messageCount}',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                tileColor: Colors.grey[900],
                onTap: () {
                  if (widget.onConversationTap != null) {
                    widget.onConversationTap!(conversation.sessionId);
                  }
                },
                onLongPress: () {
                  _deleteConversation(conversation.sessionId);
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================
// AVATAR CONVERSATION HISTORY WIDGET
// (Separate from normal AI chat history)
// ============================================

class AvatarConversationHistoryWidget extends StatefulWidget {
  final Function(String) onConversationTap;

  const AvatarConversationHistoryWidget({
    super.key,
    required this.onConversationTap,
  });

  @override
  State<AvatarConversationHistoryWidget> createState() =>
      _AvatarConversationHistoryWidgetState();
}

class _AvatarConversationHistoryWidgetState
    extends State<AvatarConversationHistoryWidget> {
  final AIModelDataService _aiService = AIModelDataService();

  String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime); // Today: show time
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime); // This week: show day
    } else {
      return DateFormat('MMM dd').format(dateTime); // Older: show date
    }
  }

  Future<void> _deleteConversation(String sessionId) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete Conversation'),
        content: Text('Are you sure you want to delete this conversation?'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _aiService.deleteConversation(
        sessionId,
        isAvatarMode: true, // ✅ Delete from aiAvatarChat collection
      );
      setState(() {}); // Refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConversationModel>>(
      future: _aiService.fetchAllConversations(
        isAvatarMode: true, // ✅ Fetch only from aiAvatarChat collection
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CupertinoActivityIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading conversations',
                  style: TextStyle(color: Colors.red),
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.person_crop_circle,
                  size: 64,
                  color: Colors.grey[600],
                ),
                SizedBox(height: 16),
                Text(
                  'No avatar conversations yet',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Start chatting with your avatar!',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          );
        }

        final conversations = snapshot.data!;

        return ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: Colors.grey[800]),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            final lastMessage = conversation.messages.isNotEmpty
                ? conversation.messages.last.text
                : 'No messages';

            return Dismissible(
              key: Key(conversation.sessionId),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: 20),
                child: Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showCupertinoDialog<bool>(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: Text('Delete Conversation'),
                    content: Text('This action cannot be undone.'),
                    actions: [
                      CupertinoDialogAction(
                        child: Text('Cancel'),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        child: Text('Delete'),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) {
                _aiService.deleteConversation(
                  conversation.sessionId,
                  isAvatarMode: true,
                );
              },
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  conversation.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    lastMessage,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDateTime(conversation.lastUpdatedDate),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${conversation.messageCount}',
                        style: TextStyle(
                          color: Colors.deepPurple[300],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                tileColor: Colors.grey[900],
                onTap: () {
                  widget.onConversationTap(conversation.sessionId);
                },
                onLongPress: () {
                  _deleteConversation(conversation.sessionId);
                },
              ),
            );
          },
        );
      },
    );
  }
}