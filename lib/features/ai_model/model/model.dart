import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';
import 'package:onlymens/core/globals.dart';
import 'package:path_provider/path_provider.dart';

class OpenAIService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1', // Your function's region
  );

  /// Sends user message to GPT-4o-mini via Cloud Function
  Future<String> sendMessage(String userMessage) async {
    final user = auth.currentUser;

    if (user == null) {
      return 'Please log in to use the chat feature.';
    }

    // Force token refresh to ensure it's valid
    try {
      await user.getIdToken(true); // Force refresh
    } catch (e) {
      print('Token refresh failed: $e');
      return 'Session expired. Please log in again.';
    }

    try {
      // Call Cloud Function
      final callable = _functions.httpsCallable('sendChatMessage');
      final result = await callable.call({'message': userMessage.trim()});

      // Extract response
      final data = result.data as Map<String, dynamic>;
      return data['reply'] as String;
    } on FirebaseFunctionsException catch (e) {
      // Handle specific errors
      if (e.code == 'resource-exhausted') {
        // Rate limit hit - show user-friendly message
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
      // Network or other errors
      print('Unexpected Error: $e');
      return 'Connection failed. Check your internet and try again.';
    }
  }

  /// Get user's current usage stats (optional feature)
  Future<Map<String, int>?> getUsageStats() async {
    if (auth.currentUser == null) return null;

    try {
      final callable = _functions.httpsCallable('sendChatMessage');
      // You can extend the Cloud Function to return usage in every call
      // For now, it's returned with each message
      return null;
    } catch (e) {
      print('Failed to get usage stats: $e');
      return null;
    }
  }
}

class HardModeAIService {
  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  /// Sends user message with persona context and returns personalized AI reply
  Future<String> sendHardModeMessage({
    required String userMessage,
    required Map<String, dynamic> userPersona,
    required int currentStreak,
    required int longestStreak,
  }) async {
    final uri = Uri.parse(_baseUrl);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    // Build personalized system prompt
    final systemPrompt = _buildHardModeSystemPrompt(
      userPersona,
      currentStreak,
      longestStreak,
    );

    final body = jsonEncode({
      "model": "gpt-4o-mini",
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": userMessage},
      ],
      "max_tokens": 350,
      "temperature": 0.9,
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final reply = data['choices'][0]['message']['content'];
      return reply.trim();
    } else {
      print('Error: ${response.statusCode} - ${response.body}');
      return 'Sorry, something went wrong. Please try again.';
    }
  }

  /// Builds a personalized system prompt based on user's persona and progress
  String _buildHardModeSystemPrompt(
    Map<String, dynamic> persona,
    int currentStreak,
    int longestStreak,
  ) {
    final usage = persona['usage'] ?? 'frequent';
    final effects = List<String>.from(persona['effects'] ?? []);
    final triggers = List<String>.from(persona['triggers'] ?? []);
    final aspects = List<String>.from(persona['aspects'] ?? []);

    // Analyze streak progress
    final streakAnalysis = _getStreakAnalysis(currentStreak, longestStreak);

    return """You are OnlyMens Hard Mode - an advanced AI coach for men overcoming pornography addiction.

USER'S JOURNEY:
Current Streak: $currentStreak days
Longest Streak: $longestStreak days
$streakAnalysis

USER'S PROFILE:
- Usage Pattern: $usage
- Negative Effects Experienced: ${effects.join(', ')}
- Primary Triggers: ${triggers.join(', ')}
- Growth Goals: ${aspects.join(', ')}


YOUR RESPONSE STRUCTURE:
1. START WITH ACKNOWLEDGMENT (1-2 sentences):
   - Recognize their current streak progress specifically
   - Reference their journey considering their usage pattern and effects they've experienced
   - Be genuine - celebrate wins, but be honest about struggles

2. ADDRESS THEIR MESSAGE (2-3 sentences):
   - Answer their question or respond to their concern
   - Reference their specific triggers when relevant
   - Provide practical, actionable advice aligned with their growth goals
   - Be direct and honest, not sugar-coated

3. ASK 3 REFLECTIVE QUESTIONS (short, punchy):
   - Ask 3 deep, personalized questions that challenge them to think about:
     * Their growth goals (${aspects.join(', ')})
     * Their triggers (${triggers.join(', ')})
     * Their life purpose and meaningful activities
   - Questions should be specific, not generic
   - Keep each question short and direct

4. END WITH BRAIN HACKS (2-3 quick tactics):
   - Give 2-3 specific, unconventional tactics to avoid relapse
   - Focus on brain tricks and psychological hacks
   - Make them counterintuitive or surprising
   - Format as short, actionable commands
   - Examples: "Cold shower for 30 seconds when triggered", "Do 20 pushups immediately", "Text a friend 'I'm struggling' - don't explain why"
   - Tie hacks to their specific triggers when possible

TONE:
- Tough love: supportive but challenging
- Direct and honest, not overly soft
- Accountable and real
- Focus on growth, not just abstinence
- Reference their specific situation, not generic advice

AVOID:
- Generic motivational phrases
- Being preachy or judgmental
- Ignoring their streak data
- Forgetting their triggers and goals
- Asking shallow questions at the end""";
  }

  /// Analyzes streak progress and provides context
  String _getStreakAnalysis(int current, int longest) {
    if (current == 0) {
      return "You're at day zero - a fresh start. Remember, you've done $longest days before.";
    } else if (current == longest && current > 0) {
      return "You're at a personal record - $current days and counting. This is new territory.";
    } else if (current > longest * 0.7) {
      return "You're approaching your record. ${longest - current} days away from your best.";
    } else if (current >= 7) {
      return "You've built momentum with $current days. Keep the focus sharp.";
    } else if (current >= 3) {
      return "You're in the crucial early phase at day $current. The hardest days often come early.";
    } else {
      return "You're rebuilding at day $current. Every day is progress.";
    }
  }
}

class VoiceModeAIService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  VoiceModeAIService() {
    _initFlutterTTS();
  }

  void _initFlutterTTS() async {
    await _flutterTts.setLanguage("en-US");
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
  }) async {
    try {
      // Check if premium TTS is available
      final canUsePremium = await _canUsePremiumTTS();

      if (canUsePremium) {
        // Try OpenAI TTS via Cloud Function
        final success = await _speakWithOpenAI(
          text,
          onStart: onStart,
          onComplete: onComplete,
        );

        // If OpenAI TTS fails, fallback to Flutter TTS
        if (!success) {
          await _speakWithFlutterTTS(
            text,
            onStart: onStart,
            onComplete: onComplete,
          );
        }
      } else {
        // Use Flutter TTS (free)
        await _speakWithFlutterTTS(
          text,
          onStart: onStart,
          onComplete: onComplete,
        );
      }
    } catch (e) {
      print('Speak error: $e');
      // Fallback to Flutter TTS on any error
      await _speakWithFlutterTTS(
        text,
        onStart: onStart,
        onComplete: onComplete,
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

      // Play audio
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          onComplete();
          audioFile.delete().catchError((_) {});
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
    await _audioPlayer.stop();
    await _flutterTts.stop();
  }

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
  }
}
