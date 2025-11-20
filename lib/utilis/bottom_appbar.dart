// Updated bottom_appbar.dart for cleaner 3-button layout

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:cleanmind/core/apptheme.dart';

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
        SizedBox(
          width: 40.w,
          height: 40.h,
          child: IconButton(
            onPressed: onAiPressed,
            padding: EdgeInsets.zero,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedAiBrain03,
              size: 20.sp, // smaller + clean
              color: currentRoute == '/aimodel'
                  ? AppColors.primary
                  : Colors.white,
            ),
          ),
        ),

        // Better with Bro Button (Right)
        SizedBox(
          width: 40.w,
          height: 40.h,
          child: IconButton(
            onPressed: onChatPressed,
            padding: EdgeInsets.zero,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedAgreement01,
              size: 20.sp, // smaller + clean
              color: currentRoute == '/bwb' ? AppColors.primary : Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
