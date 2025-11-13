import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:onlymens/core/globals.dart';
import 'package:onlymens/features/streaks_page/data/streaks_data.dart';
import 'package:path_provider/path_provider.dart';

class AIModelDataService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  // Track current active session
  String? currentSessionId;

  // ============================================
  // 1. SEND MESSAGE (Enhanced with context)
  // ============================================
  Future<String> sendMessage(
    String userMessage, {
    String? sessionId,
    List<MessageModel>? recentMessages, // ✅ NEW: Pass recent messages
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      return 'Please log in to use the chat feature.';
    }

    // Use provided session or current session or create new
    final activeSession = sessionId ?? currentSessionId;
    final currentStreak = glbCurrentStreakDays;
    final longestStreak = glbTotalDoneDays;

    print('$currentStreak $longestStreak');

    // ✅ Detect if this is a deep question
    final isDeep = _isDeepQuestion(userMessage);

    // ✅ Prepare conversation history (last 5 messages only)
    final conversationHistory = _prepareConversationHistory(recentMessages);

    try {
      await user.getIdToken(true); // Force refresh token

      final callable = _functions.httpsCallable('sendChatMessage');
      final result = await callable.call({
        'message': userMessage.trim(),
        'sessionId': activeSession,
        'title': activeSession == null
            ? userMessage.substring(
                0,
                userMessage.length > 30 ? 30 : userMessage.length,
              )
            : null,
        // ✅ Pass streak data to Cloud Function
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        // ✅ NEW: Pass conversation context
        'isDeep': isDeep,
        'conversationHistory': conversationHistory,
      });

      final data = result.data as Map<String, dynamic>;

      // Store the sessionId returned by Cloud Function
      if (data.containsKey('sessionId')) {
        currentSessionId = data['sessionId'] as String;
      } else if (activeSession != null) {
        currentSessionId = activeSession;
      }

      return data['reply'] as String;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return e.message ?? 'Rate limit reached. Please try again later.';
      } else if (e.code == 'unauthenticated') {
        return 'Session expired. Please log in again.';
      } else if (e.code == 'invalid-argument') {
        return e.message ?? 'Invalid message. Please try again.';
      } else {
        print('Firebase Function Error: ${e.code} - ${e.message}');
        return 'Something went wrong. Please try again.';
      }
    } catch (e) {
      print('Unexpected Error: $e');
      return 'Connection failed. Check your internet and try again.';
    }
  }

  // ============================================
  // HELPER: Detect Deep Questions
  // ============================================
  bool _isDeepQuestion(String message) {
    final deepIndicators = [
      'urge',
      'triggered',
      'struggling',
      'relapse',
      'tempted',
      'feeling weak',
      'can\'t resist',
      'want to give up',
      'about to',
      'edge',
      'edging',
      'craving',
      'jerk',
      'feeling to',
      'want to watch',
      'lonely',
      'stressed',
      'anxious',
      'depressed',
      'hopeless',
      'failing',
    ];

    final lowerMessage = message.toLowerCase();
    return deepIndicators.any((indicator) => lowerMessage.contains(indicator));
  }

  // ============================================
  // HELPER: Prepare Conversation History
  // ============================================
  List<Map<String, String>> _prepareConversationHistory(
    List<MessageModel>? messages,
  ) {
    if (messages == null || messages.isEmpty) {
      return [];
    }

    // Get last 5 messages (or fewer if less than 5 exist)
    final recentMessages = messages.length > 5
        ? messages.sublist(messages.length - 5)
        : messages;

    // Convert to format expected by AI
    return recentMessages.map((msg) {
      return {
        'role': msg.role == 'user' ? 'user' : 'assistant',
        'content': msg.text,
      };
    }).toList();
  }

  // ============================================
  // 2. GET ALL CONVERSATIONS (For History List)
  // ============================================
  Future<List<ConversationModel>> fetchAllConversations() async {
    try {
      final snapshot = await cloudDB
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('aiModelData')
          .orderBy('lastUpdated', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final msgs = data['msgs'] as List? ?? [];

        return ConversationModel(
          sessionId: doc.id,
          title:
              data['title'] ??
              (msgs.isNotEmpty
                  ? msgs[0]['text'] ?? 'Untitled Chat'
                  : 'Untitled Chat'),
          lastUpdated: data['lastUpdated'] as Timestamp?,
          messages: msgs.map((m) => MessageModel.fromMap(m)).toList(),
          messageCount: msgs.length,
        );
      }).toList();
    } catch (e) {
      print('Error fetching conversations: $e');
      return [];
    }
  }

  // ============================================
  // 3. GET SPECIFIC CONVERSATION (For Chat View)
  // ============================================
  Future<ConversationModel?> fetchConversation(String sessionId) async {
    try {
      final doc = await cloudDB
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('aiModelData')
          .doc(sessionId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final msgs = data['msgs'] as List? ?? [];

      return ConversationModel(
        sessionId: doc.id,
        title: data['title'] ?? 'Untitled Chat',
        lastUpdated: data['lastUpdated'] as Timestamp?,
        messages: msgs.map((m) => MessageModel.fromMap(m)).toList(),
        messageCount: msgs.length,
      );
    } catch (e) {
      print('Error fetching conversation: $e');
      return null;
    }
  }

  // ============================================
  // 4. STREAM CONVERSATION (Real-time Updates)
  // ============================================
  Stream<ConversationModel?> streamConversation(String sessionId) {
    return cloudDB
        .collection('users')
        .doc(auth.currentUser!.uid)
        .collection('aiModelData')
        .doc(sessionId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;

          final data = doc.data()!;
          final msgs = data['msgs'] as List? ?? [];

          return ConversationModel(
            sessionId: doc.id,
            title: data['title'] ?? 'Untitled Chat',
            lastUpdated: data['lastUpdated'] as Timestamp?,
            messages: msgs.map((m) => MessageModel.fromMap(m)).toList(),
            messageCount: msgs.length,
          );
        });
  }

  // ============================================
  // 5. START NEW CONVERSATION
  // ============================================
  void startNewConversation() {
    currentSessionId = null;
  }

  // ============================================
  // 6. CONTINUE EXISTING CONVERSATION
  // ============================================
  void continueConversation(String sessionId) {
    currentSessionId = sessionId;
  }

  // ============================================
  // 7. DELETE CONVERSATION
  // ============================================
  Future<void> deleteConversation(String sessionId) async {
    try {
      await cloudDB
          .collection('users')
          .doc(auth.currentUser!.uid)
          .collection('aiModelData')
          .doc(sessionId)
          .delete();

      if (currentSessionId == sessionId) {
        currentSessionId = null;
      }
    } catch (e) {
      print('Error deleting conversation: $e');
      rethrow;
    }
  }

  // ============================================
  // 8. GET USAGE STATS (Optional)
  // ============================================
  Future<Map<String, int>?> getUsageStats() async {
    if (auth.currentUser == null) return null;
    try {
      // This would require a separate Cloud Function
      // For now, return null
      return null;
    } catch (e) {
      print('Failed to get usage stats: $e');
      return null;
    }
  }
}

// ============================================
// DATA MODELS
// ============================================

class ConversationModel {
  final String sessionId;
  final String title;
  final Timestamp? lastUpdated;
  final List<MessageModel> messages;
  final int messageCount;

  ConversationModel({
    required this.sessionId,
    required this.title,
    this.lastUpdated,
    required this.messages,
    required this.messageCount,
  });

  DateTime? get lastUpdatedDate => lastUpdated?.toDate();
}

class MessageModel {
  final String role; // 'user' or 'ai'
  final String text;

  MessageModel({required this.role, required this.text});

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(role: map['role'] ?? 'user', text: map['text'] ?? '');
  }

  bool get isUser => role == 'user';
  bool get isAI => role == 'ai';
}

class VoiceModeAIService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isCurrentlySpeaking = false;

  VoiceModeAIService() {
    _initFlutterTTS();
  }

  void _initFlutterTTS() async {
    await _flutterTts.setLanguage("en-GB");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  /// Sends user voice message to GPT-4o-mini via Cloud Function
  Future<String> sendVoiceMessage(String userMessage) async {
    if (_auth.currentUser == null) {
      return 'Please log in to use voice chat.';
    }

    try {
      final callable = _functions.httpsCallable('sendVoiceMessage');
      final result = await callable.call({'message': userMessage.trim()});

      final data = result.data as Map<String, dynamic>;
      return data['reply'] as String;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        return e.message ?? 'Daily voice limit reached. Try again tomorrow! 🎤';
      } else if (e.code == 'unauthenticated') {
        return 'Session expired. Please log in again.';
      } else {
        print('Voice Function Error: ${e.code} - ${e.message}');
        return 'Sorry, I had trouble hearing that. Can you try again?';
      }
    } catch (e) {
      print('Voice Error: $e');
      return 'Connection failed. Check your internet and try again.';
    }
  }

  /// Speaks text using OpenAI TTS (premium) or Flutter TTS (free)
  /// Automatically selects based on daily usage via Cloud Function
  Future<void> speakWithAI(
    String text, {
    required Function() onStart,
    required Function() onComplete,
    required Function(String) onTextUpdate,
  }) async {
    // Stop any ongoing speech first
    await stopSpeaking();

    try {
      _isCurrentlySpeaking = true;

      // Update text immediately
      onTextUpdate(text);

      // Check if premium TTS is available
      final canUsePremium = await _canUsePremiumTTS();

      if (canUsePremium) {
        // Try OpenAI TTS via Cloud Function
        final success = await _speakWithOpenAI(
          text,
          onStart: onStart,
          onComplete: () {
            _isCurrentlySpeaking = false;
            onComplete();
          },
        );

        // If OpenAI TTS fails, fallback to Flutter TTS
        if (!success) {
          await _speakWithFlutterTTS(
            text,
            onStart: onStart,
            onComplete: () {
              _isCurrentlySpeaking = false;
              onComplete();
            },
          );
        }
      } else {
        // Use Flutter TTS (free)
        await _speakWithFlutterTTS(
          text,
          onStart: onStart,
          onComplete: () {
            _isCurrentlySpeaking = false;
            onComplete();
          },
        );
      }
    } catch (e) {
      print('Speak error: $e');
      _isCurrentlySpeaking = false;
      // Fallback to Flutter TTS on any error
      await _speakWithFlutterTTS(
        text,
        onStart: onStart,
        onComplete: () {
          _isCurrentlySpeaking = false;
          onComplete();
        },
      );
    }
  }

  /// Check if user can use premium TTS today
  Future<bool> _canUsePremiumTTS() async {
    if (_auth.currentUser == null) return false;

    try {
      final callable = _functions.httpsCallable('checkPremiumTTS');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      return data['canUsePremium'] as bool;
    } catch (e) {
      print('Error checking premium TTS: $e');
      return false;
    }
  }

  /// Get remaining premium TTS seconds
  Future<Map<String, int>> getPremiumTTSStatus() async {
    if (_auth.currentUser == null) {
      return {'remainingSeconds': 0, 'maxSeconds': 180};
    }

    try {
      final callable = _functions.httpsCallable('checkPremiumTTS');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;

      return {
        'remainingSeconds': data['remainingSeconds'] as int,
        'maxSeconds': data['maxSeconds'] as int,
      };
    } catch (e) {
      print('Error getting TTS status: $e');
      return {'remainingSeconds': 0, 'maxSeconds': 180};
    }
  }

  /// OpenAI TTS via Cloud Function (Premium)
  Future<bool> _speakWithOpenAI(
    String text, {
    required Function() onStart,
    required Function() onComplete,
  }) async {
    try {
      final estimatedDuration = _estimateTextDuration(text);

      final callable = _functions.httpsCallable('generateTTS');
      final result = await callable.call({
        'text': text,
        'estimatedDuration': estimatedDuration,
      });

      final data = result.data as Map<String, dynamic>;

      // Check if we should use fallback
      if (data['useFallback'] == true) {
        print('TTS: ${data['message']}');
        return false; // Signal to use Flutter TTS
      }

      // Decode base64 audio
      final audioBase64 = data['audioBase64'] as String;
      final audioBytes = base64Decode(audioBase64);

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final audioFile = File(
        '${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await audioFile.writeAsBytes(audioBytes);

      onStart();

      // Play audio with proper state handling
      StreamSubscription? subscription;
      subscription = _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          subscription?.cancel();
          onComplete();
          audioFile.delete().catchError((_) {
            print('Failed to delete temp audio file.');
          });
        }
      });

      await _audioPlayer.setFilePath(audioFile.path);
      await _audioPlayer.play();

      return true; // Success
    } catch (e) {
      print('OpenAI TTS Exception: $e');
      return false; // Fallback to Flutter TTS
    }
  }

  /// Flutter TTS (Free)
  Future<void> _speakWithFlutterTTS(
    String text, {
    required Function() onStart,
    required Function() onComplete,
  }) async {
    try {
      await _flutterTts.setLanguage("en-GB");

      onStart();

      _flutterTts.setCompletionHandler(() {
        onComplete();
      });

      _flutterTts.setErrorHandler((msg) {
        print('Flutter TTS Error: $msg');
        onComplete();
      });

      await _flutterTts.speak(text);
    } catch (e) {
      print('Flutter TTS Exception: $e');
      onComplete();
    }
  }

  /// Estimate text duration in seconds
  int _estimateTextDuration(String text) {
    // Average: ~150 words/min = 2.5 words/sec
    final wordCount = text.split(RegExp(r'\s+')).length;
    return (wordCount / 2.5).ceil();
  }

  /// Stop any playing audio
  Future<void> stopSpeaking() async {
    if (_isCurrentlySpeaking) {
      await _audioPlayer.stop();
      await _flutterTts.stop();
      _isCurrentlySpeaking = false;
    }
  }

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
  }
}
// ============================================
// Reporting Issue Service
// ============================================

class ReportService {
  static Future<void> sendReport(String message, {String? email}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reports')
          .add({
            'message': message,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': user.uid,
            'userEmail': email ?? user.email,
            'providedEmail': email != null,
          });
    } catch (e) {
      print('Error sending report: $e');
      rethrow;
    }
  }
}
