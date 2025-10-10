import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:onlymens/features/ai_model/model/model.dart';
import 'package:onlymens/panic_mode_pg.dart';
import 'package:onlymens/utilis/size_config.dart';

final List<ChannelItem> _channels = [
  ChannelItem(
    name: 'Hard Mode',
    icon: HugeIcon(icon: HugeIcons.strokeRoundedAiChat01),
    tobuild: HardModeWidget(),
  ),
  ChannelItem(
    name: 'Game Mode',
    icon: HugeIcon(icon: HugeIcons.strokeRoundedAiGame),
    tobuild: GameModeWidget(),
  ),
  ChannelItem(
    name: 'Chat Mode',
    icon: Image.asset('assets/ai_pg/ai_chat.png', color: Colors.white),
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
                    icon: HugeIcons.strokeRoundedMenu01,
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
          changeMode: (int mode) => setState(() => currentMode = mode),
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
          IconButton(onPressed: () {}, icon: Icon(CupertinoIcons.app)),
          SizedBox(
            height: 250,
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
        ],
      ),
    );
  }
}

divider() {
  return Padding(
    padding: const EdgeInsets.all(12.0),
    child: Divider(thickness: 1, color: Colors.grey),
  );
}

class ChannelItem {
  final String name;
  final Widget icon;
  final String pgText;
  final Widget tobuild;
  ChannelItem({
    required this.name,
    required this.icon,
    required this.tobuild,
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

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final OpenAIService _openAIService = OpenAIService();
  final TextEditingController _controller = TextEditingController();

  List<Map<String, String>> messages = [];
  bool _isLoading = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": text});
      _isLoading = true;
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
    messages.add({'role': 'user', 'text': 'Hey there'});
    return Column(
      children: [
        SizedBox(
          height: SizeConfig.screenHeight / 1.37,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isUser = msg["role"] == "user";
              return Align(
                alignment: isUser ? Alignment.topRight : Alignment.topLeft,
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
        ),
        if (_isLoading)
          const LinearProgressIndicator(color: Colors.deepPurple, minHeight: 2),
        chatInput(_controller, _sendMessage),
      ],
    );
  }
}

/// ------------------ CHAT INPUT ------------------

Widget chatInput(TextEditingController controller, VoidCallback sendMessage) {
  return Padding(
    padding: const EdgeInsets.all(10.0),
    child: Container(
      height: SizeConfig.blockHeight * 7,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepPurple), // your purple border
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.deepPurpleAccent,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none, // removes default underline & box
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,

                fillColor: Colors.transparent,
                isDense: true,
              ),
            ),
          ),
          FloatingActionButton(
            shape: const CircleBorder(),
            onPressed: sendMessage,
            backgroundColor: Colors.deepPurple,
            child: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ],
      ),
    ),
  );
}

/// ------------------ HARD MODE (placeholder) ------------------
class HardModeWidget extends StatelessWidget {
  const HardModeWidget({super.key});

  static final controller = TextEditingController();
  sendMessage() {}

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedAiChat01,
          size: 100,
          color: Colors.grey[850],
        ),
        Text("Let's brainstorm on something more important!"),

        SizedBox(height: SizeConfig.screenHeight / 3),
        chatInput(controller, sendMessage),
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
        SizedBox(
          height: SizeConfig.screenHeight / 1.5,
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
                  onPressed: () {},
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
        ThisCountDown(),
      ],
    );
  }
}

class VoiceModeWidget extends StatelessWidget {
  const VoiceModeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LottieBuilder.network(
            'https://lottie.host/184a567b-0d6c-40b3-aef7-084b029d49fd/9Bgw0imegR.json',
          ),
        ],
      ),
    );
  }
}
