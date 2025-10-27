import 'package:flutter/material.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

class RainScreen extends StatefulWidget {
  const RainScreen({super.key});

  @override
  State<RainScreen> createState() => _RainScreenState();
}

class _RainScreenState extends State<RainScreen> {
  late AudioPlayer _audioPlayer;
  late PageController _pageController;
  int _currentIndex = 0;

  final List<VideoItem> _videos = [
    VideoItem(
      title: 'Rain',
      icon: Icons.water_drop,
      videoUrl: 'assets/relax/rain/rain.mp4',
      audioUrl: 'assets/relax/rain/rain.mp3',
      color: Colors.blue,
    ),
    VideoItem(
      title: 'Fire',
      icon: Icons.local_fire_department,
      videoUrl: 'assets/relax/fire/fire.mp4',
      audioUrl: 'assets/relax/rain/rain.mp3',
      color: Colors.orange,
    ),
    // VideoItem(
    //   title: 'Wind',
    //   icon: Icons.air,
    //   videoUrl: 'assets/relax/rain/rain.mp4',
    //   color: Colors.cyan,
    // ),
    // VideoItem(
    //   title: 'Earth',
    //   icon: Icons.terrain,
    //   videoUrl: 'assets/relax/rain/rain.mp4',
    //   color: Colors.green,
    // ),
  ];

  late List<VideoPlayerController?> _controllers;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.35);
    _controllers = List.generate(_videos.length, (_) => null);
    _initializeVideo(0);
  }

  void _initializeVideo(int index) {
    // Dispose previous controller if exists
    if (_controllers[_currentIndex] != null) {
      _controllers[_currentIndex]!.pause();
    }

    // Initialize new video if not already initialized
    if (_controllers[index] == null) {
      // For network videos use: VideoPlayerController.network(url)
      // For assets use: VideoPlayerController.asset(url)
      _controllers[index] = VideoPlayerController.asset(_videos[index].videoUrl)
        ..initialize().then((_) {
          setState(() {});
          _controllers[index]!.play();
          _controllers[index]!.setLooping(true);
          _audioPlayer.setAsset(_videos[index].audioUrl);
          _audioPlayer.setLoopMode(LoopMode.one);
          _audioPlayer.play();
        });

      _audioPlayer = AudioPlayer();
    } else {
      _controllers[index]!.play();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioPlayer.dispose();
    for (var controller in _controllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _initializeVideo(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _controllers[_currentIndex] != null &&
              _controllers[_currentIndex]!.value.isInitialized
          ? Stack(
              children: [
                SizedBox(
                  height: SizeConfig.screenHeight,
                  child: VideoPlayer(_controllers[_currentIndex]!),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: SizeConfig.blockHeight * 10,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _videos.length,
                      itemBuilder: (context, index) {
                        bool isSelected = index == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 16,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Transform.scale(
                              scale: isSelected ? 1.0 : 0.85,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                  border: Border.all(
                                    color: isSelected
                                        ? _videos[index].color
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: _videos[index].color
                                                .withValues(alpha: 0.5),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Icon(
                                  _videos[index].icon,
                                  size: 40,
                                  color: isSelected
                                      ? _videos[index].color
                                      : Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class VideoSliderScreen extends StatefulWidget {
  const VideoSliderScreen({super.key});

  @override
  State<VideoSliderScreen> createState() => _VideoSliderScreenState();
}

class _VideoSliderScreenState extends State<VideoSliderScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  final List<VideoItem> _videos = [
    VideoItem(
      title: 'Rain',
      icon: Icons.water_drop,
      videoUrl: 'assets/relax/rain/rain.mp4',
      audioUrl: 'assets/relax/rain/rain.mp3',
      color: Colors.blue,
    ),
    VideoItem(
      title: 'Fire',
      icon: Icons.local_fire_department,
      videoUrl: 'assets/relax/rain/rain.mp4',
      audioUrl: 'assets/relax/fire/fire.mp3',
      color: Colors.orange,
    ),
    // VideoItem(
    //   title: 'Wind',
    //   icon: Icons.air,
    //   videoUrl: 'assets/relax/rain/rain.mp4',
    //   color: Colors.cyan,
    // ),
    // VideoItem(
    //   title: 'Earth',
    //   icon: Icons.terrain,
    //   videoUrl: 'assets/relax/rain/rain.mp4',
    //   color: Colors.green,
    // ),
  ];

  late List<VideoPlayerController?> _controllers;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.35);
    _controllers = List.generate(_videos.length, (_) => null);
    _initializeVideo(0);
  }

  void _initializeVideo(int index) {
    // Dispose previous controller if exists
    if (_controllers[_currentIndex] != null) {
      _controllers[_currentIndex]!.pause();
    }

    // Initialize new video if not already initialized
    if (_controllers[index] == null) {
      // For network videos use: VideoPlayerController.network(url)
      // For assets use: VideoPlayerController.asset(url)
      _controllers[index] = VideoPlayerController.asset(_videos[index].videoUrl)
        ..initialize().then((_) {
          setState(() {});
          _controllers[index]!.play();
          _controllers[index]!.setLooping(true);
        });
    } else {
      _controllers[index]!.play();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _initializeVideo(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Video
          Positioned.fill(
            child:
                _controllers[_currentIndex] != null &&
                    _controllers[_currentIndex]!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controllers[_currentIndex]!.value.size.width,
                      height: _controllers[_currentIndex]!.value.size.height,
                      child: VideoPlayer(_controllers[_currentIndex]!),
                    ),
                  )
                : Container(
                    color: _videos[_currentIndex].color.withValues(alpha: 0.3),
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
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),

          // Bottom List Slider
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Weather Text
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Weather',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _videos[_currentIndex].title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Horizontal List
                SizedBox(
                  height: 140,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _videos.length,
                    itemBuilder: (context, index) {
                      bool isSelected = index == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Transform.scale(
                            scale: isSelected ? 1.0 : 0.85,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? _videos[index].color
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: _videos[index].color
                                              .withValues(alpha: 0.5),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _videos[index].icon,
                                    size: 40,
                                    color: isSelected
                                        ? _videos[index].color
                                        : Colors.white.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _videos[index].title,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.black87
                                          : Colors.white.withValues(alpha: 0.6),
                                      fontSize: 16,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoItem {
  final String title;
  final IconData icon;
  final String videoUrl;
  final String audioUrl;
  final Color color;

  VideoItem({
    required this.title,
    required this.icon,
    required this.videoUrl,
    required this.audioUrl,
    required this.color,
  });
}
