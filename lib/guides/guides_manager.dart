import 'package:cloud_firestore/cloud_firestore.dart';


/// Manager for fetching daily motivational quotes
class QuoteManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch today's motivational quote from 'quotes/today' document
  /// Falls back to default quote if document doesn't exist or on error
  static Future<DailyQuote> fetchTodayQuote() async {
    try {
      print('📖 Fetching quote from quotes/today');

      final doc = await _firestore.collection('quotes').doc('today').get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        print('✅ Quote fetched successfully');

        return DailyQuote(
          text: data['text'] ?? _getDefaultQuote().text,
          author: data['author'] ?? _getDefaultQuote().author,
          date: data['date'] ?? _getTodayString(),
          imageUrl: data['imageUrl'],
        );
      }

      // Document doesn't exist - return default quote
      print('⚠️ quotes/today document not found, using default quote');
      return _getDefaultQuote();
    } catch (e) {
      print('❌ Quote fetch error: $e');
      return _getDefaultQuote();
    }
  }

  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static DailyQuote _getDefaultQuote() {
    return DailyQuote(
      text:
          'The truth is simple. If it was complicated, everyone would understand it.',
      author: 'Walt Whitman',
      date: _getTodayString(),
      imageUrl: null, // Will use asset image
    );
  }
}

/// Data class for daily motivational quote
class DailyQuote {
  final String text;
  final String author;
  final String date;
  final String? imageUrl;

  DailyQuote({
    required this.text,
    required this.author,
    required this.date,
    this.imageUrl,
  });

  factory DailyQuote.fromJson(Map<String, dynamic> json) {
    return DailyQuote(
      text: json['text'] ?? '',
      author: json['author'] ?? 'Unknown',
      date: json['date'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'author': author, 'date': date, 'imageUrl': imageUrl};
  }
}

/// Manager for fetching level-based guides
class GuideManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Level thresholds matching AvatarManager
  static const Map<int, String> LEVEL_RANGES = {
    1: '1-7',
    2: '8-14',
    3: '15-22',
    4: '23-30',
  };

  /// Fetch guide for current streak level
  static Future<LevelGuide> fetchGuideForStreak(int currentStreakDays) async {

    try {
      print('📚 Fetching guide for streak days: $currentStreakDays');
      final int level = getLevelFromDays(currentStreakDays);
      final String rangeKey = LEVEL_RANGES[level] ?? '1-7';
      print("rangeKey is $rangeKey");
      print('📚 Fetching guide for level $level (days: $currentStreakDays)');

      final doc = await _firestore.collection('lvlguide').doc(rangeKey).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        print('✅ Guide fetched successfully for $rangeKey');
        // Parse tips list from Firestore
        final List<String> tips = [];
        if (data['guide'] is List) {
          tips.addAll((data['guide'] as List).map((e) => e.toString()));
        } else if (data['guide'] is String) {
          // If stored as single string, split by newlines or semicolons
          tips.addAll(
            (data['guide'] as String)
                .split('\n')
                .where((tip) => tip.trim().isNotEmpty),
          );
        }

        return LevelGuide(
          level: level,
          dayRange: rangeKey,
          tips: tips.isNotEmpty ? tips : getDefaultGuide(level).tips,
          title: data['title'] ?? 'Level $level Guide',
        );
      }

      // Document doesn't exist - create it with default data
      print('📝 Creating guide document for $rangeKey');
      await _createGuideDocument(rangeKey, level);

      // Return default guide
      return getDefaultGuide(level);
    } catch (e) {
      print('❌ Guide fetch error: $e');
      return getDefaultGuide(1);
    }
  }

  /// Create guide document in Firestore for new users
  static Future<void> _createGuideDocument(String rangeKey, int level) async {
    try {
      final defaultGuide = getDefaultGuide(level);

      await _firestore.collection('lvlguide').doc(rangeKey).set({
        'title': defaultGuide.title,
        'guide': defaultGuide.tips,
        'level': level,
        'dayRange': rangeKey,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Created guide document: $rangeKey');
    } catch (e) {
      print('❌ Failed to create guide document: $e');
    }
  }

  static int getLevelFromDays(int streakDays) {
    if (streakDays < 8) return 1;
    if (streakDays < 15) return 2;
    if (streakDays < 23) return 3;
    return 4;
  }

  static LevelGuide getDefaultGuide(int level) {
    final Map<int, List<String>> defaultTips = {
      1: [
        'Stay hydrated - drink 8 glasses of water daily',
        'Take a 10-minute walk when urges strike',
        'Practice deep breathing: 4-7-8 technique',
        'Remove triggers from your environment',
      ],
      2: [
        'Establish a morning routine to start strong',
        'Exercise for 30 minutes to boost mood and energy',
        'Journal your feelings and triggers daily',
        'Learn a new skill to redirect focus',
      ],
      3: [
        'Practice mindfulness meditation for 15 minutes',
        'Build meaningful connections with others',
        'Set long-term goals beyond recovery',
        'Identify and challenge negative thought patterns',
      ],
      4: [
        'Mentor someone earlier in their journey',
        'Develop a life vision and purpose',
        'Master stress management techniques',
        'Build unshakeable daily disciplines',
      ],
    };

    return LevelGuide(
      level: level,
      dayRange: LEVEL_RANGES[level] ?? '1-7',
      tips: defaultTips[level] ?? defaultTips[1]!,
      title: 'Level $level Guide (Days ${LEVEL_RANGES[level]})',
    );
  }
}

/// Data class for level-based guide
class LevelGuide {
  final int level;
  final String dayRange;
  final List<String> tips;
  final String title;

  LevelGuide({
    required this.level,
    required this.dayRange,
    required this.tips,
    required this.title,
  });

  factory LevelGuide.fromJson(Map<String, dynamic> json) {
    final List<String> tips = [];
    if (json['guide'] is List) {
      tips.addAll((json['guide'] as List).map((e) => e.toString()));
    }

    return LevelGuide(
      level: json['level'] ?? 1,
      dayRange: json['dayRange'] ?? '1-7',
      tips: tips,
      title: json['title'] ?? 'Level Guide',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'dayRange': dayRange,
      'guide': tips,
      'title': title,
    };
  }
}
