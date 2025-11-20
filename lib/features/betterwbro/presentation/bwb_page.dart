// lib/features/betterwbro/bwb_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cleanmind/core/globals.dart';
import 'package:cleanmind/features/ai_model/presentation/ai_mainpage.dart';
import 'package:cleanmind/features/avatar/avatar_data.dart';
import 'package:cleanmind/features/betterwbro/chat/chat_screen.dart';
import 'package:cleanmind/features/streaks_page/data/streaks_data.dart';
import 'package:cleanmind/utilis/snackbar.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
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
  Position? currentPosition;
  Set<String> blockedUsers = {};

  bool isLoadingPosts = true;
  bool isLoadingMorePosts = false;

  final int _pageSize = 20;
  final int _defaultLimit = 6;

  bool _isFetchingPosts = false;

  List<Map<String, dynamic>> posts = [];
  final Set<String> _viewedPosts = {};

  StreamSubscription? _blockSub;
  bool _initialized = false;

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

  bool _scrollLock = false;

  void _onScroll() {
    if (_scrollLock) return;
    if (!_feedScrollController.hasClients) return;
    if (posts.isEmpty) return; // 🔥 Prevent initial double load

    final pos = _feedScrollController.position;

    if (pos.maxScrollExtent == 0) return; // 🔥 Prevent early trigger

    if (pos.pixels >= pos.maxScrollExtent * 0.8) {
      _scrollLock = true;

      _loadMorePosts().then((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollLock = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _blockSub?.cancel();
    _tabController.dispose();
    _feedScrollController.dispose();
    _cachedCurrentUserAvatar = null;
    super.dispose();
  }

  Future<void> initPage() async {
    if (_initialized) return;
    _initialized = true;

    if (!mounted) return;
    setState(() => isLoading = true);

    await fetchBlockedUsers();

    // Check permission silently without prompting
    hasPermission = await checkPermissionSilently();

    await loadAllUsers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadPosts(forceRefresh: true);
    });

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

  Future<void> loadAllUsers() async {
    try {
      final allUsersSnap = await _firestore.collection('users').get();
      List<Map<String, dynamic>> realUsers = [];

      for (var doc in allUsersSnap.docs) {
        if (doc.id == auth.currentUser!.uid) continue;
        if (doc.id == 'mUsers') continue;
        if (blockedUsers.contains(doc.id)) continue;

        var profileDoc = await doc.reference
            .collection('profile')
            .doc('data')
            .get();

        if (!profileDoc.exists) {
          await doc.reference.collection('profile').doc('data').set({
            'name': 'User',
            'img': null,
            'currentStreak': 0,
            'totalStreaks': 0,
            'streaks': 0,
            'status': 'offline',
          }, SetOptions(merge: true));

          profileDoc = await doc.reference
              .collection('profile')
              .doc('data')
              .get();
        }

        final data = profileDoc.data()!;
        final userMap = Map<String, dynamic>.from(data);
        userMap['id'] = doc.id;
        userMap['source'] = 'real';
        userMap['isDefault'] = false;

        if (hasPermission &&
            data['loc'] != null &&
            data['loc']['geopoint'] != null) {
          if (currentPosition == null) {
            try {
              currentPosition = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );

              await _firestore
                  .collection('users')
                  .doc(auth.currentUser!.uid)
                  .collection('profile')
                  .doc('data')
                  .set({
                    'loc': {
                      'geopoint': GeoPoint(
                        currentPosition!.latitude,
                        currentPosition!.longitude,
                      ),
                    },
                  }, SetOptions(merge: true));
            } catch (e) {
              debugPrint('⚠️ Could not get current position: $e');
            }
          }

          if (currentPosition != null) {
            GeoPoint gp = data['loc']['geopoint'];
            double distKm =
                Geolocator.distanceBetween(
                  currentPosition!.latitude,
                  currentPosition!.longitude,
                  gp.latitude,
                  gp.longitude,
                ) /
                1000;
            userMap['distance'] = distKm;
          }
        }

        realUsers.add(userMap);
      }

      if (hasPermission) {
        realUsers.sort((a, b) {
          final aDist = a['distance'] as double?;
          final bDist = b['distance'] as double?;
          if (aDist == null && bDist == null) return 0;
          if (aDist == null) return 1;
          if (bDist == null) return -1;
          return aDist.compareTo(bDist);
        });
      }

      List<Map<String, dynamic>> finalUsers = List.from(realUsers);

      if (finalUsers.length < 10) {
        final needed = 10 - finalUsers.length;
        final defaultSnap = await _firestore
            .collection('users')
            .doc('mUsers')
            .collection('userList')
            .limit(20) // fetch 20 always
            .get();

        final defaults = defaultSnap.docs
            .map(
              (e) => {
                ...Map<String, dynamic>.from(e.data() as Map),
                'id': e.id,
                'source': 'default',
                'isDefault': true,
              },
            )
            .where((u) => !blockedUsers.contains(u['id']));

        finalUsers.addAll(defaults);
      }

      if (!mounted) return;
      setState(() => users = finalUsers);

      debugPrint(
        "✅ Loaded ${realUsers.length} real users and ${finalUsers.length - realUsers.length} example users",
      );
    } catch (e) {
      debugPrint("❌ Error in loadAllUsers: $e");
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
              SizedBox(height: 12.h),

              Text(
                '• Long press on any post to report inappropriate content.',
                style: TextStyle(fontSize: 13.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                '• Users and posts with green "Eg" badges are sample content to help understand how the app works.',
                style: TextStyle(fontSize: 13.sp),
              ),
              if (!hasPermission) ...[
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: Colors.deepPurple.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '📍 Enable location to find people nearby based on distance',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!hasPermission)
            CupertinoDialogAction(
              child: const Text('Enable Location'),
              onPressed: () async {
                context.pop();
                if (!mounted) return;
                setState(() => isLoading = true);
                final granted = await requestPermission();
                if (granted) {
                  hasPermission = true;
                  await loadAllUsers();
                }
                if (!mounted) return;
                setState(() => isLoading = false);
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
      return permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return false;
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text(
              'Please enable location services in your device settings to find nearby users.',
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
              'Please enable location permission in your device settings to find nearby users.',
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

      return permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      return false;
    }
  }

  final Set<String> _firstBumpedPosts = {};
  final Map<String, int> _lastIncrementTs = {};
  final Random _rnd = Random();

  Future<void> incrementViewCount(Map<String, dynamic> post) async {
    try {
      final postId = post['postId']?.toString();
      if (postId == null || postId.isEmpty) return;

      if (_viewedPosts.contains(postId)) return;
      _viewedPosts.add(postId);

      final newViews = (post['viewCount'] ?? 0) + 1;
      post['viewCount'] = newViews;

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
    if (post["isDefault"] == true) return; // 🔥 FIXED
    if (post["source"] == "default") return; // 🔥 FIXED

    final postId = post['postId']?.toString();
    if (postId == null) return;
    if (_viewedPosts.contains(postId)) return;

    _viewedPosts.add(postId);

    try {
      final newViews = (post['viewCount'] ?? 0) + 1;
      post['viewCount'] = newViews;

      await _firestore
          .collection("posts")
          .doc("rUsers")
          .collection("all")
          .doc(postId)
          .update({"viewCount": newViews});
    } catch (_) {}
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
        if (customImg != null && customImg.toString().trim().isNotEmpty) {
          debugPrint('✅ Using customAvatarUrl for $userId: $customImg');
          return customImg.toString().trim();
        }

        final img = profileData['img'];
        if (img != null && img.toString().trim().isNotEmpty) {
          debugPrint('✅ Using img for $userId: $img');
          return img.toString().trim();
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

      String? dp;

      final customImg = profile['customAvatarUrl'];
      if (customImg != null && customImg.toString().trim().isNotEmpty) {
        dp = customImg.toString().trim();
        debugPrint('✅ Post using customAvatarUrl: $dp');
      }

      if (dp == null) {
        final img = profile['img'];
        if (img != null && img.toString().trim().isNotEmpty) {
          dp = img.toString().trim();
          debugPrint('✅ Post using img: $dp');
        }
      }

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
        "dp": dp,
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

      await loadPosts(forceRefresh: true);

      _showSnackbar("Post shared with community! 🎉", Colors.deepPurple);
    } catch (e) {
      debugPrint("❌ createPost error: $e");
      _showSnackbar("Failed to create post", Colors.red);
    }
  }

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
                          _getUserBadge(post, isPost: true),
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

  Widget _buildPostAvatar(Map<String, dynamic> post) {
    final uid = auth.currentUser?.uid ?? '';
    final postUserId = post['userId']?.toString() ?? '';
    final isOwn =
        (post['isCurrentUser'] == true) ||
        (postUserId.isNotEmpty && postUserId == uid);

    if (isOwn) {
      if (_avatarCacheLoaded && _cachedCurrentUserAvatar != null) {
        return _cachedCurrentUserAvatar!;
      }
      return Center(
        child: SizedBox(
          width: 20.r,
          height: 20.r,
          child: CupertinoActivityIndicator(radius: 10.r),
        ),
      );
    }

    final dpUrl = post['dp']?.toString().trim() ?? '';
    debugPrint('🖼️ Building avatar for ${post['name']}: $dpUrl');

    if (dpUrl.isNotEmpty) {
      return ClipOval(
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
                child: CupertinoActivityIndicator(radius: 10.r),
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

      final currentStreakDays = StreaksData.currentStreakDays;
      final calculatedLevel = AvatarManager.getLevelFromDays(currentStreakDays);

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
      _showSnackbar("This user is blocked.", Colors.red);
      return;
    }

    // Example user → img comes from Firestore
    if (user['isDefault'] == true || user['source'] == 'default') {
      return _openChatScreen(
        userId: otherUserId,
        name: user['name'],
        imageUrl: user['img'], // default users have firebase img
        distance: user['distance'],
        streaks: user['streaks'] ?? 0,
        totalStreaks: user['totalStreaks'] ?? 0,
      );
    }

    // REAL USER — USE LOCALLY CALCULATED STREAK AVATAR
    final int streaks = user['currentStreak'] ?? user['streaks'] ?? 0;
    final int level = AvatarManager.getLevelFromDays(streaks);

    final String avatarAsset = "assets/3d/lvl$level.png";

    return _openChatScreen(
      userId: otherUserId,
      name: user['name'],
      imageUrl: avatarAsset, // 🔥 PASS LOCAL ASSET PATH
      distance: user['distance'],
      streaks: streaks,
      totalStreaks: user['totalStreaks'] ?? 0,
    );
  }

  void _openChatScreen({
    required String userId,
    required String? name,
    required String? imageUrl,
    required double? distance,
    required int streaks,
    required int totalStreaks,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BChatScreen(
          userId: userId,
          name: name ?? 'Unknown',
          status: 'online',
          imageUrl: imageUrl, // NOW ALWAYS CORRECT
          distance: distance,
          streaks: streaks,
          totalStreaks: totalStreaks,
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

  Future<void> loadPosts({bool forceRefresh = false}) async {
    if (!mounted || _isFetchingPosts) return;
    _isFetchingPosts = true;

    if (forceRefresh) {
      posts.clear();
      _viewedPosts.clear();
      _lastRealDoc = null;
      _lastDefaultDoc = null;
      _hasMoreReal = true;
      _hasMoreDefault = true;
    }

    if (mounted) setState(() => isLoadingPosts = posts.isEmpty);

    try {
      final uid = auth.currentUser!.uid;

      // Create a set of ALL loaded IDs (including existing posts)
      final Set<String> allLoadedIds = posts
          .map((p) => p['postId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      List<Map<String, dynamic>> fresh = [];

      // -------------------------
      // 1) Load real posts (primary)
      // -------------------------
      if (_hasMoreReal) {
        Query q = _firestore
            .collection("posts")
            .doc("rUsers")
            .collection("all")
            .orderBy("timestamp", descending: true)
            .limit(_pageSize);

        if (_lastRealDoc != null) {
          q = q.startAfterDocument(_lastRealDoc!);
        }

        final snap = await q.get();

        if (snap.docs.isEmpty) {
          _hasMoreReal = false;
        } else {
          _lastRealDoc = snap.docs.last;

          for (var d in snap.docs) {
            final id = d.id;

            // Skip if already loaded
            if (allLoadedIds.contains(id)) {
              debugPrint("⚠️ Skipping duplicate post: $id");
              continue;
            }

            final data = Map<String, dynamic>.from(d.data() as Map);
            final userId = data["userId"]?.toString() ?? "";

            if (id.isEmpty) continue;
            if (blockedUsers.contains(userId)) continue;

            fresh.add({
              ...data,
              "postId": id,
              "isCurrentUser": userId == uid,
              "isDefault": false,
              "source": "real",
            });

            allLoadedIds.add(id);
          }

          if (snap.docs.length < _pageSize) _hasMoreReal = false;
        }
      }

      // ------------------------------------------------
      // 2) Load default posts only if we need more
      // ------------------------------------------------
      final currentTotal = posts.length + fresh.length;
      if (currentTotal < 10 && _hasMoreDefault) {
        final int needed = max(10 - currentTotal, 5);

        Query dQ = _firestore
            .collection("posts")
            .doc("mUsers")
            .collection("all")
            .orderBy("timestamp", descending: true)
            .limit(needed);

        if (_lastDefaultDoc != null) {
          dQ = dQ.startAfterDocument(_lastDefaultDoc!);
        }

        final snap = await dQ.get();

        if (snap.docs.isEmpty) {
          _hasMoreDefault = false;
        } else {
          _lastDefaultDoc = snap.docs.last;

          for (var doc in snap.docs) {
            final id = doc.id;

            // Skip if already loaded
            if (allLoadedIds.contains(id)) {
              debugPrint("⚠️ Skipping duplicate default post: $id");
              continue;
            }

            if (id.isEmpty) continue;

            final data = Map<String, dynamic>.from(doc.data() as Map);

            // block default posts only if they have a userId
            final defaultUser = data["userId"]?.toString() ?? "";
            if (defaultUser.isNotEmpty && blockedUsers.contains(defaultUser)) {
              continue;
            }

            fresh.add({
              ...data,
              "postId": id,
              "isCurrentUser": false,
              "isDefault": true,
              "source": "default",
            });

            allLoadedIds.add(id);
          }

          if (snap.docs.length < needed) _hasMoreDefault = false;
        }
      }

      // -------------------------------------------------------
      // 3) Add fresh posts to existing posts
      // -------------------------------------------------------
      if (fresh.isNotEmpty) {
        posts.addAll(fresh);

        // Sort by timestamp descending
        posts.sort((a, b) {
          final tA = (a['timestamp'] is int) ? a['timestamp'] as int : 0;
          final tB = (b['timestamp'] is int) ? b['timestamp'] as int : 0;
          return tB.compareTo(tA);
        });

        debugPrint(
          "✅ Loaded ${fresh.length} new posts. Total: ${posts.length}",
        );
      }
    } catch (e, st) {
      debugPrint("loadPosts ERR: $e\n$st");
      _showSnackbar("Failed to load posts", Colors.red);
    } finally {
      if (mounted) setState(() => isLoadingPosts = false);
      _isFetchingPosts = false;
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isFetchingPosts) return;
    if (!_hasMoreReal && !_hasMoreDefault) {
      debugPrint("⛔ No more posts to load");
      return;
    }

    debugPrint("🔄 Loading more posts...");
    setState(() => isLoadingMorePosts = true);

    await loadPosts();

    if (mounted) setState(() => isLoadingMorePosts = false);
  }

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

      if (postUserId.trim() != uid.trim()) {
        debugPrint("❌ User ID mismatch: '$postUserId' != '$uid'");
        _showSnackbar("You can only delete your own posts", Colors.red);
        return;
      }

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
      }

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

      posts.removeWhere((p) => p['postId']?.toString() == postId.toString());

      if (mounted) setState(() {});

      _showSnackbar("Post deleted successfully", Colors.green);
    } catch (e) {
      debugPrint("❌ deletePost error: $e");
      _showSnackbar("Failed to delete: ${e.toString()}", Colors.red);
    }
  }

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
        builder: (_) => BChatScreen(
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

      final bool isDefault =
          post["isDefault"] == true || post["source"] == "default";

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
        }
      } else {
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
        }

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
          }
        }
      }

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

  Widget _buildCommunityUserAvatar(Map<String, dynamic> user) {
    final isExampleUser =
        user['source'] == 'default' || user['isDefault'] == true;

    if (isExampleUser) {
      final imgUrl = user['img']?.toString().trim();

      if (imgUrl != null && imgUrl.isNotEmpty) {
        return ClipOval(
          child: Image.network(
            imgUrl,
            width: 50.r,
            height: 50.r,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.person, size: 24.r, color: Colors.grey[400]),
          ),
        );
      }

      // fallback if no img field
      final lvl = AvatarManager.getLevelFromDays(user['streaks'] ?? 0);
      return ClipOval(
        child: Image.asset(
          "assets/3d/lvl$lvl.png",
          width: 50.r,
          height: 50.r,
          fit: BoxFit.cover,
        ),
      );
    }

    // For real users, fetch from their profile
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) {
      return Icon(Icons.person, size: 24.r, color: Colors.grey[400]);
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _firestore
          .collection('users')
          .doc(userId)
          .collection('profile')
          .doc('data')
          .get()
          .then((doc) => doc.exists ? doc.data() : null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 20.r,
              height: 20.r,
              child: CupertinoActivityIndicator(radius: 10.r),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Icon(Icons.person, size: 24.r, color: Colors.grey[400]);
        }

        final profileData = snapshot.data!;
        final streaks = profileData['currentStreak'] ?? 0;
        final level = AvatarManager.getLevelFromDays(streaks);

        // Check for custom avatar URL
        final customImg = profileData['customAvatarUrl'];
        if (customImg != null && customImg.toString().trim().isNotEmpty) {
          return ClipOval(
            child: Image.network(
              customImg.toString().trim(),
              width: 50.r,
              height: 50.r,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildStreakAvatar(level);
              },
            ),
          );
        }

        // Check for img field
        final img = profileData['img'];
        if (img != null && img.toString().trim().isNotEmpty) {
          return ClipOval(
            child: Image.network(
              img.toString().trim(),
              width: 50.r,
              height: 50.r,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildStreakAvatar(level);
              },
            ),
          );
        }

        // Default to streak-based avatar
        return _buildStreakAvatar(level);
      },
    );
  }

  Widget _buildStreakAvatar(int level) {
    return ClipOval(
      child: Image.asset(
        "assets/3d/lvl$level.png",
        width: 50.r,
        height: 50.r,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, size: 24.r, color: Colors.grey[400]);
        },
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
              Expanded(
                child: Text(
                  nearbyCount != 0
                      ? '$nearbyCount ${hasPermission ? 'users near you' : 'users'} on the same journey'
                      : 'Connect with people on the same journey',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
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
              if (distance != null) {
                subtitle = distance < 1
                    ? '${(distance * 1000).toStringAsFixed(0)}m away'
                    : '${distance.toStringAsFixed(1)}km away';
              }

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
                    backgroundColor: Colors.grey[800],
                    child: _buildCommunityUserAvatar(user),
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

                      // --- Streak Badge (REAL USERS ONLY) ---
                      if ((user['streaks'] ?? user['currentStreak'] ?? 0) > 0)
                        Padding(
                          padding: EdgeInsets.only(left: 6.w),
                          child: Container(
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
                                  '${user['streaks'] ?? user['currentStreak'] ?? 0}',
                                  style: TextStyle(
                                    color: Colors.deepOrangeAccent,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // --- Example badge (Eg) ---
                      if (isExampleUser) ...[
                        SizedBox(width: 6.w),
                        _getUserBadge(user, isPost: false),
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
      onRefresh: () async {
        await loadPosts(forceRefresh: true);
      },
      backgroundColor: const Color(0xFF1C1C1E),
      color: Colors.deepPurple,
      child: ListView.builder(
        controller: _feedScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 12.h,
          bottom: 80.h,
        ),
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
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
              return SizedBox(height: 20.h);
            }
          }

          final post = posts[index];

          WidgetsBinding.instance.addPostFrameCallback((_) {
            safeIncrement(post);
          });

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
