import 'package:cloud_functions/cloud_functions.dart';

/// Service for handling Panic Mode related Firebase Functions
class PanicModeService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Generate AI-powered panic mode guidance
  /// Returns personalized motivational text and breathing guidance
  Future<PanicModeResponse> generateGuidance({
    required int currentStreak,
    required int longestStreak,
  }) async {
    try {
      final callable = _functions.httpsCallable('generatePanicModeGuidance');

      final result = await callable.call({
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      });

      return PanicModeResponse.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      print('Firebase Functions Error: ${e.code} - ${e.message}');

      // Return fallback response
      return PanicModeResponse.fallback(currentStreak);
    } catch (e) {
      print('Error generating panic mode guidance: $e');

      // Return fallback response
      return PanicModeResponse.fallback(currentStreak);
    }
  }

  /// Check remaining panic mode uses for today
  Future<PanicModeLimitInfo> checkLimit() async {
    try {
      final callable = _functions.httpsCallable('checkPanicModeLimit');
      final result = await callable.call();

      return PanicModeLimitInfo.fromJson(result.data);
    } catch (e) {
      print('Error checking panic mode limit: $e');

      // Return default values on error
      return PanicModeLimitInfo(canUse: true, remainingUses: 10, maxPerDay: 10);
    }
  }
}

/// Response model for panic mode guidance
class PanicModeResponse {
  final String mainText;
  final String guidanceText;
  final int remainingUses;
  final String timestamp;
  final bool isFallback;

  PanicModeResponse({
    required this.mainText,
    required this.guidanceText,
    required this.remainingUses,
    required this.timestamp,
    this.isFallback = false,
  });

  factory PanicModeResponse.fromJson(Map<String, dynamic> json) {
    return PanicModeResponse(
      mainText: json['mainText'] ?? '',
      guidanceText: json['guidanceText'] ?? '',
      remainingUses: json['remainingUses'] ?? 0,
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      isFallback: json['isFallback'] ?? false,
    );
  }

  /// Fallback response when API fails
  factory PanicModeResponse.fallback(int currentStreak) {
    final mainText = currentStreak > 0
        ? 'You\'ve shown incredible strength for $currentStreak days straight. That\'s not luck - that\'s YOU choosing growth over instant gratification every single day.\n\nWhat you\'re feeling right now? It\'s just brain chemistry lying to you. These thoughts aren\'t facts - they\'re echoes of old patterns trying to pull you back. But you\'re not that person anymore.\n\nYou\'ve already proven you\'re stronger than this urge $currentStreak times. Right now, in this moment, you have all the power. The urge will pass. Your progress is real.'
        : 'You\'ve taken the hardest step - deciding to change. That alone shows incredible courage.\n\nThis urge you\'re feeling is your brain\'s old wiring trying to fire up. But you\'re rewiring it right now, in this very moment.\n\nYou have the power to let this pass. The thoughts aren\'t commands - they\'re just noise. Stay here. Breathe. This will pass.';

    const guidanceText =
        'Take slow, deep breaths. In for 4 counts, hold for 4, out for 6. '
        'Your mind is racing - that\'s normal. Don\'t fight the thoughts, '
        'just let them float by like clouds. Focus on the words above and '
        'your breathing. Nothing else matters for the next 4 minutes.';

    return PanicModeResponse(
      mainText: mainText,
      guidanceText: guidanceText,
      remainingUses: 10,
      timestamp: DateTime.now().toIso8601String(),
      isFallback: true,
    );
  }
}

/// Model for panic mode usage limits
class PanicModeLimitInfo {
  final bool canUse;
  final int remainingUses;
  final int maxPerDay;

  PanicModeLimitInfo({
    required this.canUse,
    required this.remainingUses,
    required this.maxPerDay,
  });

  factory PanicModeLimitInfo.fromJson(Map<String, dynamic> json) {
    return PanicModeLimitInfo(
      canUse: json['canUse'] ?? true,
      remainingUses: json['remainingUses'] ?? 0,
      maxPerDay: json['maxPerDay'] ?? 10,
    );
  }

  String get usageText {
    return '$remainingUses/$maxPerDay uses remaining today';
  }
}
