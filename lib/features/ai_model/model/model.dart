import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class OpenAIService {
  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  /// Sends user message to GPT-4o-mini and returns AI's reply
  Future<String> sendMessage(String userMessage) async {
    final uri = Uri.parse(_baseUrl);

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = jsonEncode({
      "model": "gpt-4o-mini",
      "messages": [
        {
          "role": "system",
          "content":
              "You are OnlyMens, a supportive AI that helps men quit pornography addiction. "
              "You are kind, practical, and motivating. "
              "Avoid judging the user. Help him identify triggers, plan short streaks, and stay positive.",
        },
        {"role": "user", "content": userMessage},
      ],
      "max_tokens": 250,
      "temperature": 0.8,
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(data);
      final reply = data['choices'][0]['message']['content'];
      return reply.trim();
    } else {
      print('Error: ${response.statusCode} - ${response.body}');
      return 'Sorry, something went wrong. Please try again.';
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
  final String _chatUrl = 'https://api.openai.com/v1/chat/completions';
  final String _ttsUrl = 'https://api.openai.com/v1/audio/speech';
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final VoiceUsageService _usageService = VoiceUsageService();

  VoiceModeAIService() {
    _initFlutterTTS();
  }

  void _initFlutterTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  /// Sends user voice message to GPT-4o-mini and returns AI's reply text
  Future<String> sendVoiceMessage(String userMessage) async {
    final uri = Uri.parse(_chatUrl);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };
    final body = jsonEncode({
      "model": "gpt-4o-mini",
      "messages": [
        {
          "role": "system",
          "content":
              "You are OnlyMens Voice Coach, a supportive AI companion for men overcoming pornography addiction. "
              "You're speaking out loud, so keep responses conversational and natural. "
              "Be warm, direct, and motivating. Keep answers concise (2-4 sentences max) since this is voice. "
              "Speak like a trusted friend who's been through it. "
              "Use simple language, short sentences, and natural pauses. "
              "Avoid lists or complex formatting - just talk naturally.",
        },
        {"role": "user", "content": userMessage},
      ],
      "max_tokens": 150,
      "temperature": 0.9,
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final reply = data['choices'][0]['message']['content'];
      return reply.trim();
    } else {
      print('Error: ${response.statusCode} - ${response.body}');
      return 'Sorry, I had trouble hearing that. Can you try again?';
    }
  }

  /// Speaks text using either OpenAI TTS (premium) or Flutter TTS (free)
  /// Automatically selects based on daily usage
  Future<void> speakWithAI(
    String text, {
    required Function() onStart,
    required Function() onComplete,
  }) async {
    try {
      // Check if user can use premium TTS
      final canUsePremium = await _usageService.canUsePremiumTTS();

      if (canUsePremium) {
        // Use OpenAI Fable TTS (Premium)
        await _speakWithOpenAI(text, onStart: onStart, onComplete: onComplete);
      } else {
        // Use Flutter TTS (Free)
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

  /// OpenAI Fable TTS (Premium - First 3 mins/day)
  final String _instructions =
      """Voice Affect: Soft, gentle, soothing; embody tranquility.\n\nTone: Calm, reassuring, peaceful; convey genuine warmth and serenity.\n\nPacing: Slow, deliberate, and unhurried; pause gently after instructions to allow the listener time to relax and follow along.\n\nEmotion: Deeply soothing and comforting; express genuine kindness and care.\n\nPronunciation: Smooth, soft articulation, slightly elongating vowels to create a sense of ease.\n\nPauses: Use thoughtful pauses, especially between breathing instructions and visualization guidance, enhancing relaxation and mindfulness.""";

  Future<void> _speakWithOpenAI(
    String text, {
    required Function() onStart,
    required Function() onComplete,
  }) async {
    try {
      final uri = Uri.parse(_ttsUrl);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };
      final body = jsonEncode({
        "model": "tts-1",
        "voice": "fable",
        "input": text,
        "instructions": _instructions,
        "speed": 1.0,
      });

      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final audioFile = File(
          '${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await audioFile.writeAsBytes(response.bodyBytes);

        onStart();

        // Track usage
        final duration = _usageService.estimateTextDuration(text);
        await _usageService.trackTTSUsage(duration);

        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            onComplete();
            audioFile.delete().catchError((_) {});
          }
        });

        await _audioPlayer.setFilePath(audioFile.path);
        await _audioPlayer.play();
      } else {
        print('OpenAI TTS Error: ${response.statusCode}');
        // Fallback to Flutter TTS
        await _speakWithFlutterTTS(
          text,
          onStart: onStart,
          onComplete: onComplete,
        );
      }
    } catch (e) {
      print('OpenAI TTS Exception: $e');
      await _speakWithFlutterTTS(
        text,
        onStart: onStart,
        onComplete: onComplete,
      );
    }
  }

  /// Flutter TTS (Free - After 3 mins/day)
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

  /// Stops any playing audio
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

class VoiceUsageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _maxPremiumSeconds = 180; // 3 minutes

  /// Check if user can use premium TTS (Fable) today
  Future<bool> canUsePremiumTTS() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final today = _getTodayDate();
      final docRef = _db
          .collection('users')
          .doc(userId)
          .collection('voiceUsage')
          .doc(today);

      final doc = await docRef.get();

      if (!doc.exists) return true;

      final data = doc.data();
      final secondsUsed = (data?['ttsSecondsUsed'] ?? 0) as int;

      return secondsUsed < _maxPremiumSeconds;
    } catch (e) {
      print('Error checking premium TTS: $e');
      return false; // Fallback to free TTS on error
    }
  }

  /// Get remaining premium seconds for today
  Future<int> getRemainingPremiumSeconds() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;

    try {
      final today = _getTodayDate();
      final docRef = _db
          .collection('users')
          .doc(userId)
          .collection('voiceUsage')
          .doc(today);

      final doc = await docRef.get();

      if (!doc.exists) return _maxPremiumSeconds;

      final data = doc.data();
      final secondsUsed = (data?['ttsSecondsUsed'] ?? 0) as int;

      return (_maxPremiumSeconds - secondsUsed).clamp(0, _maxPremiumSeconds);
    } catch (e) {
      print('Error getting remaining seconds: $e');
      return 0;
    }
  }

  /// Track TTS usage in seconds
  Future<void> trackTTSUsage(int seconds) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final today = _getTodayDate();
      final docRef = _db
          .collection('users')
          .doc(userId)
          .collection('voiceUsage')
          .doc(today);

      await docRef.set({
        'ttsSecondsUsed': FieldValue.increment(seconds),
        'lastUpdated': FieldValue.serverTimestamp(),
        'date': today,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error tracking TTS usage: $e');
    }
  }

  /// Get today's date as string (YYYY-MM-DD)
  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Estimate text duration in seconds (rough calculation)
  int estimateTextDuration(String text) {
    // Average speaking rate: ~150 words per minute = 2.5 words per second
    final wordCount = text.split(RegExp(r'\s+')).length;
    return (wordCount / 2.5).ceil();
  }
}
