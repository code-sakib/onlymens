import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:onlymens/features/ai_model/convo_history.dart';
import 'package:onlymens/features/ai_model/model/model.dart';
import 'package:onlymens/utilis/snackbar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final List<ChannelItem> _channels = [
  ChannelItem(
    name: 'Chat Mode',
    icon: HugeIcon(icon: HugeIcons.strokeRoundedAiMagic, size: 20.r),
    tobuild: ChatScreen(),
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
  String? _activeChatSessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
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
          currentMode == 0
              ? ChatScreen(
                  key: ValueKey(_activeChatSessionId ?? 'new_chat'),
                  sessionId: _activeChatSessionId,
                )
              : _channels[currentMode].tobuild,
        ],
      ),
      drawer: Drawer(
        width: 0.5.sw,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: SideBar(
          changeMode: (int mode, String? sessionId) {
            setState(() {
              currentMode = mode;
              if (mode == 0) {
                _activeChatSessionId = sessionId;
              }
            });
          },
        ),
      ),
    );
  }
}

class SideBar extends StatefulWidget {
  const SideBar({super.key, required this.changeMode});

  final Function(int, String?) changeMode;

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
              IconButton(
                tooltip: 'New Session',
                onPressed: () {
                  widget.changeMode(currentMode, null);
                  Scaffold.of(context).closeDrawer();
                },
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedBubbleChatAdd,
                  color: Colors.white,
                  size: 20.r,
                ),
              ),
              IconButton(
                tooltip: 'Report Issue',
                onPressed: () {
                  context.pop();
                  _showReportDialog(context);
                },
                icon: Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: Colors.white70,
                  size: 18.r,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 0.125.sh,
            child: ListView.builder(
              itemBuilder: (context, i) {
                return ListTile(
                  onTap: () {
                    widget.changeMode(i, null);
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
          SizedBox(
            height: 500.h,
            child: ConversationHistoryWidget(
              onConversationTap: (sessionId) {
                print('Opening conversation: $sessionId');
                widget.changeMode(0, sessionId);
                Scaffold.of(context).closeDrawer();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final TextEditingController reportController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Report Issue',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
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
                fillColor: Colors.grey[900],
                contentPadding: EdgeInsets.all(12.r),
              ),
              style: TextStyle(fontSize: 14.sp),
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
}

divider() {
  return Padding(
    padding: EdgeInsets.all(12.r),
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

class ChatScreen extends StatefulWidget {
  final String? sessionId;

  const ChatScreen({super.key, this.sessionId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AIModelDataService _aiService = AIModelDataService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  List<MessageModel> _messages = [];
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    print('ChatScreen initState - sessionId: ${widget.sessionId}');
    _currentSessionId = widget.sessionId;

    if (widget.sessionId != null) {
      _loadConversation();
    } else {
      _aiService.startNewConversation();
      _messages = [];
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      print('Session changed: ${oldWidget.sessionId} -> ${widget.sessionId}');
      _currentSessionId = widget.sessionId;

      if (widget.sessionId != null) {
        _loadConversation();
      } else {
        setState(() {
          _messages = [];
        });
        _aiService.startNewConversation();
      }
    }
  }

  Future<void> _loadConversation() async {
    print('Loading conversation: ${widget.sessionId}');
    try {
      final conversation = await _aiService.fetchConversation(
        widget.sessionId!,
      );
      if (conversation != null && mounted) {
        setState(() {
          _messages = conversation.messages;
        });
        _scrollToBottom();
        print('Loaded ${_messages.length} messages');
      }
    } catch (e) {
      print('Error loading conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load conversation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(MessageModel(role: 'user', text: message));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final recentMessages = _messages.length > 1
          ? _messages.sublist(
              _messages.length > 6 ? _messages.length - 6 : 0,
              _messages.length - 1,
            )
          : <MessageModel>[];

      print('Sending with ${recentMessages.length} context messages');

      final response = await _aiService.sendMessage(
        message,
        sessionId: _currentSessionId,
        recentMessages: recentMessages,
      );

      if (_currentSessionId == null) {
        _currentSessionId = _aiService.currentSessionId;
        print('New session created: $_currentSessionId');
      }

      if (mounted) {
        setState(() {
          _messages.add(MessageModel(role: 'ai', text: response));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        setState(() {
          _messages.add(
            MessageModel(
              role: 'ai',
              text: 'Sorry, something went wrong. Please try again.',
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 0.8.sh,
      child: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAiMagic,
                          size: 100.r,
                          color: Colors.grey[850],
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          "Hey! I'm your AI assistant.",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16.sp,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          "How can I help you today?",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16.r),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message.isUser;

                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(
                            bottom: 12.h,
                            left: isUser ? 64.w : 0,
                            right: isUser ? 0 : 64.w,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Colors.deepPurple.withOpacity(0.3)
                                : Colors.grey[800],
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8.r),
              child: Row(
                children: [
                  SizedBox(width: 16.w),
                  CupertinoActivityIndicator(),
                  SizedBox(width: 12.w),
                  Text(
                    'Thinking...',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14.sp),
                  ),
                ],
              ),
            ),
          chatInput(_messageController, _sendMessage),
        ],
      ),
    );
  }
}

Widget chatInput(
  TextEditingController controller,
  VoidCallback sendMessage, [
  bool isEnabled = true,
  VoidCallback? onChanged,
]) {
  return Padding(
    padding: EdgeInsets.all(10.r),
    child: Container(
      height: 56.h,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepPurple),
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: isEnabled,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: Colors.white, fontSize: 15.sp),
              cursorColor: Colors.deepPurpleAccent,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15.sp),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
              ),
            ),
          ),
          FloatingActionButton(
            shape: const CircleBorder(),
            onPressed: isEnabled ? sendMessage : null,
            backgroundColor: isEnabled ? Colors.deepPurple : Colors.grey,
            child: Icon(Icons.send_rounded, color: Colors.white, size: 20.r),
          ),
        ],
      ),
    ),
  );
}

class GameModeWidget extends StatelessWidget {
  const GameModeWidget({super.key});

  static final gameMode = ['bounce-ball', 'snatch-it'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 0.125.sh),
        SizedBox(
          height: 0.33.sh,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
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
        SizedBox(height: 10.h),
      ],
    );
  }
}

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
  String _aiResponseText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestMicPermission();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startPulseAnimation() {
    _pulseController.repeat(reverse: true);
  }

  void _stopPulseAnimation() {
    _pulseController.stop();
    _pulseController.reset();
  }

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isDenied) {
      Utilis.showSnackBar('Microphone permission denied');
    }
  }

  Future<void> _startListening() async {
    await _voiceAIService.stopSpeaking();

    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
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
        print('Speech error: ${error.errorMsg}');
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
          _aiResponseText = '';
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

    setState(() {
      _isProcessing = true;
      _isSpeaking = false;
    });
    _startPulseAnimation();

    try {
      final reply = await _voiceAIService.sendVoiceMessage(_spokenText);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      await _voiceAIService.speakWithAI(
        reply,
        onStart: () {
          if (mounted) {
            setState(() {
              _isSpeaking = true;
              _isProcessing = false;
            });
            _startPulseAnimation();
          }
        },
        onComplete: () {
          if (mounted) {
            setState(() {
              _isSpeaking = false;
            });
            _stopPulseAnimation();

            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _aiResponseText = '';
                });
              }
            });
          }
        },
        onTextUpdate: (text) {
          if (mounted) {
            setState(() {
              _aiResponseText = text;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSpeaking = false;
        });
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
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Column(
          children: [
            SizedBox(height: 0.02.sh),
            ScaleTransition(
              scale: _pulseAnimation,
              child: Lottie.network(
                'https://lottie.host/b72fd15d-61a4-4510-ae8f-93936c32c857/xzLgoD2MQj.json',
                width: 200.w,
                height: 200.h,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 0.03.sh),
            SizedBox(height: 0.23.sh),
            GestureDetector(
              onTap: _isProcessing || _isSpeaking
                  ? null
                  : (_isListening ? _stopListening : _startListening),
              child: Container(
                width: 70.r,
                height: 70.r,
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
                      color:
                          (_isListening
                                  ? Colors.red
                                  : _isProcessing || _isSpeaking
                                  ? Colors.orange
                                  : Colors.deepPurple)
                              .withOpacity(0.3),
                      blurRadius: 20.r,
                      spreadRadius: _isListening ? 8.r : 0,
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
            SizedBox(height: 0.02.sh),
            Text(
              _isListening
                  ? 'Listening...'
                  : _isSpeaking
                  ? 'Speaking...'
                  : _isProcessing
                  ? 'Processing...'
                  : '',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 0.01.sh),
          ],
        ),
      ),
    );
  }

  voiceHugeIcons(icon) {
    return HugeIcon(icon: icon, size: 30.r, color: Colors.white);
  }
}