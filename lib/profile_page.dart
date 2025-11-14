import 'dart:io';
import 'dart:ui';
import 'package:feedback/feedback.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onlymens/legal_screen.dart' show LegalScreen;
import 'package:onlymens/userpost_pg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onlymens/core/data_state.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/ai_model/model/model.dart';
import 'package:onlymens/features/avatar/avatar_data.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';
import 'package:onlymens/feedback_service.dart';
import 'package:onlymens/utilis/snackbar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const MethodChannel _screenTimeChannel = MethodChannel('onlymens/screentime');

Future<bool> _requestScreenTimeAuth() async {
  try {
    return await _screenTimeChannel.invokeMethod('requestAuthorization');
  } catch (e) {
    print('❌ Screen Time auth error: $e');
    return false;
  }
}

Future<bool> _enablePornBlock(List<String> domains) async {
  try {
    await _screenTimeChannel.invokeMethod('enablePornBlock', {
      'domains': domains,
    });
    return true;
  } catch (e) {
    print('❌ Enable block error: $e');
    return false;
  }
}

Future<bool> _disablePornBlock() async {
  try {
    await _screenTimeChannel.invokeMethod('disablePornBlock');
    return true;
  } catch (e) {
    print('❌ Disable block error: $e');
    return false;
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  bool _isContentBlocked = false;
  String _userName = 'User';
  String? _customAvatarPath;
  String? _streakAvatarUrl;
  int _totalDays = 0;
  int _currentStreak = 0;
  int _progressPercentage = 0;
  String? _userEmail;

  final TextEditingController _confirmationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<String> _blockedDomains = [
    "pornhub.com",
    "xvideos.com",
    "xnxx.com",
    "redtube.com",
    "youjizz.com",
    "youporn.com",
    "tube8.com",
    "spankbang.com",
    "xhamster.com",
    "brazzers.com",
    "bangbros.com",
    "naughtyamerica.com",
    "realitykings.com",
    "fakehub.com",
    "txxx.com",
    "hqporner.com",
    "eporner.com",
    "drtuber.com",
    "porn.com",
    "sex.com",
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) return;

      final profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('data');

      final docSnapshot = await profileRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        setState(() {
          _userName = data['name'] ?? 'User';
          _totalDays = data['totalDays'] ?? 0;
          _currentStreak = data['currentStreak'] ?? 0;
          _isContentBlocked = data['contentBlocked'] ?? false;
          _userEmail = data['email'];
          _isLoading = false;
        });

        _calculateProgress();
        await _loadAvatars();
      } else {
        await profileRef.set({
          'name': auth.currentUser?.displayName ?? 'User',
          'totalDays': 0,
          'currentStreak': 0,
          'contentBlocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'email': auth.currentUser?.email,
        });

        setState(() {
          _userName = auth.currentUser?.displayName ?? 'User';
          _isLoading = false;
        });
        await _loadAvatars();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Utilis.showSnackBar('Failed to load profile', isErr: true);
    }
  }

  void _calculateProgress() {
    final heatmapData = StreaksData.getHeatmapData();

    if (heatmapData.isEmpty) {
      setState(() {
        _progressPercentage = 0;
      });
      return;
    }

    int successfulDays = 0;
    int totalDays = heatmapData.length;

    heatmapData.forEach((date, value) {
      if (value == 3) {
        successfulDays++;
      }
    });

    int percentage = totalDays > 0
        ? ((successfulDays / totalDays) * 100).round()
        : 0;

    setState(() {
      _progressPercentage = percentage;
    });
  }

  Future<void> _loadAvatars() async {
    try {
      final customPath = await _getCustomAvatarPath();
      if (customPath != null && File(customPath).existsSync()) {
        setState(() {
          _customAvatarPath = customPath;
        });
        return;
      }

      await _loadStreakAvatar();
    } catch (e) {
      print('Error loading avatars: $e');
      setState(() {
        _customAvatarPath = null;
        _streakAvatarUrl = null;
      });
    }
  }

  Future<String?> _getCustomAvatarPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customAvatarPath = '${directory.path}/custom_avatar.png';

      if (File(customAvatarPath).existsSync()) {
        return customAvatarPath;
      }
    } catch (e) {
      print('Error getting custom avatar path: $e');
    }
    return null;
  }

  Future<void> _loadStreakAvatar() async {
    try {
      final currentStreakDays = StreaksData.currentStreakDays;
      final calculatedLevel = AvatarManager.getLevelFromDays(currentStreakDays);

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('avatarsImg')
            .child('$calculatedLevel.png');

        final downloadUrl = await storageRef.getDownloadURL();
        setState(() {
          _streakAvatarUrl = downloadUrl;
        });
      } catch (storageError) {
        print('Firebase Storage failed, will use local assets');
        setState(() {
          _streakAvatarUrl = null;
        });
      }
    } catch (e) {
      print('Error loading streak avatar: $e');
      setState(() {
        _streakAvatarUrl = null;
      });
    }
  }

  void _showAvatarOptionsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20.h),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.photo_library,
                  color: Colors.deepPurple,
                  size: 24.r,
                ),
              ),
              title: Text(
                'Upload from Gallery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndSaveCustomAvatar();
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue, size: 24.r),
              ),
              title: Text(
                'Take Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _takePhotoAndSaveAvatar();
              },
            ),
            if (_customAvatarPath != null)
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.refresh, color: Colors.orange, size: 24.r),
                ),
                title: Text(
                  'Reset to Streak Avatar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _resetToStreakAvatar();
                },
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Divider(color: Colors.grey[700], thickness: 1),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  color: Colors.teal,
                  size: 24.r,
                ),
              ),
              title: Text(
                'Edit Username',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _userName,
                style: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditNameDialog();
              },
            ),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSaveCustomAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _saveCustomAvatar(image.path);
      }
    } catch (e) {
      Utilis.showSnackBar('Failed to pick image', isErr: true);
    }
  }

  Future<void> _takePhotoAndSaveAvatar() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null) {
        await _saveCustomAvatar(photo.path);
      }
    } catch (e) {
      Utilis.showSnackBar('Failed to take photo', isErr: true);
    }
  }

  Future<void> _saveCustomAvatar(String imagePath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customAvatarPath = '${directory.path}/custom_avatar.png';
      final currentUid = auth.currentUser!.uid;

      final File sourceFile = File(imagePath);
      await sourceFile.copy(customAvatarPath);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('userAvatars')
          .child('$currentUid.png');

      await storageRef.putFile(File(customAvatarPath));
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('profile')
          .doc('data')
          .update({'customAvatarUrl': downloadUrl, 'img': downloadUrl});

      setState(() {
        _customAvatarPath = customAvatarPath;
      });

      Utilis.showSnackBar('Profile picture updated ✅');
    } catch (e) {
      debugPrint('Error saving custom avatar: $e');
      Utilis.showSnackBar('Failed to save profile picture', isErr: true);
    }
  }

  Future<void> _resetToStreakAvatar() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customAvatarPath = '${directory.path}/custom_avatar.png';
      final customAvatarFile = File(customAvatarPath);
      final currentUid = auth.currentUser!.uid;

      if (customAvatarFile.existsSync()) {
        await customAvatarFile.delete();
      }

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('userAvatars')
            .child('$currentUid.png');
        await storageRef.delete();
      } catch (e) {
        debugPrint('Storage file might not exist: $e');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('profile')
          .doc('data')
          .update({
            'customAvatarUrl': FieldValue.delete(),
            'img': FieldValue.delete(),
          });

      setState(() {
        _customAvatarPath = null;
      });

      await _loadStreakAvatar();

      Utilis.showSnackBar('Reset to streak avatar ✅');
    } catch (e) {
      debugPrint('Error resetting avatar: $e');
      Utilis.showSnackBar('Failed to reset avatar', isErr: true);
    }
  }

  Future<void> _updateUserName(String newName) async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) return;

      final profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('data');

      await profileRef.update({'name': newName});

      setState(() {
        _userName = newName;
      });

      Utilis.showSnackBar('Username updated ✅');
    } catch (e) {
      Utilis.showSnackBar('Failed to update username', isErr: true);
    }
  }

  Future<void> _updateContentBlock(bool isBlocked) async {
    try {
      final uid = auth.currentUser?.uid;
      if (uid == null) return;

      final profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('data');

      await profileRef.update({'contentBlocked': isBlocked});
    } catch (e) {
      print('Failed to update Firestore: $e');
    }
  }

  void _showEditNameDialog() {
    final nameController = TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            'Edit Username',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          content: TextField(
            controller: nameController,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Username',
              labelStyle: TextStyle(color: Colors.grey[300]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.deepPurple, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  Utilis.showSnackBar('Username cannot be empty', isErr: true);
                  return;
                }
                Navigator.pop(context);
                _updateUserName(newName);
              },
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showToggleOffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28.r,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Disable Content Block?',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To disable content blocking, please type:',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.red[900]?.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.red[700]!),
                ),
                child: Text(
                  'I choose to stay in apathy, embrace destructive thoughts, and avoid personal growth',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.red[300],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _confirmationController,
                maxLines: 3,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type the text above...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: Colors.deepPurple),
                  ),
                  contentPadding: EdgeInsets.all(12.r),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _confirmationController.clear();
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () async {
                if (_confirmationController.text.trim() ==
                    'I choose to stay in apathy, embrace destructive thoughts, and avoid personal growth') {
                  final disabled = await _disablePornBlock();

                  if (disabled) {
                    setState(() {
                      _isContentBlocked = false;
                    });
                    await _updateContentBlock(false);

                    _confirmationController.clear();
                    Navigator.of(context).pop();

                    Utilis.showSnackBar('Content blocking disabled');
                  } else {
                    Utilis.showSnackBar(
                      'Failed to disable blocking. Please try again.',
                      isErr: true,
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Text doesn\'t match. Please try again.'),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                }
              },
              child: Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _handleToggleChange(bool value) async {
    if (value) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            Center(child: CupertinoActivityIndicator(color: Colors.white)),
      );

      final allowed = await _requestScreenTimeAuth();

      if (!allowed) {
        if (mounted) Navigator.pop(context);
        Utilis.showSnackBar(
          'Screen Time permission is required. Please grant access in Settings.',
          isErr: true,
        );
        return;
      }

      final enabled = await _enablePornBlock(_blockedDomains);

      if (mounted) Navigator.pop(context);

      if (enabled) {
        setState(() => _isContentBlocked = true);
        await _updateContentBlock(true);
        Utilis.showSnackBar('Content blocking enabled ✅');
      } else {
        Utilis.showSnackBar('Failed to enable content block', isErr: true);
      }
    } else {
      _showToggleOffDialog();
    }
  }

  void _showReportDialog(BuildContext context) {
    final TextEditingController reportController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text(
          'Report Issue',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: reportController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Your Report Message..',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[800],
                contentPadding: EdgeInsets.all(12.r),
              ),
              style: TextStyle(fontSize: 14.sp, color: Colors.white),
            ),
            SizedBox(height: 12.h),
            Text(
              "Sorry for the inconvenience! We'll fix this soon. ThankYou!",
              style: TextStyle(
                fontSize: 11.sp,
                color: const Color(0xFFEF9A9A),
                height: 1.4,
              ),
            ),
            if (_userEmail == null) ...[
              SizedBox(height: 12.h),
              TextField(
                controller: emailController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Your email (optional)',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13.sp,
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF7F1019).withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () async {
              if (reportController.text.trim().isEmpty) {
                Utilis.showSnackBar(
                  'Please enter a report message',
                  isErr: true,
                );
                return;
              }

              context.pop();
              await ReportService.sendReport(reportController.text.trim());

              Utilis.showSnackBar('Report sent successfully');
            },
            child: Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28.r),
              SizedBox(width: 8.w),
              Text(
                'Delete Account?',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: Text(
            'This action cannot be undone. All your data will be permanently deleted.',
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () async {
                try {
                  final uid = auth.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .delete();

                    await auth.currentUser?.delete();

                    if (context.mounted) {
                      Navigator.pop(context);
                      context.go('/');
                    }
                    Utilis.showSnackBar('Account deleted successfully');
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  Utilis.showSnackBar(
                    'Failed to delete account. Please try again.',
                    isErr: true,
                  );
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();
    Uint8List? screenshot;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text(
          'Send Feedback',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
            color: Colors.white,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: feedbackController,
                  maxLines: 3,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Write your feedback...',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14.sp,
                    ),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(
                        color: Colors.deepPurple,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                if (screenshot != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.memory(screenshot!, height: 120.h),
                  ),
                SizedBox(height: 12.h),
                ElevatedButton.icon(
                  onPressed: () async {
                    final boundary =
                        context.findRenderObject() as RenderRepaintBoundary?;
                    if (boundary != null) {
                      final image = await boundary.toImage(pixelRatio: 2.0);
                      final byteData = await image.toByteData(
                        format: ImageByteFormat.png,
                      );
                      if (byteData != null) {
                        setState(() {
                          screenshot = byteData.buffer.asUint8List();
                        });
                      }
                    }
                  },
                  icon: Icon(Icons.camera_alt_outlined, size: 16.r),
                  label: Text(
                    screenshot == null
                        ? 'Attach Screenshot'
                        : 'Change Screenshot',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (feedbackController.text.trim().isEmpty) {
                Utilis.showSnackBar('Please enter feedback', isErr: true);
                return;
              }

              context.pop();
              await FeedbackService.sendFeedback(
                message: feedbackController.text.trim(),
                screenshot: screenshot,
              );

              Utilis.showSnackBar('Feedback sent successfully');
            },
            child: Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget() {
    if (_customAvatarPath != null && File(_customAvatarPath!).existsSync()) {
      return Image.file(File(_customAvatarPath!), fit: BoxFit.cover);
    }

    if (_streakAvatarUrl != null) {
      return Image.network(
        _streakAvatarUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CupertinoActivityIndicator(color: Colors.white38),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildLocalAssetAvatar();
        },
      );
    }

    return _buildLocalAssetAvatar();
  }

  Widget _buildLocalAssetAvatar() {
    final currentStreakDays = StreaksData.currentStreakDays;
    final calculatedLevel = AvatarManager.getLevelFromDays(currentStreakDays);

    return Image.asset(
      'assets/3d/lvl$calculatedLevel.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.person, size: 80.r, color: Colors.grey[400]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CupertinoActivityIndicator(color: Colors.white38)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          iconSize: 20.r,
          icon: Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 140.r,
                  height: 140.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[900],
                    border: Border.all(width: 1.5, color: Colors.white30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.35),
                        blurRadius: 26.r,
                        spreadRadius: 4.r,
                        offset: Offset(0, 8.h),
                      ),
                    ],
                  ),
                  child: ClipOval(child: _buildAvatarWidget()),
                ),
                Positioned(
                  bottom: 0,
                  right: 10.w,
                  child: GestureDetector(
                    onTap: _showAvatarOptionsDialog,
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: .5),
                      ),
                      child: Icon(Icons.edit, color: Colors.white, size: 10.r),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Icon(
                  CupertinoIcons.checkmark_seal,
                  color: Colors.blue,
                  size: 12.r,
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
                child: Text(
                  "Progress Stats",
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _smallStatCard(
                    titleTop: "$_currentStreak",
                    titleBottom: "Streak Days",
                    icon: Icons.local_fire_department,
                    iconColor: Colors.orange,
                    borderColor: Colors.orange,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _smallStatCard(
                    titleTop: "$_progressPercentage%",
                    titleBottom: "Progress",
                    icon: Icons.trending_up_rounded,
                    iconColor: Colors.green,
                    borderColor: Colors.green,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _smallStatCard(
                    titleTop: "$_totalDays",
                    titleBottom: "Total Days",
                    icon: Icons.calendar_month_rounded,
                    iconColor: Colors.blue,
                    borderColor: Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 32.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
                child: Text(
                  "Preferences",
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                children: [
                  _blockContentTile(
                    "Block Restrictive Content",
                    Icons.shield,
                    _isContentBlocked,
                    _handleToggleChange,
                  ),
                  _tile(
                    "Privacy & Terms",
                    Icons.privacy_tip_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LegalScreen()),
                      );
                    },
                  ),

                  _tile(
                    'Posts',
                    Icons.post_add,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserPostsPage()),
                    ),
                  ),
                  _tile(
                    "Feedback",
                    Icons.feedback_outlined,
                    onTap: () async {
                      BetterFeedback.of(context).show((
                        UserFeedback feedback,
                      ) async {
                        await FeedbackService.sendFeedback(
                          message: feedback.text,
                          screenshot: feedback.screenshot,
                        );
                        Utilis.showSnackBar('Feedback sent successfully');
                      });
                    },
                  ),
                  _tile(
                    "Help & Support",
                    Icons.help_outline,
                    onTap: () => _showReportDialog(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),
            ElevatedButton(
              onPressed: () async {
                await auth.signOut();
                context.go('/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                minimumSize: Size(double.infinity, 50.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                "Sign Out",
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: _deleteAccount,
              child: Text(
                "Delete Account",
                style: TextStyle(color: Colors.red[400], fontSize: 14.sp),
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    String title,
    IconData icon, {
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: Container(
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: Colors.deepPurple[300], size: 22.r),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      trailing:
          trailingWidget ??
          Icon(Icons.chevron_right, color: Colors.grey[600], size: 20.r),
      onTap: onTap,
    );
  }

  Widget _smallStatCard({
    required String titleTop,
    required String titleBottom,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.18),
              border: Border.all(color: iconColor.withOpacity(0.7), width: 1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 28.r, color: iconColor),
          ),
          SizedBox(height: 10.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              titleTop,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            titleBottom,
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _blockContentTile(
    String title,
    IconData icon,
    bool value,
    Function(bool) onToggle,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: (value ? Colors.green : Colors.red).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              icon,
              color: value ? Colors.green : Colors.red,
              size: 22.r,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  value ? "Enabled" : "Disabled",
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onToggle,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.deepPurple,
          ),
        ],
      ),
    );
  }
}

class ProfileData {
  static updateFields(int c, int t) {
    DataState.run(() async {
      final uid = auth.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('data')
          .update({'currentStreak': c, 'totalDays': t});
    });
  }
}
