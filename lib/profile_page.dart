import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // This will render directly behind Dynamic Island
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(CupertinoIcons.back, color: Colors.white),
          ),
          const Spacer(),
          const Center(
            child: Text(
              'Profile Page',
              style: TextStyle(color: Colors.white, fontSize: 22),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
