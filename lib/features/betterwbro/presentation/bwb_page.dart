import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:onlymens/core/globals.dart' show auth, currentUser;
import 'package:onlymens/features/avatar/avatar_data.dart';
import 'package:onlymens/features/betterwbro/chat/chat_screen.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:onlymens/utilis/snackbar.dart';

class BWBPage extends StatefulWidget {
  const BWBPage({super.key});

  @override
  State<BWBPage> createState() => _BWBPageState();
}

class _BWBPageState extends State<BWBPage> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final ScrollController _feedScrollController = ScrollController();

  // Community tab (existing)
  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  bool hasPermission = false;
  bool permissionAsked = false;
  Position? currentPosition;
  Set<String> blockedUsers = {};

  // Feed tab (new)
  List<Map<String, dynamic>> posts = [];
  bool isLoadingPosts = true;
  bool isLoadingMorePosts = false;
  int _postLimit = 20;
  final Set<String> _viewedPosts = {}; // Track viewed posts

  StreamSubscription? _blockSub;
  bool _initialized = false;

  // Tab controller
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });

    // Infinite scroll listener
    _feedScrollController.addListener(_onScroll);

    // ✅ Live listen to blocked users
    _blockSub = FirebaseFirestore.instance
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('blocked')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          setState(() {
            blockedUsers = snap.docs.map((e) => e.id).toSet();
            users.removeWhere((u) => blockedUsers.contains(u['id']));
            posts.removeWhere((p) => blockedUsers.contains(p['userId']));
          });
        });

    initPage();
  }

  void _onScroll() {
    if (_feedScrollController.position.pixels >=
            _feedScrollController.position.maxScrollExtent - 200 &&
        !isLoadingMorePosts) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (isLoadingMorePosts) return;

    setState(() {
      isLoadingMorePosts = true;
      _postLimit += 20;
    });

    await loadPosts(showLoading: false);

    if (mounted) {
      setState(() => isLoadingMorePosts = false);
    }
  }

  @override
  void dispose() {
    _blockSub?.cancel();
    _tabController.dispose();
    _feedScrollController.dispose();
    super.dispose();
  }

  Future<void> initPage() async {
    if (_initialized) return;
    _initialized = true;

    if (!mounted) return;
    setState(() => isLoading = true);

    await fetchBlockedUsers();
    await loadDefaultUsers();
    await loadPosts(); // Load posts for feed

    bool granted = await checkPermissionSilently();
    if (granted) {
      hasPermission = true;
      await loadNearbyUsers();
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Future<void> fetchBlockedUsers() async {
    try {
      final currentUid = auth.currentUser!.uid;
      final snap = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blocked')
          .get();
      blockedUsers = snap.docs.map((e) => e.id).toSet();
    } catch (e) {
      debugPrint("Error loading blocked users: $e");
    }
  }

  Future<void> loadDefaultUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc('mUsers')
          .collection('userList')
          .limit(20)
          .get();

      final data = snapshot.docs
          .map((e) {
            final u = e.data();
            u['id'] = e.id;
            return u;
          })
          .where((u) => !blockedUsers.contains(u['id']))
          .toList();

      if (!mounted) return;
      setState(() => users = data);
    } catch (e) {
      debugPrint('Error loading default users: $e');
    }
  }

  Future<bool> checkPermissionSilently() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      if (!mounted) return false;
      setState(() => permissionAsked = true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return false;
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Please enable location services in your device settings.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return false;
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'Please enable location permission in your device settings.',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Open Settings'),
                onPressed: () {
                  Navigator.pop(context);
                  Geolocator.openLocationSettings();
                },
              ),
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        return false;
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      return false;
    }
  }

  Future<void> loadNearbyUsers() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() => currentPosition = pos);

      await _firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('profile')
          .doc('data')
          .set({
            'loc': {'geopoint': GeoPoint(pos.latitude, pos.longitude)},
          }, SetOptions(merge: true));

      final allUsersSnap = await _firestore.collection('users').get();
      List<Map<String, dynamic>> realNearby = [];

      for (var doc in allUsersSnap.docs) {
        if (doc.id == auth.currentUser!.uid) continue;
        if (blockedUsers.contains(doc.id)) continue;

        final profileDoc = await doc.reference
            .collection('profile')
            .doc('data')
            .get();
        if (!profileDoc.exists) continue;

        final data = profileDoc.data()!;
        if (data['loc'] == null || data['loc']['geopoint'] == null) continue;

        GeoPoint gp = data['loc']['geopoint'];
        double distKm =
            Geolocator.distanceBetween(
              pos.latitude,
              pos.longitude,
              gp.latitude,
              gp.longitude,
            ) /
            1000;

        if (distKm <= 50) {
          data['id'] = doc.id;
          data['distance'] = distKm;
          realNearby.add(data);
        }
      }

      realNearby.sort(
        (a, b) => (a['distance'] ?? 999).compareTo(b['distance'] ?? 999),
      );

      List<Map<String, dynamic>> finalUsers = List.from(realNearby);

      if (finalUsers.length < 10) {
        final needed = 10 - finalUsers.length;
        final defaultSnap = await _firestore
            .collection('users')
            .doc('mUsers')
            .collection('userList')
            .limit(needed + 10)
            .get();

        final defaults = defaultSnap.docs
            .map((e) => {...e.data(), 'id': e.id})
            .where((u) => !blockedUsers.contains(u['id']))
            .take(needed);

        finalUsers.addAll(defaults);
      }

      if (!mounted) return;
      setState(() => users = finalUsers);
    } catch (e) {
      debugPrint("Error in loadNearbyUsers: $e");
    }
  }

  // ===== FEED FUNCTIONS =====

  Future<String?> _getUserProfileImage(String userId, int? streaks) async {
    try {
      // 1. Try to get user's custom profile image URL from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('data')
          .get();

      if (userDoc.exists) {
        final profileData = userDoc.data()!;

        // Check for custom avatar URL
        final customImg = profileData['customAvatarUrl'];
        if (customImg != null && customImg.toString().isNotEmpty) {
          return customImg;
        }

        // Check for general img field
        final img = profileData['img'];
        if (img != null && img.toString().isNotEmpty) {
          return img;
        }
      }

      // 2. Get streak-based avatar
      if (streaks != null) {
        final level = AvatarManager.getLevelFromDays(streaks);
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('avatarsImg')
              .child('$level.png');
          final downloadUrl = await storageRef.getDownloadURL();
          return downloadUrl;
        } catch (e) {
          debugPrint('Firebase Storage failed for level avatar');
        }
      }

      // 3. Return null (will show default icon)
      return null;
    } catch (e) {
      debugPrint('Error getting user profile image: $e');
      return null;
    }
  }

  Future<void> incrementViewCount(Map<String, dynamic> post) async {
    try {
      final postId = post['postId'];
      final currentViews = post['viewCount'] ?? 0;

      // Skip if it's user's own post
      if (post['isCurrentUser'] == true) return;

      // Skip if post is too new (<2 minutes old)
      final timestamp = post['timestamp'];
      if (timestamp != null) {
        final postTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(postTime).inMinutes < 2) return;
      }

      // Don't increment if already viewed or if views >= 50
      if (_viewedPosts.contains(postId) || currentViews >= 50) return;

      _viewedPosts.add(postId);

      final increment = 3 + Random().nextInt(3); // 3, 4, or 5
      final newViews = min(currentViews + increment, 50);

      if (post['source'] == 'default') {
        await _firestore
            .collection('posts')
            .doc('default')
            .collection(post['date'])
            .doc(postId)
            .update({'viewCount': newViews});
      } else {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await _firestore
            .collection('posts')
            .doc(today)
            .collection('userPosts')
            .doc(postId)
            .update({'viewCount': newViews});
      }

      if (!mounted) return;
      setState(() {
        post['viewCount'] = newViews;
      });
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
    }
  }

  Future<void> loadPosts({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() => isLoadingPosts = true);
    }

    try {
      List<Map<String, dynamic>> allPosts = [];
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final currentUid = auth.currentUser!.uid;

      // 1. Fetch ALL user posts from today (from all users)
      final userPostsSnap = await _firestore
          .collection('posts')
          .doc(today)
          .collection('userPosts')
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in userPostsSnap.docs) {
        final data = doc.data();
        if (blockedUsers.contains(data['userId'])) continue;

        // Get fresh user profile data for each post
        final userProfile = await _firestore
            .collection('users')
            .doc(data['userId'])
            .collection('profile')
            .doc('data')
            .get();

        if (userProfile.exists) {
          final profileData = userProfile.data()!;
          final updatedName = profileData['name'] ?? data['name'];
          final updatedStreaks =
              profileData['currentStreak'] ?? data['streaks'];

          // Get updated profile image
          final updatedDp = await _getUserProfileImage(
            data['userId'],
            updatedStreaks,
          );

          allPosts.add({
            ...data,
            'postId': doc.id,
            'source': 'user',
            'name': updatedName, // Use updated name
            'dp': updatedDp, // Use updated DP
            'streaks': updatedStreaks, // Use updated streak
            'isCurrentUser': data['userId'] == currentUid,
          });
        } else {
          // Fallback if profile doesn't exist
          allPosts.add({
            ...data,
            'postId': doc.id,
            'source': 'user',
            'isCurrentUser': data['userId'] == currentUid,
          });
        }
      }

      // 2. If less than 10 posts, fetch from default posts
      if (allPosts.length < 10) {
        final now = DateTime.now();

        for (int i = 0; i < 7 && allPosts.length < _postLimit; i++) {
          final date = DateFormat(
            'yyyy-MM-dd',
          ).format(now.subtract(Duration(days: i)));

          final defaultPostsSnap = await _firestore
              .collection('posts')
              .doc('default')
              .collection(date)
              .get();

          for (var doc in defaultPostsSnap.docs) {
            if (allPosts.length >= _postLimit) break;

            allPosts.add({
              ...doc.data(),
              'postId': doc.id,
              'source': 'default',
              'date': date,
              'isCurrentUser': false,
              'isDefault': true,
            });
          }
        }
      }

      // 3. Sort by timestamp descending (most recent first)
      allPosts.sort((a, b) {
        final aTime = a['timestamp'] ?? 0;
        final bTime = b['timestamp'] ?? 0;
        return bTime.compareTo(aTime);
      });
      // 🌀 Blend current user's post randomly (not always on top)
      final currentUserPosts = allPosts
          .where((p) => p['isCurrentUser'] == true)
          .toList();
      final otherPosts = allPosts
          .where((p) => p['isCurrentUser'] != true)
          .toList();

      if (otherPosts.isNotEmpty) {
        otherPosts.shuffle(Random()); // Natural feed randomness

        if (currentUserPosts.isNotEmpty) {
          final insertIndex = min(2 + Random().nextInt(3), otherPosts.length);
          otherPosts.insertAll(insertIndex, currentUserPosts);
        }

        allPosts = otherPosts;
      }

      // Move current user's post slightly down
      if (allPosts.isNotEmpty) {
        final currentUserPosts = allPosts
            .where((p) => p['isCurrentUser'] == true)
            .toList();
        final otherPosts = allPosts
            .where((p) => p['isCurrentUser'] != true)
            .toList();

        // Slight shuffle for natural randomness
        otherPosts.shuffle(Random());

        // Interleave user post randomly between 2nd–5th position
        if (currentUserPosts.isNotEmpty) {
          final insertIndex = min(2 + Random().nextInt(3), otherPosts.length);
          otherPosts.insertAll(insertIndex, currentUserPosts);
        }

        allPosts = otherPosts;
      }

      if (!mounted) return;
      setState(() {
        posts = allPosts.take(_postLimit).toList();
        if (showLoading) isLoadingPosts = false;
      });
    } catch (e) {
      debugPrint("Error loading posts: $e");
      if (!mounted) return;
      if (showLoading) {
        setState(() => isLoadingPosts = false);
      }
    }
  }

  Future<void> createPost(String postText) async {
    if (postText.trim().isEmpty) return;

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final currentUid = auth.currentUser!.uid;

      // Get user profile data
      final userProfileSnap = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('profile')
          .doc('data')
          .get();

      final userData = userProfileSnap.data() ?? {};
      final name = userData['name'] ?? 'Anonymous';
      final streaks = userData['currentStreak'] ?? 0;

      // Get user's profile image
      final dp = await _getUserProfileImage(currentUid, streaks);

      final postData = {
        'userId': currentUid,
        'name': name,
        'dp': dp,
        'postText': postText.trim(),
        'streaks': streaks,
        'viewCount': Random().nextInt(20),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'likes': 0,
        'isDefault': false,
        'date': today,
      };

      // Save to main posts collection (posts > today > userPosts)
      final postRef = await _firestore
          .collection('posts')
          .doc(today)
          .collection('userPosts')
          .add(postData);

      // Save to user's personal posts collection (users > uid > posts)
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('posts')
          .doc(postRef.id)
          .set({...postData, 'postId': postRef.id});

      // Reload posts
      await loadPosts();

      if (!mounted) return;
      _showSnackbar('Post shared with the community! 🎉', Colors.deepPurple);
    } catch (e) {
      debugPrint("Error creating post: $e");
      if (!mounted) return;
      _showSnackbar('Failed to create post. Try again.', Colors.red);
    }
  }

  Future<void> deletePost(Map<String, dynamic> post) async {
    try {
      final postId = post['postId'];
      final userId = post['userId'];
      final currentUid = auth.currentUser!.uid;

      // Only allow deletion of own posts
      if (userId != currentUid) {
        _showSnackbar('You can only delete your own posts', Colors.red);
        return;
      }

      // Delete from main posts collection
      final today =
          post['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _firestore
          .collection('posts')
          .doc(today)
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
        posts.removeWhere((p) => p['postId'] == postId);
      });

      if (!mounted) return;
      _showSnackbar('Post deleted successfully', Colors.green);
    } catch (e) {
      debugPrint("Error deleting post: $e");
      if (!mounted) return;
      _showSnackbar('Failed to delete post', Colors.red);
    }
  }

  void showCreatePostDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share with Community',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 5,
                  maxLength: 300,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'How are you feeling today?',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: const TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final text = textController.text.trim();
                        Navigator.of(context).pop();

                        if (text.isNotEmpty) {
                          await createPost(text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Post'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> reportPost(
    Map<String, dynamic> post,
    String reportMessage,
  ) async {
    try {
      final currentUid = auth.currentUser!.uid;

      // Save to reported collection
      await _firestore
          .collection('posts')
          .doc('reported')
          .collection('all')
          .add({
            ...post,
            'reportedBy': currentUid,
            'reportedAt': FieldValue.serverTimestamp(),
            'reportMessage': reportMessage,
          });

      // Remove from source
      if (post['source'] == 'default') {
        await _firestore
            .collection('posts')
            .doc('default')
            .collection(post['date'])
            .doc(post['postId'])
            .delete();
      } else {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await _firestore
            .collection('posts')
            .doc(today)
            .collection('userPosts')
            .doc(post['postId'])
            .delete();
      }

      // Reload posts
      await loadPosts();

      if (!mounted) return;
      _showSnackbar('Report sent successfully', Colors.orange);
    } catch (e) {
      debugPrint("Error reporting post: $e");
      if (!mounted) return;
      _showSnackbar('Failed to report post', Colors.red);
    }
  }

  void _showReportDialog(Map<String, dynamic> post) {
    final reportController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Report Post',
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
                  hintText: 'Your Report Message..',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                "Sorry for the inconvenience! We'll fix this soon. ThankYou!",
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
              if (reportController.text.trim().isEmpty) {
                reportController.dispose();
                Navigator.of(context).pop();
                _showSnackbar('Please enter a report message', Colors.red);
                return;
              }

              final message = reportController.text.trim();
              reportController.dispose();
              Navigator.of(context).pop();

              await reportPost(post, message);
            },
            child: const Text(
              'Send',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    if (color == Colors.red) {
      Utilis.showSnackBar(message, isErr: true);
    } else if (color == Colors.green) {
      Utilis.showSnackBar(message, isGreen: true);
    } else {
      Utilis.showSnackBar(message);
    }
  }

  void showInfoDialog() {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Better With Buddy'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.network(
                'https://lottie.host/23a28cec-2969-4b3b-9b55-f8b7a9ce7fc7/1ZCeHcovAb.json',
                height: SizeConfig.blockHeight * 15,
              ),
              const SizedBox(height: 12),
              const Text('• Find people who are on the same journey as you.'),
              const SizedBox(height: 12),
              const Text('• People support each other here.'),
              const SizedBox(height: 12),
              const Text('• Full control. Full privacy. Always.'),
            ],
          ),
        ),
        actions: [
          if (!hasPermission)
            CupertinoDialogAction(
              child: const Text('Give Permission'),
              onPressed: () async {
                Navigator.pop(context);
                if (!mounted) return;
                setState(() => isLoading = true);

                final granted = await requestPermission();
                if (granted) {
                  await loadNearbyUsers();
                  if (!mounted) return;
                  setState(() {
                    hasPermission = true;
                    isLoading = false;
                  });
                } else {
                  if (!mounted) return;
                  setState(() => isLoading = false);
                }
              },
            ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> handleUserTap(Map<String, dynamic> user) async {
    final otherUserId = user['id'] ?? '';
    if (otherUserId.isEmpty) return;

    if (blockedUsers.contains(otherUserId)) {
      if (!mounted) return;
      _showSnackbar("This user is blocked.", Colors.red);
      return;
    }

    if (!permissionAsked && !hasPermission) {
      final granted = await requestPermission();
      if (!granted) return;
      hasPermission = true;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userId: otherUserId,
          name: user['name'] ?? 'Unknown',
          status: user['status'] ?? 'offline',
          imageUrl: user['img'],
          distance: user['distance'],
          streaks: user['streaks'] ?? 0,
          totalStreaks: user['totalStreaks'] ?? 0,
        ),
      ),
    );
  }

  Future<void> handlePostUserTap(Map<String, dynamic> post) async {
    final otherUserId = post['userId'] ?? '';
    if (otherUserId.isEmpty) return;

    // Don't allow chat if it's current user's post
    if (post['isCurrentUser'] == true) {
      _showSnackbar("This is your post", Colors.orange);
      return;
    }

    // Don't allow chat with default users
    if (post['isDefault'] == true) {
      _showSnackbar("This is a community post", Colors.orange);
      return;
    }

    if (blockedUsers.contains(otherUserId)) {
      if (!mounted) return;
      _showSnackbar("This user is blocked.", Colors.red);
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userId: otherUserId,
          name: post['name'] ?? 'Unknown',
          status: 'online',
          imageUrl: post['dp'],
          distance: null,
          streaks: post['streaks'] ?? 0,
          totalStreaks: 0,
        ),
      ),
    );
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

  Future<List<Map<String, dynamic>>> getUserPosts(String userId) async {
    try {
      final userPostsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> userPosts = [];

      for (var doc in userPostsSnap.docs) {
        final data = doc.data();
        userPosts.add({...data, 'postId': doc.id, 'isCurrentUser': true});
      }

      return userPosts;
    } catch (e) {
      debugPrint("Error fetching user posts: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearbyCount = hasPermission
        ? users.where((u) => u['distance'] != null).length
        : users.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Feed'),
              Tab(text: 'Community'),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_rounded, color: Colors.white54),
            onPressed: showInfoDialog,
          ),
          IconButton(
            onPressed: () => context.go('/streaks'),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedFire02,
              color: Colors.deepOrangeAccent,
            ),
          ),
          IconButton(
            onPressed: () => context.push('/messages'),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedMessage01,
              color: Colors.white12,
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // FEED TAB
          _buildFeedTab(),

          // COMMUNITY TAB (existing)
          _buildCommunityTab(nearbyCount),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: showCreatePostDialog,
              backgroundColor: Colors.deepPurple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Post',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFeedTab() {
    if (isLoadingPosts) {
      return const Center(
        child: CupertinoActivityIndicator(color: Colors.white24, radius: 12),
      );
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 64, color: Colors.white24),
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
              'Be the first to share!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: showCreatePostDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadPosts,
      backgroundColor: const Color(0xFF1C1C1E),
      color: Colors.deepPurple,
      child: ListView.builder(
        controller: _feedScrollController,
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 80,
        ),
        itemCount: posts.length + (isLoadingMorePosts ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CupertinoActivityIndicator(color: Colors.white24),
              ),
            );
          }
          final post = posts[index];

          // Increment view count when post becomes visible
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) incrementViewCount(post);
          });

          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return GestureDetector(
      onLongPress: () {
        showCupertinoModalPopup(
          context: context,
          builder: (context) => CupertinoActionSheet(
            actions: [
              // Show delete option only for current user's posts
              if (post['isCurrentUser'] == true)
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    Navigator.pop(context);
                    deletePost(post);
                  },
                  child: const Text('Delete Post'),
                ),
              // Show report option for other users' posts
              if (post['isCurrentUser'] != true && post['isDefault'] != true)
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    _showReportDialog(post);
                  },
                  child: const Text('Report Post'),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
        );
      },
      child: Container(
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
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => handlePostUserTap(post),
                  child: CircleAvatar(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => handlePostUserTap(post),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post['name'] ?? 'Anonymous',
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
                                  color: Colors.deepOrangeAccent.withOpacity(
                                    0.2,
                                  ),
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
      ),
    );
  }

  Widget _buildCommunityTab(int nearbyCount) {
    if (isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(color: Colors.white24, radius: 12),
      );
    }

    if (users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_2, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text('Check back later', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Text(
                nearbyCount != 0
                    ? '$nearbyCount ${hasPermission ? 'users near you' : 'users'} on the same journey'
                    : 'Find people near you on the same journey',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final user = users[index];
              final distance = user['distance'] as double?;

              String subtitle = user['status'] ?? "Let's grow together";
              if (hasPermission && distance != null) {
                subtitle = distance < 1
                    ? '${(distance * 1000).toStringAsFixed(0)}m away'
                    : '${distance.toStringAsFixed(1)}km away';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(
                      user['img'] ??
                          'https://cdn-icons-png.flaticon.com/512/2815/2815428.png',
                    ),
                  ),
                  title: Text(
                    user['name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => handleUserTap(user),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
