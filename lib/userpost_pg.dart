import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/core/globals.dart' show auth;
import 'package:onlymens/utilis/snackbar.dart';

// Add this to ProfilePage State class

class UserPostsPage extends StatefulWidget {
  const UserPostsPage({super.key});

  @override
  State<UserPostsPage> createState() => _UserPostsPageState();
}

class _UserPostsPageState extends State<UserPostsPage> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> userPosts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
  }

  Future<void> _loadUserPosts() async {
    try {
      final currentUid = auth.currentUser!.uid;

      final postsSnap = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> posts = [];

      for (var doc in postsSnap.docs) {
        posts.add({...doc.data(), 'postId': doc.id});
      }

      if (!mounted) return;
      setState(() {
        userPosts = posts;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading user posts: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _deletePost(String postId, String date) async {
    try {
      final currentUid = auth.currentUser!.uid;

      // Show confirmation dialog
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Delete Post?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Delete from main posts collection
      await _firestore
          .collection('posts')
          .doc(date)
          .collection('userPosts')
          .doc(postId)
          .delete();

      // Delete from user's personal collection
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('posts')
          .doc(postId)
          .delete();

      // Remove from local state
      setState(() {
        userPosts.removeWhere((p) => p['postId'] == postId);
      });

      if (!mounted) return;

      Utilis.showSnackBar('Post deleted successfully', isGreen: true);
    } catch (e) {
      debugPrint("Error deleting post: $e");
      if (!mounted) return;

      Utilis.showSnackBar('Failed to delete post', isGreen: true);
    }
  }

  String _getTimeAgo(int timestamp) {
    final now = DateTime.now();
    final postTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(postTime);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Posts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CupertinoActivityIndicator(color: Colors.white24),
            )
          : userPosts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No posts yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Share your thoughts with the community',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to BWB feed tab
                      context.go('/bwb');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Create Post'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadUserPosts,
              backgroundColor: const Color(0xFF1C1C1E),
              color: Colors.deepPurple,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: userPosts.length,
                itemBuilder: (context, index) {
                  final post = userPosts[index];
                  return _buildPostCard(post);
                },
              ),
            ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with delete button
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[800],
                child: post['dp'] != null
                    ? ClipOval(
                        child: Image.network(
                          post['dp'],
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 24,
                              color: Colors.grey[400],
                            );
                          },
                        ),
                      )
                    : Icon(Icons.person, size: 24, color: Colors.grey[400]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post['name'] ?? 'You',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (post['streaks'] != null && post['streaks'] > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepOrangeAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const HugeIcon(
                                  icon: HugeIcons.strokeRoundedFire02,
                                  color: Colors.deepOrangeAccent,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${post['streaks']}',
                                  style: const TextStyle(
                                    color: Colors.deepOrangeAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getTimeAgo(post['timestamp'] ?? 0),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deletePost(post['postId'], post['date']),
              ),
            ],
          ),

          // Post text
          const SizedBox(height: 12),
          Text(
            post['postText'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),

          // Stats
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedChart01,
                size: 14,
                color: Color.fromARGB(255, 202, 202, 202),
              ),
              const SizedBox(width: 4),
              Text(
                '${post['viewCount'] ?? 0} views',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Update the Profile Page _tile widget to navigate to UserPostsPage
