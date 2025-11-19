import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:onlymens/utilis/snackbar.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:async';

class RainScreen extends StatefulWidget {
  const RainScreen({super.key});

  @override
  State<RainScreen> createState() => _RainScreenState();
}

class _RainScreenState extends State<RainScreen> {
  late AudioPlayer _audioPlayer;
  late ScrollController _scrollController;
  int _currentIndex = 0;
  bool _hasInternet = true;
  bool _isCheckingInternet = true;
  String _currentText = 'Ambient Sounds';
  bool _isLoadingText = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final List<VideoItem> _videos = [
    VideoItem(
      title: 'Rain',
      icon: Icons.water_drop,
      videoUrl: 'assets/relax/rain/rain.mp4',
      audioUrl: 'assets/relax/rain/rain.mp3',
      color: Colors.blue,
      isAsset: true,
      firestoreCollection: 'rain',
    ),
    VideoItem(
      title: 'Calm',
      icon: CupertinoIcons.snow,
      videoUrl: 'assets/relax/medi/medi.mp4',
      audioUrl: 'assets/relax/medi/medi.mp3',
      color: const Color(0xFFB8E6F5), // Soft icy blue
      isAsset: true,
      firestoreCollection: 'calm',
    ),
    VideoItem(
      title: 'Forest',
      icon: Icons.terrain,
      videoUrl: '',
      audioUrl: '',
      color: Colors.green,
      isAsset: false,
      storagePath: 'relax/forest.mp4',
      audioStoragePath: 'relax/forest.mp3',
      firestoreCollection: 'forest',
    ),
    VideoItem(
      title: 'Fire',
      icon: Icons.local_fire_department,
      videoUrl: '',
      audioUrl: '',
      color: Colors.orange,
      isAsset: false,
      storagePath: 'relax/fire.mp4',
      audioStoragePath: 'relax/fire.mp3',
      firestoreCollection: 'fire',
    ),
  ];

  late List<VideoPlayerController?> _controllers;
  final Map<int, bool> _isInitializing = {};
  final Map<int, bool> _initializationFailed = {};

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _scrollController = ScrollController();
    _controllers = List.generate(_videos.length, (_) => null);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // START ASSET VIDEO IMMEDIATELY - Don't wait for anything
    unawaited(_initializeVideo(0));

    // Run everything else in parallel
    unawaited(_setupConnectivityListener());
    unawaited(_checkInternetAndPreload());
    unawaited(_fetchAmbientText(0));
  }

  Future<void> _setupConnectivityListener() async {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (mounted && _hasInternet != hasInternet) {
        setState(() {
          _hasInternet = hasInternet;
        });
        if (hasInternet) {
          _retryFailedInitializations();
        }
      }
    });
  }

  Future<void> _checkInternetAndPreload() async {
    // Check internet in background
    try {
      final results = await Connectivity().checkConnectivity();
      _hasInternet = !results.contains(ConnectivityResult.none);

      if (_hasInternet) {
        try {
          await FirebaseFirestore.instance
              .collection('relax')
              .doc('rain')
              .get()
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          _hasInternet = false;
        }
      }
    } catch (e) {
      debugPrint('Error checking internet: $e');
      _hasInternet = false;
    }

    if (mounted) {
      setState(() {
        _isCheckingInternet = false;
      });
    }

    // Preload network videos if we have internet
    if (_hasInternet) {
      // Small delay to let asset video start first, but much shorter
      await Future.delayed(const Duration(milliseconds: 500));
      _preloadNetworkVideos();
    }
  }

  void _retryFailedInitializations() {
    for (int i = 0; i < _videos.length; i++) {
      if (_initializationFailed[i] == true && !_videos[i].isAsset) {
        _initializationFailed[i] = false;
        _initializeVideoInBackground(i);
      }
    }
  }

  void _preloadNetworkVideos() {
    // Preload all network videos in parallel
    for (int i = 1; i < _videos.length; i++) {
      if (!_videos[i].isAsset && _controllers[i] == null) {
        unawaited(_initializeVideoInBackground(i));
      }
    }
  }

  Future<void> _initializeVideoInBackground(int index) async {
    if (_isInitializing[index] == true ||
        _initializationFailed[index] == true) {
      return;
    }

    _isInitializing[index] = true;

    try {
      final video = _videos[index];
      if (!video.isAsset && _hasInternet) {
        // Fetch URLs in parallel
        final results = await Future.wait([
          _fetchFirestoreUrl(video.storagePath!),
          _fetchFirestoreUrl(video.audioStoragePath!),
        ]);

        final videoUrl = results[0];
        final audioUrl = results[1];

        if (videoUrl != null && audioUrl != null && mounted) {
          video.videoUrl = videoUrl;
          video.audioUrl = audioUrl;

          final controller = VideoPlayerController.networkUrl(
            Uri.parse(videoUrl),
          );
          await controller.initialize();
          controller.setLooping(true);
          controller.setVolume(0);

          if (mounted) {
            _controllers[index] = controller;
            setState(() {});
          }
        } else {
          _initializationFailed[index] = true;
        }
      }
    } catch (e) {
      debugPrint('Error preloading video $index: $e');
      _initializationFailed[index] = true;
    } finally {
      _isInitializing[index] = false;
    }
  }

  Future<void> _fetchAmbientText(int index) async {
    if (!_hasInternet) {
      if (mounted) {
        setState(() {
          _currentText = 'Ambient Sounds';
          _isLoadingText = false;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoadingText = true;
        });
      }

      final collection = _videos[index].firestoreCollection;
      final docSnapshot = await FirebaseFirestore.instance
          .collection('relax')
          .doc(collection)
          .get()
          .timeout(const Duration(seconds: 5));

      if (docSnapshot.exists && mounted) {
        final data = docSnapshot.data();
        final text = data?['today'] ?? data?['text'] ?? 'Ambient Sounds';
        setState(() {
          _currentText = text;
          _isLoadingText = false;
        });
      } else if (mounted) {
        setState(() {
          _currentText = 'Ambient Sounds';
          _isLoadingText = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching ambient text: $e');
      if (mounted) {
        setState(() {
          _currentText = 'Ambient Sounds';
          _isLoadingText = false;
        });
      }
    }
  }

  Future<String?> _fetchFirestoreUrl(String storagePath) async {
    try {
      if (!_hasInternet) return null;

      final url = await FirebaseStorage.instance
          .ref(storagePath)
          .getDownloadURL()
          .timeout(const Duration(seconds: 10));

      return url;
    } catch (e) {
      debugPrint('Error fetching URL from $storagePath: $e');
      return null;
    }
  }

  Future<void> _initializeVideo(int index) async {
    if (_isInitializing[index] == true) {
      while (_isInitializing[index] == true) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_controllers[index]?.value.isInitialized == true) {
        await _controllers[index]!.play();
        await _playAudio(index);
      }
      return;
    }

    _isInitializing[index] = true;

    try {
      final video = _videos[index];

      if (_controllers[index] != null &&
          _controllers[index]!.value.isInitialized) {
        await _controllers[index]!.play();
        await _playAudio(index);
        _isInitializing[index] = false;
        return;
      }

      VideoPlayerController controller;

      if (video.isAsset) {
        // Asset video - fast path, no network needed
        controller = VideoPlayerController.asset(video.videoUrl);
        _controllers[index] = controller;
        if (mounted) setState(() {});

        await controller.initialize();
        controller.setLooping(true);
        controller.setVolume(0);
        await controller.play();
        await _playAudio(index);

        if (mounted) setState(() {});
      } else {
        // Network video
        if (!_hasInternet) {
          _isInitializing[index] = false;
          _initializationFailed[index] = true;
          _showNoInternetError();
          return;
        }

        if (_controllers[index] != null &&
            _controllers[index]!.value.isInitialized) {
          await _controllers[index]!.play();
          await _playAudio(index);
          _isInitializing[index] = false;
          if (mounted) setState(() {});
          return;
        }

        // Fetch URLs in parallel
        final results = await Future.wait([
          _fetchFirestoreUrl(video.storagePath!),
          _fetchFirestoreUrl(video.audioStoragePath!),
        ]);

        final videoUrl = results[0];
        final audioUrl = results[1];

        if (videoUrl == null || audioUrl == null) {
          _isInitializing[index] = false;
          _initializationFailed[index] = true;
          if (mounted) {
            Utilis.showSnackBar(
              'Failed to load ${video.title}. Check your connection.',
              isErr: true,
            );
            _returnToRain();
          }
          return;
        }

        video.videoUrl = videoUrl;
        video.audioUrl = audioUrl;

        controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        _controllers[index] = controller;
        if (mounted) setState(() {});

        await controller.initialize();
        controller.setLooping(true);
        controller.setVolume(0);
        await controller.play();
        await _playAudio(index);

        if (mounted) setState(() {});
        _initializationFailed[index] = false;
      }
    } catch (e) {
      debugPrint('Error initializing video $index: $e');
      _initializationFailed[index] = true;
      if (mounted && !_videos[index].isAsset) {
        Utilis.showSnackBar(
          'Error loading ${_videos[index].title}',
          isErr: true,
        );
        _returnToRain();
      }
    } finally {
      _isInitializing[index] = false;
    }
  }

  Future<void> _playAudio(int index) async {
    try {
      await _audioPlayer.stop();

      if (_videos[index].isAsset) {
        await _audioPlayer.setAsset(_videos[index].audioUrl);
      } else {
        if (_videos[index].audioUrl.isEmpty) return;
        await _audioPlayer.setUrl(_videos[index].audioUrl);
      }

      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  void _showNoInternetError() {
    if (mounted) {
      Utilis.showSnackBar(
        'No internet connection. Please check and try again.',
        isErr: true,
      );
      if (_currentIndex != 0) {
        _returnToRain();
      }
    }
  }

  void _returnToRain() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _currentIndex != 0) {
        _switchVideo(0);
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _switchVideo(int newIndex) async {
    if (newIndex == _currentIndex) return;

    if (!_videos[newIndex].isAsset && !_hasInternet) {
      _showNoInternetError();
      return;
    }

    if (_controllers[_currentIndex] != null) {
      await _controllers[_currentIndex]!.pause();
    }
    await _audioPlayer.pause();

    if (mounted) {
      setState(() {
        _currentIndex = newIndex;
      });
    }

    unawaited(_fetchAmbientText(newIndex));
    await _initializeVideo(newIndex);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _audioPlayer.dispose();
    _scrollController.dispose();
    for (var controller in _controllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemWidth = 70.w;
    final centerPadding = (1.sw - itemWidth) / 2;
    final isVideoReady =
        _controllers[_currentIndex] != null &&
        _controllers[_currentIndex]!.value.isInitialized;

    return Scaffold(
      body: Stack(
        children: [
          // Background Video
          Positioned.fill(
            child: isVideoReady
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controllers[_currentIndex]!.value.size.width,
                      height: _controllers[_currentIndex]!.value.size.height,
                      child: VideoPlayer(_controllers[_currentIndex]!),
                    ),
                  )
                : Container(
                    color: _videos[_currentIndex].color.withOpacity(0.3),
                    child: Center(
                      child: CupertinoActivityIndicator(
                        radius: 12.r,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),

          // Dark Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),

          // Cupertino Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8.h,
            left: 8.w,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(CupertinoIcons.back, color: Colors.white, size: 28.r),
            ),
          ),

          // Animated Firestore Text
          Positioned(
            bottom: 155.h,
            left: 24.w,
            right: 24.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoadingText)
                  const SizedBox.shrink()
                else
                  Flexible(
                    child: AnimatedTextKit(
                      key: ValueKey(_currentText),
                      animatedTexts: [
                        TyperAnimatedText(
                          _currentText,
                          textAlign: TextAlign.center,
                          textStyle: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            height: 1.3,
                          ),
                          speed: const Duration(milliseconds: 50),
                        ),
                      ],
                      totalRepeatCount: 1,
                      displayFullTextOnTap: true,
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Horizontal List
          Positioned(
            bottom: 50.h,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 90.h,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(left: centerPadding, right: 16.w),
                physics: const BouncingScrollPhysics(),
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentIndex;
                  final video = _videos[index];
                  final isAvailable = video.isAsset || _hasInternet;
                  final hasFailed = _initializationFailed[index] == true;

                  return GestureDetector(
                    onTap: () {
                      if (!isAvailable) {
                        _showNoInternetError();
                        return;
                      }
                      if (hasFailed && !video.isAsset) {
                        _initializationFailed[index] = false;
                      }
                      _switchVideo(index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: itemWidth,
                      margin: EdgeInsets.only(right: 12.w),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : isAvailable
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: isSelected
                              ? video.color
                              : Colors.white.withOpacity(0.1),
                          width: isSelected ? 2.5.w : 1.w,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: video.color.withOpacity(0.5),
                                  blurRadius: 16.r,
                                  spreadRadius: 1.r,
                                ),
                              ]
                            : [],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            video.icon,
                            size: isSelected ? 32.r : 28.r,
                            color: isSelected
                                ? video.color
                                : isAvailable
                                ? Colors.white.withOpacity(0.8)
                                : Colors.white.withOpacity(0.3),
                          ),
                          if (!isAvailable || hasFailed)
                            Positioned(
                              top: 6.h,
                              right: 6.w,
                              child: Container(
                                padding: EdgeInsets.all(2.r),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  hasFailed ? Icons.refresh : Icons.cloud_off,
                                  size: 12.r,
                                  color: hasFailed
                                      ? Colors.orange.shade300
                                      : Colors.red.shade300,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function for unawaited futures
void unawaited(Future<void> future) {}

class VideoItem {
  final String title;
  final IconData icon;
  String videoUrl;
  String audioUrl;
  final Color color;
  final bool isAsset;
  final String? storagePath;
  final String? audioStoragePath;
  final String firestoreCollection;

  VideoItem({
    required this.title,
    required this.icon,
    required this.videoUrl,
    required this.audioUrl,
    required this.color,
    required this.isAsset,
    required this.firestoreCollection,
    this.storagePath,
    this.audioStoragePath,
  });
}
