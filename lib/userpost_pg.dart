import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cleanmind/core/globals.dart';
import 'package:cleanmind/utilis/snackbar.dart';

class UserPostsPage extends StatefulWidget {
  const UserPostsPage({super.key});

  @override
  State<UserPostsPage> createState() => _UserPostsPageState();
}

class _UserPostsPageState extends State<UserPostsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
  }

  Future<void> _loadUserPosts() async {
    setState(() => _isLoading = true);

    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .get();

      final posts = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['postId'] = doc.id; // Ensure postId is set
        return data;
      }).toList();

      setState(() {
        _userPosts = posts;
        _isLoading = false;
      });

      debugPrint("✅ Loaded ${_userPosts.length} user posts");
    } catch (e) {
      debugPrint("❌ Error loading user posts: $e");
      setState(() => _isLoading = false);
      Utilis.showSnackBar('Failed to load posts', isErr: true);
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) {
        Utilis.showSnackBar('User not authenticated', isErr: true);
        return;
      }

      // Safe null checks
      final postId = post['postId']?.toString();
      final postUserId = post['userId']?.toString();

      debugPrint(
        "🗑️ Delete attempt - postId: $postId, userId: $postUserId, currentUid: $uid",
      );

      if (postId == null || postId.isEmpty) {
        debugPrint("❌ Post ID is null or empty");
        Utilis.showSnackBar('Invalid post ID', isErr: true);
        return;
      }

      // Verify ownership
      if (postUserId != null && postUserId != uid) {
        debugPrint("❌ User ID mismatch");
        Utilis.showSnackBar('You can only delete your own posts', isErr: true);
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            Center(child: CupertinoActivityIndicator(color: Colors.white)),
      );

      // Delete from global posts collection (rUsers/all)
      try {
        await _firestore
            .collection("posts")
            .doc("rUsers")
            .collection("all")
            .doc(postId)
            .delete();
        debugPrint("✅ Deleted from rUsers/all");
      } catch (e) {
        debugPrint("⚠️ Failed to delete from rUsers/all: $e");
      }

      // Delete from user's personal posts
      try {
        await _firestore
            .collection("users")
            .doc(uid)
            .collection("posts")
            .doc(postId)
            .delete();
        debugPrint("✅ Deleted from user posts");
      } catch (e) {
        debugPrint("⚠️ Failed to delete from user posts: $e");
      }

      // Remove from local list
      setState(() {
        _userPosts.removeWhere((p) => p['postId']?.toString() == postId);
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Utilis.showSnackBar('Post deleted successfully', isGreen: true);
      }
    } catch (e) {
      debugPrint("❌ Delete post error: $e");
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Utilis.showSnackBar('Failed to delete post', isErr: true);
      }
    }
  }

  void _confirmDelete(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Delete Post?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deletePost(post);
            },
            child: Text(
              'Delete',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(int? timestamp) {
    if (timestamp == null) return 'Unknown';

    final now = DateTime.now();
    final postTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(postTime);

    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: Colors.white, size: 20.r),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Posts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CupertinoActivityIndicator(
                color: Colors.white24,
                radius: 16.r,
              ),
            )
          : _userPosts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64.r,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No posts yet',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Share your journey in the Feed tab',
                    style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadUserPosts,
              backgroundColor: const Color(0xFF1C1C1E),
              color: Colors.deepPurple,
              child: ListView.builder(
                padding: EdgeInsets.all(16.r),
                itemCount: _userPosts.length,
                itemBuilder: (context, index) {
                  final post = _userPosts[index];
                  return _buildPostCard(post);
                },
              ),
            ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post['name']?.toString() ?? 'Anonymous',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'You',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _getTimeAgo(post['timestamp'] as int?),
                      style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                onPressed: () => _confirmDelete(post),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            post['postText']?.toString() ?? '',
            style: TextStyle(color: Colors.white, fontSize: 15.sp, height: 1.5),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 14.r,
                color: Colors.grey[600],
              ),
              SizedBox(width: 4.w),
              Text(
                '${post['viewCount'] ?? 0} views',
                style: TextStyle(color: Colors.white38, fontSize: 13.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
