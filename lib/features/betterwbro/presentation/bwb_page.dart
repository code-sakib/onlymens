// lib/features/betterwbro/bwb_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/avatar/avatar_data.dart';
import 'package:onlymens/features/betterwbro/chat/chat_screen.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';
import 'package:onlymens/utilis/snackbar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';

class BWBPage extends StatefulWidget {
  const BWBPage({super.key});

  @override
  State<BWBPage> createState() => _BWBPageState();
}

class _BWBPageState extends State<BWBPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _feedScrollController = ScrollController();

  Widget? _cachedCurrentUserAvatar;
  bool _avatarCacheLoaded = false;

  List<Map<String, dynamic>> users = [];
  bool isLoading = true;
  bool hasPermission = false;
  bool permissionAsked = false;
  Position? currentPosition;
  Set<String> blockedUsers = {};

  bool isLoadingPosts = true;
  bool isLoadingMorePosts = false;

  // pagination / limits
  final int _pageSize = 20; // how many real posts we page by
  final int _defaultLimit = 6; // fetch 5-6 default posts per page as requested

  bool _isFetchingPosts = false;

  List<Map<String, dynamic>> posts = [];
  final Set<String> _viewedPosts = {};

  StreamSubscription? _blockSub;
  bool _initialized = false;

  // For pagination cursors + flags
  DocumentSnapshot? _lastRealDoc;
  DocumentSnapshot? _lastDefaultDoc;
  bool _hasMoreReal = true;
  bool _hasMoreDefault = true;

  late TabController _tabController;
  int _currentTabIndex = 0;

  final Random _rand = Random();

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

    _blockSub = _firestore
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

    _loadCurrentUserAvatarCache();

    initPage();
  }

  Future<void> _loadCurrentUserAvatarCache() async {
    final avatar = await _getCurrentUserAvatar();
    if (mounted) {
      setState(() {
        _cachedCurrentUserAvatar = avatar;
        _avatarCacheLoaded = true;
      });
    }
  }

  void _onScroll() {
    if (!_feedScrollController.hasClients) return;

    final position = _feedScrollController.position;

    // Trigger load when user is near the bottom (80% scrolled)
    final threshold = position.maxScrollExtent * 0.8;

    if (position.pixels >= threshold &&
        !_isFetchingPosts &&
        !isLoadingMorePosts &&
        (_hasMoreReal || _hasMoreDefault)) {
      debugPrint("🔄 Scroll threshold reached, loading more posts...");
      _loadMorePosts();
    }
  }

  @override
  void dispose() {
    _blockSub?.cancel();
    _tabController.dispose();
    _feedScrollController.dispose();
    _cachedCurrentUserAvatar = null; // Clear cache
    super.dispose();
  }

  Future<void> initPage() async {
    if (_initialized) return;
    _initialized = true;

    if (!mounted) return;
    setState(() => isLoading = true);

    await fetchBlockedUsers();
    await loadDefaultUsers(); // community list
    await loadPosts(forceRefresh: true);

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

  // Update these specific methods in your bwb_page.dart

  // 1. UPDATE: _getUserBadge method (add this if not exists, or replace existing)
  Widget _getUserBadge(Map<String, dynamic> item, {bool isPost = true}) {
    final uid = auth.currentUser?.uid ?? '';

    if (isPost) {
      final postUserId = item['userId']?.toString() ?? '';
      final isOwn =
          (item['isCurrentUser'] == true) ||
          (postUserId.isNotEmpty && postUserId == uid);

      if (isOwn) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
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
        );
      }
    }

    // Check if this is from mUsers (default/example content)
    final isExample = item['isDefault'] == true || item['source'] == 'default';

    if (isExample) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4.r),
          border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
        ),
        child: Text(
          'Eg',
          style: TextStyle(
            color: Colors.green,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox.shrink();
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
            final map = Map<String, dynamic>.from(e.data() as Map);
            map['id'] = e.id;
            map['source'] = 'default'; // ✅ Mark as default
            map['isDefault'] = true; // ✅ Mark as default
            return map;
          })
          .where((u) => !blockedUsers.contains(u['id']))
          .toList();

      if (!mounted) return;
      setState(() => users = data);
    } catch (e) {
      debugPrint('Error loading default users: $e');
    }
  }

  // 5. UPDATE: showInfoDialog - Add explanation about Example badges
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

              SizedBox(height: 16.h),
              Text(
                '• Find real people on the same journey as you.',
                style: TextStyle(fontSize: 13.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                '• People support each other here.',
                style: TextStyle(fontSize: 13.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                '• Create your own posts and connect with the community.',
                style: TextStyle(fontSize: 13.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                '• Full control. Full privacy. Always.',
                style: TextStyle(fontSize: 13.sp),
              ),
              Text(
                '• Users and posts with green "Eg" badges are sample content to help understand how the app works.',
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
                context.pop();
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
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
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
                onPressed: () => context.pop(),
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
                  context.pop();
                  Geolocator.openLocationSettings();
                },
              ),
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => context.pop(),
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

      // save current user's loc
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
          final userMap = Map<String, dynamic>.from(data);
          userMap['id'] = doc.id;
          userMap['distance'] = distKm;
          realNearby.add(userMap);
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
            .map(
              (e) => {
                ...Map<String, dynamic>.from(e.data() as Map),
                'id': e.id,
              },
            )
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

  final Set<String> _firstBumpedPosts = {};
  final Map<String, int> _lastIncrementTs = {}; // postId -> epochSeconds
  final Random _rnd = Random();

  Future<void> incrementViewCount(Map<String, dynamic> post) async {
    try {
      final postId = post['postId']?.toString();
      if (postId == null || postId.isEmpty) return;

      // Only increment once per session per post
      if (_viewedPosts.contains(postId)) return;
      _viewedPosts.add(postId);

      final newViews = (post['viewCount'] ?? 0) + 1;
      post['viewCount'] = newViews;

      if (post['isDefault'] == true || post['source'] == 'default') {
        try {
          await _firestore
              .collection("posts")
              .doc("mUsers")
              .collection("all")
              .doc(postId)
              .update({"viewCount": newViews});
        } catch (_) {}
        return;
      }

      try {
        await _firestore
            .collection("posts")
            .doc("rUsers")
            .collection("all")
            .doc(postId)
            .update({"viewCount": newViews});
      } catch (_) {}
    } catch (e) {
      debugPrint("incrementViewCount error: $e");
    }
  }

  Future<void> safeIncrement(Map<String, dynamic> post) async {
    final String postId = post['postId'].toString();
    if (postId.isEmpty) return;

    final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Rule 1: First time in session → guaranteed bump
    if (!_firstBumpedPosts.contains(postId)) {
      _firstBumpedPosts.add(postId);
      _lastIncrementTs[postId] = now;
      await incrementViewCount(post);
      return;
    }

    // Rule 2: Cooldown — must wait at least 10 seconds
    if (_lastIncrementTs.containsKey(postId)) {
      final last = _lastIncrementTs[postId]!;
      if (now - last < 10) return; // limit to once per 10 seconds
    }

    // Rule 3: Random bump only 20% chance
    if (_rnd.nextDouble() > 0.20) return;

    _lastIncrementTs[postId] = now;
    await incrementViewCount(post);
  }

  // Fix for BWB Page - Replace the _getUserProfileImage method and update post card building

  // REPLACE the existing _getUserProfileImage method with this improved version:
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

        // 1) HIGHEST PRIORITY: Custom avatar URL
        final customImg = profileData['customAvatarUrl'];
        if (customImg != null && customImg.toString().trim().isNotEmpty) {
          debugPrint('✅ Using customAvatarUrl for $userId: $customImg');
          return customImg.toString().trim();
        }

        // 2) SECOND PRIORITY: Regular img field
        final img = profileData['img'];
        if (img != null && img.toString().trim().isNotEmpty) {
          debugPrint('✅ Using img for $userId: $img');
          return img.toString().trim();
        }
      }

      // 3) FALLBACK: Streak-based avatar from Firebase Storage
      if (streaks != null) {
        final level = AvatarManager.getLevelFromDays(streaks);
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('avatarsImg')
              .child('$level.png');
          final downloadUrl = await storageRef.getDownloadURL();
          debugPrint('✅ Using streak avatar for $userId: $downloadUrl');
          return downloadUrl;
        } catch (e) {
          debugPrint('⚠️ Failed to load streak avatar: $e');
        }
      }

      debugPrint('❌ No avatar found for $userId');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user profile image: $e');
      return null;
    }
  }

  // UPDATE the createPost method to fetch and store the correct profile image:
  Future<void> createPost(String postText) async {
    if (postText.trim().isEmpty) return;

    try {
      final uid = auth.currentUser!.uid;

      final profileSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('data')
          .get();

      final profile = profileSnap.data() ?? {};
      final name = profile['name'] ?? 'Anonymous';
      final streaks = profile['currentStreak'] ?? 0;

      // Get the correct profile image using the same priority logic
      String? dp;

      // 1) Try custom avatar first
      final customImg = profile['customAvatarUrl'];
      if (customImg != null && customImg.toString().trim().isNotEmpty) {
        dp = customImg.toString().trim();
        debugPrint('✅ Post using customAvatarUrl: $dp');
      }

      // 2) Try regular img field
      if (dp == null) {
        final img = profile['img'];
        if (img != null && img.toString().trim().isNotEmpty) {
          dp = img.toString().trim();
          debugPrint('✅ Post using img: $dp');
        }
      }

      // 3) Fallback to streak avatar
      if (dp == null) {
        final level = AvatarManager.getLevelFromDays(streaks);
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('avatarsImg')
              .child('$level.png');
          dp = await storageRef.getDownloadURL();
          debugPrint('✅ Post using streak avatar: $dp');
        } catch (e) {
          debugPrint('⚠️ Failed to load streak avatar: $e');
        }
      }

      final postId = _firestore.collection('x').doc().id;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final postData = <String, dynamic>{
        "postId": postId,
        "userId": uid,
        "name": name,
        "dp": dp, // This will now contain the correct profile image
        "postText": postText.trim(),
        "streaks": streaks,
        "timestamp": timestamp,
        "likes": 0,
        "viewCount": Random().nextInt(20),
        "isDefault": false,
        "source": "real",
      };

      await _firestore
          .collection("posts")
          .doc("rUsers")
          .collection("all")
          .doc(postId)
          .set(postData);

      await _firestore
          .collection("users")
          .doc(uid)
          .collection("posts")
          .doc(postId)
          .set(postData);

      // Refresh feed
      await loadPosts(forceRefresh: true);

      _showSnackbar("Post shared with community! 🎉", Colors.deepPurple);
    } catch (e) {
      debugPrint("❌ createPost error: $e");
      _showSnackbar("Failed to create post", Colors.red);
    }
  }

  // UPDATE the _buildPostCard CircleAvatar section for better image handling:
  Widget _buildPostCard(Map<String, dynamic> post) {
    final uid = auth.currentUser?.uid ?? '';
    final postUserId = post['userId']?.toString() ?? '';

    final isOwn =
        (post['isCurrentUser'] == true) ||
        (postUserId.isNotEmpty && postUserId == uid);

    return GestureDetector(
      onLongPress: () {
        if (isOwn) {
          _confirmDelete(post);
        } else {
          _showReportDialog(post);
        }
      },
      onTap: () => handlePostUserTap(post),
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
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: Colors.grey[800],
                  child: _buildPostAvatar(post),
                ),
                SizedBox(width: 12.w),
                Expanded(
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
                          _getUserBadge(post, isPost: true), // ✅ UPDATED
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Text(
                            _getTimeAgo(post['timestamp'] ?? 0),
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12.sp,
                            ),
                          ),
                          if (post['streaks'] != null &&
                              post['streaks'] > 0) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepOrangeAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedFire02,
                                    color: Colors.deepOrangeAccent,
                                    size: 11.r,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    '${post['streaks']}',
                                    style: TextStyle(
                                      color: Colors.deepOrangeAccent,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

  // ADD this new helper method to build the avatar widget:
  Widget _buildPostAvatar(Map<String, dynamic> post) {
    final uid = auth.currentUser?.uid ?? '';
    final postUserId = post['userId']?.toString() ?? '';
    final isOwn =
        (post['isCurrentUser'] == true) ||
        (postUserId.isNotEmpty && postUserId == uid);

    // ✅ Use cached avatar for current user
    if (isOwn) {
      if (_avatarCacheLoaded && _cachedCurrentUserAvatar != null) {
        return _cachedCurrentUserAvatar!;
      }
      return Center(
        child: SizedBox(
          width: 20.r,
          height: 20.r,
          child: CupertinoActivityIndicator(
            radius: 10.r, // ✅ Consistent sizing
          ),
        ),
      );
    }
    // For other users' posts, use the dp from post data
    final dpUrl = post['dp']?.toString().trim() ?? '';
    debugPrint('🖼️ Building avatar for ${post['name']}: $dpUrl');

    if (dpUrl.isNotEmpty) {
      return // For network images
      ClipOval(
        child: Image.network(
          dpUrl,
          width: 44.r,
          height: 44.r,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 20.r,
                height: 20.r,
                child: CupertinoActivityIndicator(
                  radius: 10.r, // ✅ Match other loaders
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Failed to load image: $dpUrl - Error: $error');
            return Icon(Icons.person, size: 24.r, color: Colors.grey[400]);
          },
        ),
      );
    }

    return Icon(Icons.person, size: 24.r, color: Colors.grey[400]);
  }

  void showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final textController = TextEditingController();

        return Dialog(
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
                          Navigator.of(dialogContext).pop();
                          // Don't dispose - let it be garbage collected
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
                          Navigator.of(dialogContext).pop();
                          // Don't dispose - let it be garbage collected
                          if (text.isNotEmpty) await createPost(text);
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
        );
      },
    );
  }

  Future<Widget> _getCurrentUserAvatar() async {
    try {
      // 1) Check for custom avatar first (local file)
      final directory = await getApplicationDocumentsDirectory();
      final customAvatarPath = '${directory.path}/custom_avatar.png';

      if (File(customAvatarPath).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(customAvatarPath),
            width: 44.r,
            height: 44.r,
            fit: BoxFit.cover,
          ),
        );
      }

      // 2) Load streak-based avatar
      final currentStreakDays = StreaksData.currentStreakDays;
      final calculatedLevel = AvatarManager.getLevelFromDays(currentStreakDays);

      // Try Firebase Storage first
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('avatarsImg')
            .child('$calculatedLevel.png');

        final downloadUrl = await storageRef.getDownloadURL();

        return ClipOval(
          child: Image.network(
            downloadUrl,
            width: 44.r,
            height: 44.r,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to local asset
              return Image.asset(
                'assets/3d/lvl$calculatedLevel.png',
                width: 44.r,
                height: 44.r,
                fit: BoxFit.cover,
              );
            },
          ),
        );
      } catch (e) {
        // Use local asset directly
        return ClipOval(
          child: Image.asset(
            'assets/3d/lvl$calculatedLevel.png',
            width: 44.r,
            height: 44.r,
            fit: BoxFit.cover,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading current user avatar: $e');
      return Icon(Icons.person, size: 24.r, color: Colors.grey[400]);
    }
  }

  void _showReportDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final reportController = TextEditingController();

        return AlertDialog(
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
                  "Sorry for the inconvenience! We'll review this report. Thank you!",
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
                Navigator.of(dialogContext).pop();
                // Don't dispose - let it be garbage collected
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
                final msg = reportController.text.trim();
                Navigator.of(dialogContext).pop();
                // Don't dispose - let it be garbage collected
                await reportPost(post, msg);
              },
              child: Text(
                'Report Post',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
          ],
        );
      },
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

  String _getTimeAgo(int timestamp) {
    final now = DateTime.now();
    final postTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(postTime);

    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<List<Map<String, dynamic>>> getUserPosts(String userId) async {
    try {
      final userPostsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .get();
      return userPostsSnap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        return {...data, 'postId': d.id, 'isCurrentUser': true};
      }).toList();
    } catch (e) {
      debugPrint("Error fetching user posts: $e");
      return [];
    }
  }

  // ========================================
  // MAIN FEED LOADER (own → real → default)
  // lazy default loading, dedupe, merge, and randomize own posts inside top 10
  // ========================================
  // Simple, clean post loading - no over-engineering
  Future<void> loadPosts({bool forceRefresh = false}) async {
    if (!mounted || _isFetchingPosts) return;
    _isFetchingPosts = true;

    if (forceRefresh) {
      _lastRealDoc = null;
      _lastDefaultDoc = null;
      _hasMoreReal = true;
      _hasMoreDefault = true;
      posts.clear();
      _viewedPosts.clear();
    }

    if (mounted) setState(() => isLoadingPosts = true);

    try {
      final uid = auth.currentUser!.uid;
      final Set<String> existingIds = posts
          .map((p) => p['postId'].toString())
          .toSet();
      List<Map<String, dynamic>> newPosts = [];

      // ============================================
      // 1) FETCH REAL POSTS (from rUsers/all)
      // ============================================
      if (_hasMoreReal) {
        Query query = _firestore
            .collection("posts")
            .doc("rUsers")
            .collection("all")
            .orderBy("timestamp", descending: true)
            .limit(_pageSize);

        if (_lastRealDoc != null) {
          query = query.startAfterDocument(_lastRealDoc!);
        }

        final snapshot = await query.get();
        debugPrint("📥 Fetched ${snapshot.docs.length} real posts");

        if (snapshot.docs.isNotEmpty) {
          _lastRealDoc = snapshot.docs.last;

          for (var doc in snapshot.docs) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            final postId = doc.id;
            final userId = data['userId']?.toString() ?? '';

            // Skip if already in list (deduplication)
            if (existingIds.contains(postId)) continue;

            // Skip blocked users
            if (blockedUsers.contains(userId)) continue;

            data['postId'] = postId;
            data['isCurrentUser'] = (userId == uid);
            data['isDefault'] = false;
            data['source'] = 'real';

            newPosts.add(data);
            existingIds.add(postId);
          }

          if (snapshot.docs.length < _pageSize) {
            _hasMoreReal = false;
            debugPrint("✅ No more real posts");
          }
        } else {
          _hasMoreReal = false;
          debugPrint("✅ No more real posts");
        }
      }

      // ============================================
      // 2) FETCH DEFAULT POSTS (from mUsers/all)
      // ============================================
      if (newPosts.length < 10 && _hasMoreDefault) {
        final needed = max(10 - newPosts.length, _defaultLimit);

        Query query = _firestore
            .collection("posts")
            .doc("mUsers")
            .collection("all")
            .orderBy("timestamp", descending: true)
            .limit(needed);

        if (_lastDefaultDoc != null) {
          query = query.startAfterDocument(_lastDefaultDoc!);
        }

        final snapshot = await query.get();
        debugPrint("📥 Fetched ${snapshot.docs.length} default posts");

        if (snapshot.docs.isNotEmpty) {
          _lastDefaultDoc = snapshot.docs.last;

          for (var doc in snapshot.docs) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            final postId = doc.id;

            if (existingIds.contains(postId)) continue;

            data['postId'] = postId;
            data['isCurrentUser'] = false;
            data['isDefault'] = true;
            data['source'] = 'default';

            newPosts.add(data);
            existingIds.add(postId);
          }

          if (snapshot.docs.length < needed) {
            _hasMoreDefault = false;
            debugPrint("✅ No more default posts");
          }
        } else {
          _hasMoreDefault = false;
          debugPrint("✅ No more default posts");
        }
      }

      // ============================================
      // 3) ADD NEW POSTS & SORT CHRONOLOGICALLY
      // ============================================
      posts.addAll(newPosts);

      // Sort everything by timestamp (newest first)
      posts.sort((a, b) {
        final aTime = a['timestamp'] ?? 0;
        final bTime = b['timestamp'] ?? 0;
        return bTime.compareTo(aTime); // Descending order
      });

      debugPrint(
        "📊 Loaded ${newPosts.length} new posts. Total now: ${posts.length}",
      );
      debugPrint(
        "🔄 Has more real: $_hasMoreReal, Has more default: $_hasMoreDefault",
      );
    } catch (e) {
      debugPrint("❌ loadPosts error: $e");
      _showSnackbar("Failed to load posts", Colors.red);
    }

    if (mounted) setState(() => isLoadingPosts = false);
    _isFetchingPosts = false;
  }

  // Load more posts when scrolling to bottom
  Future<void> _loadMorePosts() async {
    if (_isFetchingPosts) return;
    if (!_hasMoreReal && !_hasMoreDefault) {
      debugPrint("⛔ No more posts to load");
      return;
    }

    debugPrint("🔄 Loading more posts...");
    setState(() => isLoadingMorePosts = true);

    await loadPosts(); // Don't pass forceRefresh - we want to continue from cursor

    if (mounted) setState(() => isLoadingMorePosts = false);
  } // Replace your deletePost function with this improved version:

  Future<void> deletePost(Map<String, dynamic> post) async {
    try {
      final uid = auth.currentUser!.uid;
      final postId = post['postId'];
      final postUserId = post['userId']?.toString() ?? '';

      debugPrint("🗑️ Attempting to delete post: $postId");
      debugPrint("🗑️ Current user: $uid");
      debugPrint("🗑️ Post userId: $postUserId");
      debugPrint("🗑️ isCurrentUser flag: ${post['isCurrentUser']}");

      if (postId == null || postId.toString().isEmpty) {
        debugPrint("❌ Post ID is null or empty");
        _showSnackbar("Invalid post ID", Colors.red);
        return;
      }

      // More robust userId comparison
      if (postUserId.trim() != uid.trim()) {
        debugPrint("❌ User ID mismatch: '$postUserId' != '$uid'");
        _showSnackbar("You can only delete your own posts", Colors.red);
        return;
      }

      // Delete from global posts collection
      try {
        await _firestore
            .collection("posts")
            .doc("rUsers")
            .collection("all")
            .doc(postId.toString())
            .delete();
        debugPrint("✅ Deleted from rUsers/all");
      } catch (e) {
        debugPrint("⚠️ Failed to delete from rUsers/all: $e");
        // Continue anyway - might not exist there
      }

      // Delete from user's personal posts
      try {
        await _firestore
            .collection("users")
            .doc(uid)
            .collection("posts")
            .doc(postId.toString())
            .delete();
        debugPrint("✅ Deleted from user posts");
      } catch (e) {
        debugPrint("⚠️ Failed to delete from user posts: $e");
      }

      // Remove from local lists
      posts.removeWhere((p) => p['postId']?.toString() == postId.toString());

      if (mounted) setState(() {});

      _showSnackbar("Post deleted successfully", Colors.green);
    } catch (e) {
      debugPrint("❌ deletePost error: $e");
      _showSnackbar("Failed to delete: ${e.toString()}", Colors.red);
    }
  }

  // Also update _buildPostCard to add better debugging:

  Future<void> handlePostUserTap(Map<String, dynamic> post) async {
    final otherUserId = post['userId'] ?? '';
    if (post['isCurrentUser'] == true ||
        post['isDefault'] == true ||
        otherUserId.isEmpty) {
      debugPrint("👤 Cannot chat with this post");
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

  Future<void> reportPost(Map<String, dynamic> post, String message) async {
    final postId = post['postId']?.toString() ?? '';
    final uid = auth.currentUser?.uid ?? '';

    debugPrint("🚨 Reporting post: $postId");
    debugPrint("🚨 Post userId: ${post['userId']}");
    debugPrint("🚨 Is default: ${post['isDefault']}");
    debugPrint("🚨 Source: ${post['source']}");

    if (postId.isEmpty) {
      debugPrint("❌ Post ID is empty");
      _showSnackbar("Invalid post", Colors.red);
      return;
    }

    try {
      // Save the report first (this is most important)
      await _firestore.collection("reports").add({
        "postId": postId,
        "userId": post["userId"]?.toString() ?? "unknown",
        "reportedBy": uid,
        "message": message.isEmpty ? "No message" : message,
        "timestamp": FieldValue.serverTimestamp(),
        "source": post["source"] ?? "unknown",
        "isDefault": post["isDefault"] ?? false,
      });
      debugPrint("✅ Report saved successfully");

      // Determine correct delete target
      final bool isDefault =
          post["isDefault"] == true || post["source"] == "default";

      // Try to delete the post (best effort - don't fail if this doesn't work)
      if (isDefault) {
        try {
          await _firestore
              .collection("posts")
              .doc("mUsers")
              .collection("all")
              .doc(postId)
              .delete();
          debugPrint("✅ Deleted from mUsers/all");
        } catch (e) {
          debugPrint("⚠️ Could not delete from mUsers/all: $e");
          // Don't throw - reporting succeeded
        }
      } else {
        // Try to delete from real posts
        try {
          await _firestore
              .collection("posts")
              .doc("rUsers")
              .collection("all")
              .doc(postId)
              .delete();
          debugPrint("✅ Deleted from rUsers/all");
        } catch (e) {
          debugPrint("⚠️ Could not delete from rUsers/all: $e");
          // Don't throw - reporting succeeded
        }

        // Try to delete from user's private posts
        final reportedUserId = post["userId"]?.toString() ?? '';
        if (reportedUserId.isNotEmpty) {
          try {
            await _firestore
                .collection("users")
                .doc(reportedUserId)
                .collection("posts")
                .doc(postId)
                .delete();
            debugPrint("✅ Deleted from user's posts");
          } catch (e) {
            debugPrint("⚠️ Could not delete from user posts: $e");
            // Don't throw - reporting succeeded
          }
        }
      }

      // Remove from local feed
      posts.removeWhere((p) => p['postId']?.toString() == postId);
      if (mounted) setState(() {});

      _showSnackbar("Post reported and removed. Thank you!", Colors.green);
    } catch (e) {
      debugPrint("❌ reportPost error: $e");
      _showSnackbar("Report saved, but couldn't remove post", Colors.orange);
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
            onPressed: () => context.pop(),
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
              context.pop();
              deletePost(post);
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

              // ✅ Check if user is from mUsers (example user)
              final isExampleUser =
                  user['source'] == 'default' || user['isDefault'] == true;

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
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          user['name'] ?? 'Unknown',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isExampleUser) ...[
                        SizedBox(width: 6.w),
                        _getUserBadge(user, isPost: false), // ✅ Add badge
                      ],
                    ],
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

  Widget _buildFeedTab() {
    if (isLoadingPosts && posts.isEmpty) {
      // Initial loading state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(color: Colors.white24, radius: 16.r),
            SizedBox(height: 16.h),
            Text(
              'Loading posts...',
              style: TextStyle(color: Colors.white38, fontSize: 14.sp),
            ),
          ],
        ),
      );
    }

    if (posts.isEmpty && !isLoadingPosts) {
      // Empty state
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

    // Posts list with lazy loading
    return RefreshIndicator(
      onRefresh: () async {
        await loadPosts(forceRefresh: true);
      },
      backgroundColor: const Color(0xFF1C1C1E),
      color: Colors.deepPurple,
      child: ListView.builder(
        controller: _feedScrollController,
        physics:
            const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh even with few items
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 12.h,
          bottom: 80.h,
        ),
        itemCount:
            posts.length +
            1, // Always add 1 for loading indicator or end message
        itemBuilder: (context, index) {
          // Loading indicator or end message at bottom
          if (index == posts.length) {
            if (isLoadingMorePosts) {
              return Container(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Column(
                  children: [
                    CupertinoActivityIndicator(
                      color: Colors.deepPurple,
                      radius: 14.r,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Loading more posts...',
                      style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                    ),
                  ],
                ),
              );
            } else if (!_hasMoreReal && !_hasMoreDefault) {
              return Container(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 24.r,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "You're all caught up!",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // Has more but not currently loading - show nothing or a subtle indicator
              return SizedBox(height: 20.h);
            }
          }

          final post = posts[index];

          safeIncrement(post);

          return _buildPostCard(post);
        },
      ),
    );
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
            labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
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
}
