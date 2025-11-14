// Updated bottom_appbar.dart for cleaner 3-button layout

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:onlymens/core/apptheme.dart';
import 'package:onlymens/utilis/size_config.dart';

Widget bottomAppBar({
  required String currentRoute,
  required VoidCallback onAiPressed,
  required VoidCallback onHomePressed,
  required VoidCallback onChatPressed,
}) {
  return BottomAppBar(
    shape: const CircularNotchedRectangle(),
    color: AppColors.surface,
    notchMargin: 3,
    height: 55.h,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // AI Model Button (Left)
        IconButton(
          onPressed: onAiPressed,
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedAiBrain03,

            color: currentRoute == '/aimodel'
                ? AppColors.primary
                : Colors.white,
          ),
        ),

        // Better with Bro Button (Right)
        IconButton(
          onPressed: onChatPressed,
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedAgreement01,
            color: currentRoute == '/bwb' ? AppColors.primary : Colors.white,
            size: 30,
          ),
        ),
      ],
    ),
  );
}
