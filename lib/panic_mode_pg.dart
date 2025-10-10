import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/utilis/size_config.dart';

class PanicModePg extends StatelessWidget {
  const PanicModePg({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(CupertinoIcons.back),
          ),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final currentMode = PanicOptions.get(index);
                return Card(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        (currentMode[1]),
                        Text(currentMode[0], textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
              itemCount: 4,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: SizeConfig.paddingMedium),
            child: ThisCountDown(),
          ),
        ],
      ),
    );
  }
}

class PanicOptions {
  static List<dynamic> get(int i) {
    final modes = [
      "Let's chat about this",
      "Game Engine: Beat me",
      "Hard Questions",
      "Voice talk",
    ];
    final List<Widget> icons = [
      Image.asset('assets/ai_pg/ai_chat.png', color: Colors.white,),
      HugeIcon(icon: HugeIcons.strokeRoundedAiGame),
      HugeIcon(icon: HugeIcons.strokeRoundedAiChat01),
      HugeIcon(icon: HugeIcons.strokeRoundedAiAudio),
    ];

    return [modes[i], icons[i]];
  }
}

class ThisCountDown extends StatefulWidget {
  const ThisCountDown({super.key});

  @override
  State<ThisCountDown> createState() => _ThisCountDownState();
}

class _ThisCountDownState extends State<ThisCountDown> {
  Key key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(seconds: 5),
      onEnd: () {
        context.go('/aimodel');
      },
      builder: (context, value, child) {
        final remaining = (value * 5).ceil();
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade900,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.deepPurpleAccent,
                  ),
                ),
              ),
              Text(
                '00:0$remaining',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
