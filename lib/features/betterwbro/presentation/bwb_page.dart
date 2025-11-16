import 'dart:async';
import 'dart:math';
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
import 'package:onlymens/utilis/snackbar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BWBPage extends StatefulWidget {
  const BWBPage({super.key});

  @override
  State<BWBPage> createState() => _BWBPageState();
}

class _BWBPageState extends State<BWBPage> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final ScrollController _feedScrollController = ScrollController();

  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  bool hasPermission = false;
  bool permissionAsked = false;
  Position? currentPosition;
  Set<String> blockedUsers = {};

  List<Map<String, dynamic>> posts = [];
  bool isLoadingPosts = true;
  bool isLoadingMorePosts = false;
  int _postLimit = 20;
  final Set<String> _viewedPosts = {};

  StreamSubscription? _blockSub;
  bool _initialized = false;

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

    _feedScrollController.addListener(_onScroll);

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
    await loadPosts();

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

  Future<String?> _getUserProfileImage(String userId, int? streaks) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('data')
          .get();

      if (userDoc.exists) {
        final profileData = userDoc.data()!;

        final customImg = profileData['customAvatarUrl'];
        if (customImg != null && customImg.toString().isNotEmpty) {
          return customImg;
        }

        final img = profileData['img'];
        if (img != null && img.toString().isNotEmpty) {
          return img;
        }
      }

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

      if (post['isCurrentUser'] == true) return;

      final timestamp = post['timestamp'];
      if (timestamp != null) {
        final postTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(postTime).inMinutes < 2) return;
      }

      if (_viewedPosts.contains(postId) || currentViews >= 50) return;

      _viewedPosts.add(postId);

      final increment = 3 + Random().nextInt(3);
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

      final userPostsSnap = await _firestore
          .collection('posts')
          .doc(today)
          .collection('userPosts')
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in userPostsSnap.docs) {
        final data = doc.data();
        if (blockedUsers.contains(data['userId'])) continue;

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

          final updatedDp = await _getUserProfileImage(
            data['userId'],
            updatedStreaks,
          );

          allPosts.add({
            ...data,
            'postId': doc.id,
            'source': 'user',
            'name': updatedName,
            'dp': updatedDp,
            'streaks': updatedStreaks,
            'isCurrentUser': data['userId'] == currentUid,
          });
        } else {
          allPosts.add({
            ...data,
            'postId': doc.id,
            'source': 'user',
            'isCurrentUser': data['userId'] == currentUid,
          });
        }
      }

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

      allPosts.sort((a, b) {
        final aTime = a['timestamp'] ?? 0;
        final bTime = b['timestamp'] ?? 0;
        return bTime.compareTo(aTime);
      });

      final currentUserPosts = allPosts
          .where((p) => p['isCurrentUser'] == true)
          .toList();
      final otherPosts = allPosts
          .where((p) => p['isCurrentUser'] != true)
          .toList();

      if (otherPosts.isNotEmpty) {
        otherPosts.shuffle(Random());

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

      final userProfileSnap = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('profile')
          .doc('data')
          .get();

      final userData = userProfileSnap.data() ?? {};
      final name = userData['name'] ?? 'Anonymous';
      final streaks = userData['currentStreak'] ?? 0;

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

      final postRef = await _firestore
          .collection('posts')
          .doc(today)
          .collection('userPosts')
          .add(postData);

      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('posts')
          .doc(postRef.id)
          .set({...postData, 'postId': postRef.id});

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

      if (userId != currentUid) {
        _showSnackbar('You can only delete your own posts', Colors.red);
        return;
      }

      final today =
          post['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _firestore
          .collection('posts')
          .doc(today)
          .collection('userPosts')
          .doc(postId)
          .delete();

      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('posts')
          .doc(postId)
          .delete();

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share with Community',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: textController,
                  maxLines: 5,
                  maxLength: 300,
                  autofocus: true,
                  style: TextStyle(color: Colors.white, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: 'How are you feeling today?',
                    hintStyle: TextStyle(
                      color: Colors.white38,
                      fontSize: 15.sp,
                    ),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: TextStyle(
                      color: Colors.white38,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text('Post', style: TextStyle(fontSize: 14.sp)),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Report Post',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
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
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14.sp,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                  contentPadding: EdgeInsets.all(12.r),
                ),
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              ),
              SizedBox(height: 12.h),
              Text(
                "Sorry for the inconvenience! We'll fix this soon. ThankYou!",
                style: TextStyle(
                  fontSize: 11.sp,
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
            child: Text('Cancel', style: TextStyle(fontSize: 14.sp)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F1019).withOpacity(0.5),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
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
            child: Text(
              'Send',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
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
          padding: EdgeInsets.only(top: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.network(
                'https://lottie.host/23a28cec-2969-4b3b-9b55-f8b7a9ce7fc7/1ZCeHcovAb.json',
                height: 120.h,
              ),
              SizedBox(height: 12.h),
              Text(
                '• Find people who are on the same journey as you.',
                style: TextStyle(fontSize: 13.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                '• People support each other here.',
                style: TextStyle(fontSize: 13.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                '• Full control. Full privacy. Always.',
                style: TextStyle(fontSize: 13.sp),
              ),
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

    if (post['isCurrentUser'] == true) {
      _showSnackbar("This is your post", Colors.orange);
      return;
    }

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
          height: 36.h,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(8.r),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Feed'),
              Tab(text: 'Community'),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_rounded, color: Colors.white54, size: 20.r),
            onPressed: showInfoDialog,
          ),
          IconButton(
            onPressed: () => context.go('/streaks'),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedFire02,
              color: Colors.deepOrangeAccent,
              size: 20.r,
            ),
          ),
          IconButton(
            onPressed: () => context.push('/messages'),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedMessage01,
              color: Colors.white12,
              size: 20.r,
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFeedTab(), _buildCommunityTab(nearbyCount)],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: showCreatePostDialog,
              backgroundColor: Colors.deepPurple,
              icon: Icon(Icons.add, color: Colors.white, size: 20.r),
              label: Text(
                'Post',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFeedTab() {
    if (isLoadingPosts) {
      return Center(
        child: CupertinoActivityIndicator(color: Colors.white24, radius: 12.r),
      );
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64.r, color: Colors.white24),
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
              'Be the first to share!',
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: showCreatePostDialog,
              icon: Icon(Icons.add, size: 18.r),
              label: Text('Create Post', style: TextStyle(fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
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
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 12.h,
          bottom: 80.h,
        ),
        itemCount: posts.length + (isLoadingMorePosts ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: CupertinoActivityIndicator(color: Colors.white24),
              ),
            );
          }
          final post = posts[index];

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
              if (post['isCurrentUser'] == true)
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    Navigator.pop(context);
                    deletePost(post);
                  },
                  child: const Text('Delete Post'),
                ),
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
                GestureDetector(
                  onTap: () => handlePostUserTap(post),
                  child: CircleAvatar(
                    radius: 22.r,
                    backgroundColor: Colors.grey[800],
                    child: post['dp'] != null
                        ? ClipOval(
                            child: Image.network(
                              post['dp'],
                              width: 44.r,
                              height: 44.r,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 24.r,
                                  color: Colors.grey[400],
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.person,
                            size: 24.r,
                            color: Colors.grey[400],
                          ),
                  ),
                ),
                SizedBox(width: 12.w),
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
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            if (post['streaks'] != null && post['streaks'] > 0)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrangeAccent.withOpacity(
                                    0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons.strokeRoundedFire02,
                                      color: Colors.deepOrangeAccent,
                                      size: 12.r,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '${post['streaks']}',
                                      style: TextStyle(
                                        color: Colors.deepOrangeAccent,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _getTimeAgo(post['timestamp'] ?? 0),
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              post['postText'] ?? '',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedChart01,
                  size: 14.r,
                  color: const Color.fromARGB(255, 202, 202, 202),
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
      ),
    );
  }

  Widget _buildCommunityTab(int nearbyCount) {
    if (isLoading) {
      return Center(
        child: CupertinoActivityIndicator(color: Colors.white24, radius: 12.r),
      );
    }

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.person_2, size: 64.r, color: Colors.white24),
            SizedBox(height: 16.h),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Check back later',
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Row(
            children: [
              Text(
                nearbyCount != 0
                    ? '$nearbyCount ${hasPermission ? 'users near you' : 'users'} on the same journey'
                    : 'Find people near you on the same journey',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  leading: CircleAvatar(
                    radius: 25.r,
                    backgroundImage: NetworkImage(
                      user['img'] ??
                          'https://cdn-icons-png.flaticon.com/512/2815/2815428.png',
                    ),
                  ),
                  title: Text(
                    user['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: TextStyle(color: Colors.deepPurple, fontSize: 13.sp),
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
