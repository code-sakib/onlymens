import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/features/ai_model/presentation/ai_mainpage.dart';
import 'package:onlymens/user_model.dart';

class BWBPage extends StatelessWidget {
  const BWBPage({super.key});
  static UsersFriendsListModel usersFriendsList = UsersFriendsListModel(
    brand: 'brand',
    img: 'img',
    interested: 'interested',
    uploader: 'uploader',
    offer: 'offer',
    checkOffer: 'checkOffer',
    interestedUsers: ['interestedUsers'],
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Find people on the same journey'),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey,
                  child: Icon(
                    CupertinoIcons.person_2_fill,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: usersFriendsList.interestedUsers?.length ?? 0,
              itemBuilder: (context, index) {
                return GestureDetector(
                  // onTap: () => context.('chat', extra: user),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      child: ListTile(
                        leading: UserImgFetching(
                          user: UserModel(name: 'name', uID: 'user1'),
                        ),
                        title: Text('name'),
                        subtitle: Text('let grow together'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class UserImgFetching extends StatefulWidget {
  const UserImgFetching({super.key, required this.user});

  final UserModel user;

  @override
  _UserImgFetchingState createState() => _UserImgFetchingState();
}

class _UserImgFetchingState extends State<UserImgFetching> {
  final String fallbackImageUrl =
      'https://cdn-icons-png.flaticon.com/512/2815/2815428.png'; // Fallback image URL

  String currentImageUrl = ''; // Holds the URL to display

  static late bool isImgNull;

  @override
  void initState() {
    super.initState();
    isImgNull = widget.user.dp == null;

    if (isImgNull) return;

    currentImageUrl = widget.user.dp!; // Start with the primary image URL
  }

  @override
  Widget build(BuildContext context) {
    return !isImgNull
        ? CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(currentImageUrl),
            onBackgroundImageError: (error, stackTrace) {
              // Switch to fallback URL if primary image fails
              setState(() {
                currentImageUrl = fallbackImageUrl;
              });
            },
          )
        : CircleAvatar(
            radius: 25,
            child: Text(widget.user.name[0].toUpperCase()),
          );
  }
}

class BwbPage2 extends StatelessWidget {
  const BwbPage2({super.key});

  @override
  Widget build(BuildContext context) {
    final names = [
      'Alex Johnson',
      'Ryan Garcia',
      'James Wilson',
      'Ethan Brown',
      'Michael Davis',
      'Daniel Martinez',
      'David Lee',
      'Matthew Taylor',
      'Chris Anderson',
      'Brandon Thomas',
    ];

    final people = List.generate(
      10,
      (i) => {
        'name': names[i],
        'status': i % 3 == 0
            ? 'Online'
            : i % 3 == 1
            ? 'Away'
            : 'Busy',
        'image': 'https://picsum.photos/200?random=$i',
      },
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: false,
            floating: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.asset('assets/bwb/map.png', fit: BoxFit.cover),
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => context.go('/streaks'),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedFire02,
                  color: Colors.deepOrangeAccent,
                ),
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              final person = people[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  i == 0
                      ? Text(
                          '*10 people near you on the same journey',
                          style: TextStyle(
                            color: Colors.deepPurple[500],
                            fontSize: 12,
                          ),
                        )
                      : SizedBox.shrink(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(person['image']!),
                    ),
                    title: Text(person['name']!),
                    subtitle: Text(person['status']!),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            name: person['name']!,
                            status: person['status']!,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }, childCount: people.length),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String name;
  final String status;

  const ChatScreen({super.key, required this.name, required this.status});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<String> _messages = [];

  void _sendMessage() {
    if (_msgController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add(_msgController.text);
        _msgController.clear();
      });
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your Privacy, Your Control',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                '• You control what you share - we have no access to your personal conversations',
              ),
              SizedBox(height: 8),
              Text(
                '• Server protection - your chats are protected and secure',
              ),
              SizedBox(height: 8),
              Text(
                '• No data collection - we don\'t store or monitor your messages',
              ),
              SizedBox(height: 8),
              Text(
                '• Complete privacy - only you and your recipient can read the messages',
              ),
              SizedBox(height: 12),
              Text(
                'Your conversations belong to you. We are committed to protecting your privacy and ensuring your data remains secure.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name),
            Text(widget.status, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.privacy_tip),
            onPressed: _showPrivacyPolicy,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _messages[i],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          chatInput(_msgController, _sendMessage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }
}
