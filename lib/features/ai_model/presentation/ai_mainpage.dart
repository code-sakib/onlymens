import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/ai_model/data_service.dart';
import 'package:onlymens/features/ai_model/model/model.dart';
import 'package:onlymens/panic_mode_pg.dart';
import 'package:onlymens/utilis/parse_datetime.dart';
import 'package:onlymens/utilis/size_config.dart';
import 'package:onlymens/utilis/snackbar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

final List<ChannelItem> _channels = [
  ChannelItem(
    name: 'Chat Mode',
    icon: Image.asset('assets/ai_pg/ai_chat.png', color: Colors.white),
    tobuild: ChatScreen(),
    thisFunc: () => AIModelDataService.fetchAIChats(),
  ),
  ChannelItem(
    name: 'Game Mode',
    icon: HugeIcon(icon: HugeIcons.strokeRoundedAiGame),
    tobuild: GameModeWidget(),
  ),
  ChannelItem(
    name: 'Hard Mode',
    icon: HugeIcon(icon: HugeIcons.strokeRoundedAiChat01),
    tobuild: HardModeWidget(),
  ),
  ChannelItem(
    name: 'Voice Mode',
    icon: HugeIcon(icon: HugeIcons.strokeRoundedAiAudio),
    tobuild: VoiceModeWidget(),
  ),
];

int currentMode = 0;

class AiMainpage extends StatefulWidget {
  const AiMainpage({super.key});

  @override
  State<AiMainpage> createState() => _AiMainpageState();
}

class _AiMainpageState extends State<AiMainpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ✅ Wrap in Builder to get a context under Scaffold
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSidebarLeft,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                _channels[currentMode].name,
                style: Theme.of(context).textTheme.labelMedium,
              ),

              IconButton(
                onPressed: () => context.go('/streaks'),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedFire02,
                  color: Colors.deepOrangeAccent,
                ),
              ),
            ],
          ),
          _channels[currentMode].tobuild,
        ],
      ),
      drawer: Drawer(
        width: SizeConfig.screenWidth / 2,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SideBar(
          changeMode: (int mode) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              setState(() {
                currentMode = mode;
              });
            });
          },
        ),
      ),
    );
  }
}

class SideBar extends StatefulWidget {
  const SideBar({super.key, required this.changeMode});

  final Function(int) changeMode;

  @override
  State<SideBar> createState() => _SideBarState();
}

class _SideBarState extends State<SideBar> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () {}, icon: Icon(CupertinoIcons.app)),
              IconButton(
                onPressed: () {},
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedBubbleChatAdd,
                  color: Colors.white10,
                  size: 20,
                ),
              ),
            ],
          ),

          SizedBox(
            height: SizeConfig.screenHeight / 3.8,
            child: ListView.builder(
              itemBuilder: (context, i) {
                return ListTile(
                  onTap: () {
                    widget.changeMode(i);
                    Scaffold.of(context).closeDrawer();
                  },

                  leading: (_channels[i].icon),
                  title: Text(
                    _channels[i].name,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  tileColor: currentMode == i
                      ? Colors.deepPurple
                      : Colors.transparent,
                );
              },
              itemCount: _channels.length,
            ),
          ),

          divider(),
          messages.isNotEmpty
              ? Builder(
                  builder: (context) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        tileColor: Colors.grey[900],
                        title: !typerAnimationShowed
                            ? AnimatedTextKit(
                                repeatForever: false,
                                totalRepeatCount: 1,
                                animatedTexts: [
                                  TypewriterAnimatedText(
                                    messages.first['text'] ?? '',

                                    speed: const Duration(milliseconds: 100),
                                  ),
                                ],
                              )
                            : Text(messages.first['text'] ?? ''),
                        subtitle: Text(
                          formatDateTime(DateTime.now().toString()),
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 10,
                          ),
                        ),
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),

          !isGuest
              ? FutureBuilder(
                  future: _channels[currentMode].thisFunc?.call(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CupertinoActivityIndicator());
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    } else if (snapshot.hasData) {
                      final dataFetched = snapshot.data as Map;
                      print(dataFetched);
                      Map dataFetchedReversed = Map.fromEntries(
                        dataFetched.entries.toList().reversed,
                      );

                      return SizedBox(
                        height: SizeConfig.screenHeight / 3,
                        child: ListView.builder(
                          itemBuilder: (context, index) {
                            final datetime = formatDateTime(
                              dataFetchedReversed.entries.elementAt(index).key,
                            );
                            final title = dataFetchedReversed.entries
                                .elementAt(index)
                                .value[0];
                            final msgs =
                                dataFetchedReversed.entries
                                    .elementAt(index)
                                    .value[1] ??
                                [];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: ListTile(
                                title: Text(title),

                                subtitle: Text(
                                  datetime,
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 10,
                                  ),
                                ),
                                tileColor: Colors.grey[900],
                              ),
                            );
                          },
                          itemCount: dataFetched.length,
                        ),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  },
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

divider() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12.0),
    child: Divider(thickness: 1, color: Colors.grey),
  );
}

class ChannelItem {
  final String name;
  final Widget icon;
  final String pgText;
  final Widget tobuild;
  Future<void> Function()? thisFunc;
  ChannelItem({
    required this.name,
    required this.icon,
    required this.tobuild,
    this.thisFunc,
    this.pgText = '',
  });
}

enum Sender { user, ai }

class Message {
  final String text;
  final Sender sender;
  final DateTime time;
  Message({required this.text, required this.sender, DateTime? time})
    : time = time ?? DateTime.now();
}

/// ------------------ CHAT MODE (fully implemented) ------------------
List<Map<String, String>> messages = [];
bool typerAnimationShowed = false;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final OpenAIService _openAIService = OpenAIService();
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [];

  bool _isLoading = false;
  bool typerAnimationShowed = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      messages.add({"role": "user", "text": text});
      _isLoading = true;
      typerAnimationShowed = true;
    });

    _controller.clear();

    final reply = await _openAIService.sendMessage(text);

    setState(() {
      messages.add({"role": "ai", "text": reply});
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          messages.isNotEmpty
              ? SizedBox(
                  height: SizeConfig.screenHeight / 1.37,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isUser = msg["role"] == "user";
                      return Align(
                        alignment: isUser
                            ? Alignment.topRight
                            : Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Colors.deepPurple.withValues(alpha: 0.3)
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg["text"] ?? "",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: SizeConfig.screenHeight / 4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAiMagic,
                        size: 100,
                        color: Colors.grey[850],
                      ),
                      const Text(
                        "Hey! I'm your AI assistant. How can I help you today?",
                      ),
                    ],
                  ),
                ),

          ElevatedButton(
            onPressed: () async {
              print('\n========== iOS DIAGNOSTIC ==========');

              // 1. Get fresh token
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                print('❌ No user logged in');
                return;
              }

              final token = await user.getIdToken(true);
              print('User: ${user.email}');
              print('Token: ${token?.substring(0, 50)}...');

              // 2. Initialize Functions with explicit configuration
              final functions = FirebaseFunctions.instanceFor(
                region: 'us-central1',
              );

              try {
                print('Calling testAuth...');
                final callable = functions.httpsCallable('testAuth');
                final result = await callable.call({
                  'platform': 'iOS',
                  'timestamp': DateTime.now().toIso8601String(),
                });

                print('✅ SUCCESS: ${result.data}');
              } catch (e) {
                print('❌ ERROR: $e');
                if (e is FirebaseFunctionsException) {
                  print('Code: ${e.code}');
                  print('Message: ${e.message}');
                  print('Details: ${e.details}');
                }
              }
            },
            child: Text("IOS diagnos"),
          ),
          if (_isLoading)
            const LinearProgressIndicator(
              color: Colors.deepPurple,
              minHeight: 2,
            ),
          chatInput(_controller, _sendMessage, !_isLoading),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// ------------------ CHAT INPUT ------------------

Widget chatInput(
  TextEditingController controller,
  VoidCallback sendMessage, [
  bool isEnabled = true,
]) {
  return Padding(
    padding: const EdgeInsets.all(10.0),
    child: Container(
      height: SizeConfig.blockHeight * 7,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepPurple),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: isEnabled,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.deepPurpleAccent,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          FloatingActionButton(
            shape: const CircleBorder(),
            onPressed: isEnabled ? sendMessage : null,
            backgroundColor: isEnabled ? Colors.deepPurple : Colors.grey,
            child: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

/// ------------------ HARD MODE (placeholder) ------------------
///
List<Map<String, String>> hardModeMessages = [];

class HardModeWidget extends StatefulWidget {
  const HardModeWidget({super.key});

  static final controller = TextEditingController();

  @override
  State<HardModeWidget> createState() => _HardModeWidgetState();
}

class _HardModeWidgetState extends State<HardModeWidget> {
  final TextEditingController _controller = TextEditingController();

  final HardModeAIService _hardModeAIService = HardModeAIService();

  bool _isLoading = false;
  bool typerAnimationShowed = false;

  // User persona data - load this from SharedPreferences or pass from previous screen
  late Map<String, dynamic> userPersona;
  late int currentStreak;
  late int longestStreak;

  Future<void> _loadUserData() async {
    // Load from SharedPreferences or get from widget parameters
    setState(() {
      userPersona = {
        'usage': 'frequent',
        'effects': [
          'Impaired concentration',
          'Reduced creativity',
          'Sleep disturbances',
          'Apathy',
        ],
        'triggers': ['When alone', 'Under stress', 'Boredom', 'Anxiety'],
        'aspects': [
          'Strengthen self-discipline',
          'Develop mental resilience',
          'Cultivate inner peace',
        ],
      };
      currentStreak = 10;
      longestStreak = 15;
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      hardModeMessages.add({"role": "user", "text": text});
      _isLoading = true;
      typerAnimationShowed = true;
    });

    _controller.clear();

    final reply = await _hardModeAIService.sendHardModeMessage(
      userMessage: text,
      userPersona: userPersona,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );

    setState(() {
      hardModeMessages.add({"role": "ai", "text": reply});
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    hardModeMessages.isEmpty
        ? hardModeMessages.add({
            "role": "ai",
            "text":
                "Hey! How are you doing? Just want you to know I'm here for you whenever things get tough.",
          })
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,

      children: [
        hardModeMessages.isNotEmpty
            ? SizedBox(
                height: SizeConfig.screenHeight / 1.37,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: hardModeMessages.length,
                  itemBuilder: (context, index) {
                    final msg = hardModeMessages[index];
                    final isUser = msg["role"] == "user";
                    return Align(
                      alignment: isUser
                          ? Alignment.topRight
                          : Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Colors.deepPurple.withValues(alpha: 0.3)
                              : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: index != hardModeMessages.length - 1 || !isUser
                            ? Text(
                                msg["text"] ?? "",
                                style: const TextStyle(color: Colors.white),
                              )
                            : AnimatedTextKit(
                                repeatForever: false,
                                totalRepeatCount: 1,
                                animatedTexts: [
                                  TypewriterAnimatedText(
                                    msg["text"] ?? "",
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    speed: const Duration(milliseconds: 25),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              )
            : Padding(
                padding: EdgeInsets.symmetric(
                  vertical: SizeConfig.screenHeight / 3.4,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedAiChat01,
                      size: 100,
                      color: Colors.grey[850],
                    ),
                    Text(
                      "Let's brainstorm some hard questions. Ask me anything!",
                    ),
                  ],
                ),
              ),
        if (_isLoading)
          const LinearProgressIndicator(color: Colors.deepPurple, minHeight: 2),
        chatInput(_controller, _sendMessage),
      ],
    );
  }
}

/// ------------------ GAME MODE (placeholder) ------------------
class GameModeWidget extends StatelessWidget {
  const GameModeWidget({super.key});

  static final gameMode = ['bounce-ball', 'snatch-it'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: SizeConfig.screenHeight / 8),
        SizedBox(
          height: SizeConfig.screenHeight / 3,
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              return Card(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.4),
                  ),
                  onPressed: () {
                    index == 0
                        ? context.push('/game1')
                        : context.push('/game2');
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(gameMode[index], textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            },
            itemCount: 2,
          ),
        ),
        Text("Let's see who wins. Choose or anyone starts in "),
        const SizedBox(height: 10),
        ThisCountDown(onEnd: () => context.push('/game1'), secs: 4),
      ],
    );
  }
}

/// ------------------ VOICE MODE (with animated Lottie) ------------------
class VoiceModeWidget extends StatefulWidget {
  const VoiceModeWidget({super.key});

  @override
  State<VoiceModeWidget> createState() => _VoiceModeWidgetState();
}

class _VoiceModeWidgetState extends State<VoiceModeWidget>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  final VoiceModeAIService _voiceAIService = VoiceModeAIService();
  final TextEditingController _textController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _spokenText = '';
  String _aiResponse = '';
  int _remainingPremiumSeconds = 180;
  bool _isPremiumTTS = true;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestMicPermission();
    _checkPremiumStatus();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final status = await _voiceAIService.getPremiumTTSStatus();
      if (mounted) {
        setState(() {
          _remainingPremiumSeconds = status['remainingSeconds'] ?? 0;
          _isPremiumTTS = _remainingPremiumSeconds > 0;
        });
      }
    } catch (e) {
      print('Error checking premium status: $e');
    }
  }

  void _startPulseAnimation() {
    _pulseController.repeat(reverse: true);
  }

  void _stopPulseAnimation() {
    _pulseController.stop();
  }

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isDenied) {
      Utilis.showSnackBar('Microphone permission denied');
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          if (mounted) {
            setState(() => _isListening = false);
            _stopPulseAnimation();
          }
          if (_spokenText.isNotEmpty) {
            _sendToAI();
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          _stopPulseAnimation();
        }
        Utilis.showSnackBar('Error: ${error.errorMsg}');
      },
    );

    if (available) {
      if (mounted) {
        setState(() {
          _isListening = true;
          _spokenText = '';
          _aiResponse = '';
        });
        _startPulseAnimation();
      }

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _spokenText = result.recognizedWords;
            });
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
      _stopPulseAnimation();
    }
    if (_spokenText.isNotEmpty) {
      _sendToAI();
    }
  }

  Future<void> _sendToAI() async {
    if (!mounted) return;

    setState(() => _isProcessing = true);
    _startPulseAnimation();

    try {
      final reply = await _voiceAIService.sendVoiceMessage(_spokenText);

      if (!mounted) return;

      setState(() {
        _aiResponse = reply;
        _isProcessing = false;
      });

      // Auto-selects between OpenAI TTS (premium) and Flutter TTS (free)
      await _voiceAIService.speakWithAI(
        reply,
        onStart: () {
          if (mounted) {
            setState(() => _isSpeaking = true);
          }
        },
        onComplete: () {
          if (mounted) {
            setState(() => _isSpeaking = false);
            _stopPulseAnimation();
            _checkPremiumStatus(); // Update remaining time
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _stopPulseAnimation();
      }
      Utilis.showSnackBar('Error: $e');
    }
  }

  Future<void> _sendTextMessage() async {
    if (_textController.text.trim().isEmpty) return;
    if (!mounted) return;

    setState(() {
      _spokenText = _textController.text.trim();
      _isProcessing = true;
      _aiResponse = '';
    });
    _startPulseAnimation();

    _textController.clear();
    FocusScope.of(context).unfocus();

    try {
      final reply = await _voiceAIService.sendVoiceMessage(_spokenText);

      if (!mounted) return;

      setState(() {
        _aiResponse = reply;
        _isProcessing = false;
      });

      await _voiceAIService.speakWithAI(
        reply,
        onStart: () {
          if (mounted) {
            setState(() => _isSpeaking = true);
          }
        },
        onComplete: () {
          if (mounted) {
            setState(() => _isSpeaking = false);
            _stopPulseAnimation();
            _checkPremiumStatus();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _stopPulseAnimation();
      }
      Utilis.showSnackBar('Error: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.cancel().catchError((_) => false);
    _speech.stop().catchError((_) => false);
    _voiceAIService.stopSpeaking().catchError((_) {});
    _voiceAIService.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: SizeConfig.paddingLarge),
        child: Column(
          children: [
            // Premium Status Badge
            if (_remainingPremiumSeconds > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Premium Voice: ${(_remainingPremiumSeconds / 60).floor()}m ${_remainingPremiumSeconds % 60}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_up,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Standard Voice',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: SizeConfig.blockHeight * 2),

            // Animated Lottie with Gradient Background
            ScaleTransition(
              scale: _pulseAnimation,
              child: Lottie.network(
                'https://lottie.host/b72fd15d-61a4-4510-ae8f-93936c32c857/xzLgoD2MQj.json',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),

            SizedBox(height: SizeConfig.blockHeight * 20),

            // Microphone Button
            GestureDetector(
              onTap: _isProcessing || _isSpeaking
                  ? null
                  : (_isListening ? _stopListening : _startListening),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isListening
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : _isProcessing || _isSpeaking
                        ? [Colors.orange.shade400, Colors.orange.shade600]
                        : [
                            Colors.deepPurple.shade400,
                            Colors.deepPurple.shade600,
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : Colors.deepPurple)
                          .withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: _isListening ? 8 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: _isListening
                      ? voiceHugeIcons(HugeIcons.strokeRoundedMic01)
                      : _isProcessing || _isSpeaking
                      ? voiceHugeIcons(HugeIcons.strokeRoundedHourglass)
                      : voiceHugeIcons(HugeIcons.strokeRoundedMic01),
                ),
              ),
            ),

            SizedBox(height: SizeConfig.blockHeight * 2),

            // Status Text with Voice Type Indicator
            Text(
              _isListening
                  ? 'Listening...'
                  : _isSpeaking
                  ? (_isPremiumTTS
                        ? 'Speaking (Premium)...'
                        : 'Speaking (Standard)...')
                  : _isProcessing
                  ? 'Processing...'
                  : '',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),

            SizedBox(height: SizeConfig.blockHeight * 1),

            // Helper text when premium expires
            if (!_isPremiumTTS && (_isSpeaking || _isProcessing))
              Text(
                'Using standard voice quality',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
          ],
        ),
      ),
    );
  }

  voiceHugeIcons(icon) {
    return HugeIcon(icon: icon, size: 30, color: Colors.white12);
  }
}
