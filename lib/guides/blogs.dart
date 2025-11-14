import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

// BlogPost model
class BlogPost {
  final String id;
  final String title;
  final String excerpt;
  final String? content;
  final String iconName;
  final String colorHex;
  final String route;
  final String readTime;
  final String category;
  final DateTime? createdAt;

  BlogPost({
    required this.id,
    required this.title,
    required this.excerpt,
    this.content,
    required this.iconName,
    required this.colorHex,
    required this.route,
    required this.readTime,
    required this.category,
    this.createdAt,
  });

  factory BlogPost.fromJson(String id, Map<String, dynamic> json) {
    DateTime? created;
    if (json['createdAt'] is Timestamp) {
      created = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      try {
        created = DateTime.parse(json['createdAt']);
      } catch (_) {}
    }

    return BlogPost(
      id: id,
      title: (json['title'] ?? '').toString(),
      excerpt: (json['excerpt'] ?? '').toString(),
      content: json['content']?.toString(),
      iconName: (json['iconName'] ?? 'article').toString(),
      colorHex: (json['colorHex'] ?? '#9C27B0').toString(),
      route: (json['route'] ?? '/blog/detail').toString(),
      readTime: (json['readTime'] ?? '5 min').toString(),
      category: (json['category'] ?? '').toString(),
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'excerpt': excerpt,
    'content': content,
    'iconName': iconName,
    'colorHex': colorHex,
    'route': route,
    'readTime': readTime,
    'category': category,
    'createdAt': createdAt?.toIso8601String(),
  };

  IconData get icon {
    switch (iconName) {
      case 'psychology':
        return Icons.psychology;
      case 'psychology_alt':
        return Icons.psychology_alt;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.article;
    }
  }

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      final argb = int.parse('FF$hex', radix: 16);
      return Color(argb);
    } catch (_) {
      return Colors.deepPurple;
    }
  }
}

// Safe StreamBuilder widget
Widget buildBlogSection(BuildContext context) {
  return StreamBuilder(
    stream: FirebaseFirestore.instance
        .collection('blogs')
        .doc('all')
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData ||
          snapshot.data?.data() == null ||
          snapshot.hasError) {
        return fallbackBlogs(context);
      }

      final data = snapshot.data!.data() as Map<String, dynamic>;
      List<Map<String, dynamic>> blogs = [];

      data.forEach((key, value) {
        if (value is Map<String, dynamic>) blogs.add(value);
      });

      if (blogs.isEmpty) {
        return fallbackBlogs(context);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'Your Daily Reads',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: blogs.length,
            itemBuilder: (context, index) {
              final blog = blogs[index];
              return blogCard(context, blog);
            },
          ),
        ],
      );
    },
  );
}

Widget blogCard(BuildContext context, Map<String, dynamic> blog) {
  final colorHex = blog['colorHex'] ?? '#9C27B0';
  final color = Color(int.parse(colorHex.replaceFirst('#', '0xff')));

  return InkWell(
    borderRadius: BorderRadius.circular(16.r),
    onTap: () {
      context.push('/blogdetail', extra: blog);
    },
    child: Container(
      margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        leading: Container(
          height: double.infinity,
          width: 48.w,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(Icons.article, color: color, size: 24.r),
        ),
        title: Text(
          blog['title'] ?? 'Blog Title',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

Widget fallbackBlogs(BuildContext context) {
  final defaultPosts = [
    BlogPost(
      id: '1',
      title: 'How Porn Paves the Way to Misery',
      excerpt:
          'Understanding the psychological and physiological impact of pornography addiction...',
      content: null,
      iconName: 'psychology',
      colorHex: '#F44336',
      route: '/blog/misery',
      readTime: '8 min',
      category: 'Understanding Addiction',
    ),
    BlogPost(
      id: '2',
      title: 'Rewiring Your Brain: The Science of Recovery',
      excerpt:
          'Discover how neuroplasticity can help you rebuild neural pathways...',
      content: null,
      iconName: 'psychology_alt',
      colorHex: '#2196F3',
      route: '/blog/rewiring',
      readTime: '10 min',
      category: 'Neuroscience',
    ),
    BlogPost(
      id: '3',
      title: 'Building Unshakeable Self-Discipline',
      excerpt:
          'Practical strategies and mindset shifts to develop iron-will discipline...',
      content: null,
      iconName: 'fitness_center',
      colorHex: '#4CAF50',
      route: '/blog/discipline',
      readTime: '12 min',
      category: 'Self Mastery',
    ),
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        child: Text(
          'Featured Blogs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      ...defaultPosts.map((p) => blogCard(context, p.toJson())),
    ],
  );
}

/// Manager for fetching blog posts from Firestore
class BlogManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<BlogPost>> fetchTodayBlogs() async {
    try {
      print('📖 Fetching blogs from blogs/today');

      final doc = await _firestore.collection('blogs').doc('today').get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final List<BlogPost> blogs = [];

        for (int i = 1; i <= 3; i++) {
          final blogData = data['$i'];
          if (blogData != null && blogData is Map<String, dynamic>) {
            blogs.add(BlogPost.fromJson('$i', blogData));
          }
        }

        if (blogs.isNotEmpty) {
          print('✅ Fetched ${blogs.length} blogs successfully');
          return blogs;
        }
      }

      print('⚠️ blogs/today document not found or empty, using default blogs');
      return _getDefaultBlogs();
    } catch (e) {
      print('❌ Blog fetch error: $e');
      return _getDefaultBlogs();
    }
  }

  static Future<List<BlogPost>> fetchAllBlogs() async {
    try {
      print('📖 Fetching all blogs from blogs/all');

      final doc = await _firestore.collection('blogs').doc('all').get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final List<BlogPost> blogs = [];

        data.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            blogs.add(BlogPost.fromJson(key, value));
          }
        });

        print('✅ Fetched ${blogs.length} blogs from all');
        return blogs;
      }

      print('⚠️ blogs/all document not found');
      return [];
    } catch (e) {
      print('❌ All blogs fetch error: $e');
      return [];
    }
  }

  static List<BlogPost> _getDefaultBlogs() {
    return [
      BlogPost(
        id: '1',
        title: 'How Porn Paves the Way to Misery',
        excerpt: 'Understanding the psychological and physiological impact...',
        iconName: 'psychology',
        colorHex: '#F44336',
        route: '/blog/misery',
        readTime: '',
        category: '',
      ),
      BlogPost(
        id: '2',
        title: 'Rewiring Your Brain: The Science of Recovery',
        excerpt: 'Discover how neuroplasticity can help you rebuild...',
        iconName: 'psychology_alt',
        colorHex: '#2196F3',
        route: '/blog/rewiring',
        readTime: '',
        category: '',
      ),
      BlogPost(
        id: '3',
        title: 'Building Unshakeable Self-Discipline',
        excerpt: 'Practical strategies and mindset shifts...',
        iconName: 'fitness_center',
        colorHex: '#4CAF50',
        route: '/blog/discipline',
        readTime: '',
        category: '',
      ),
    ];
  }
}

class BlogDetailPage extends StatelessWidget {
  final Map<String, dynamic> blogData;

  const BlogDetailPage({super.key, required this.blogData});

  String get _title => blogData['title']?.toString() ?? 'Article';
  String get _excerpt => blogData['excerpt']?.toString() ?? '';
  String? get _content => blogData['content']?.toString();
  String get _iconName => blogData['iconName']?.toString() ?? 'article';

  Color get _color {
    try {
      final hex = (blogData['colorHex']?.toString() ?? '#9C27B0').replaceAll(
        '#',
        '',
      );
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.deepPurple;
    }
  }

  IconData get _icon {
    switch (_iconName) {
      case 'psychology':
        return Icons.psychology;
      case 'psychology_alt':
        return Icons.psychology_alt;
      default:
        return Icons.article;
    }
  }

  String _getFallbackContent() {
    return _excerpt.isNotEmpty
        ? _excerpt
        : 'Full article content not available.';
  }

  @override
  Widget build(BuildContext context) {
    final contentToShow = _content ?? _getFallbackContent();

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: Colors.white, size: 24.r),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(_icon, color: _color, size: 20.r),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                _title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_color.withOpacity(0.28), _color.withOpacity(0.12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: _color.withOpacity(0.36)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icon, color: _color, size: 48.r),
                  SizedBox(height: 16.h),
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey[400],
                        size: 16.r,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        blogData['readTime']?.toString() ?? '10 min',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(width: 20.w),
                      if (blogData['createdAt'] != null)
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.grey[400],
                              size: 16.r,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              (blogData['createdAt'] is Timestamp)
                                  ? (blogData['createdAt'] as Timestamp)
                                        .toDate()
                                        .toLocal()
                                        .toString()
                                        .split(' ')
                                        .first
                                  : blogData['createdAt']?.toString() ?? '',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 30.h),

            Text(
              contentToShow,
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey[300],
                height: 1.8,
                letterSpacing: 0.2,
              ),
            ),

            SizedBox(height: 40.h),
            // CTA
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: _color.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  Icon(Icons.favorite, color: _color, size: 40.r),
                  SizedBox(height: 16.h),
                  Text(
                    'Your Journey Starts Today',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Every moment you choose recovery is a victory. Keep going—you\'re worth it.',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}
