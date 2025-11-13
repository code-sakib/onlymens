import 'package:flutter/widgets.dart';
import 'dart:math' as math;

class SizeConfig {
  // Screen dims
  static double screenWidth = 360;
  static double screenHeight = 800;

  // 1% units
  static double blockWidth = 3.6;
  static double blockHeight = 8.0;

  // Icons & sizes
  static double iconMedium = 16;
  static double iconLarge = 56;
  static double fireIconSize = 24;
  static double mediumButtonSize = 48;

  // Paddings
  static double paddingSmall = 8;
  static double paddingMedium = 16;
  static double paddingLarge = 24;
  static double screenVPadding = 12;
  static double screenHPadding = 16;

  // Defaults for spacing
  static double defaultHeight1 = 12;
  static double defaultHeight2 = 8;

  // tiles etc
  static double defaultTileHeight = 80;

  // call once per screen (idempotent)
  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    screenWidth = mq.size.width;
    screenHeight = mq.size.height;

    // avoid zero division / tiny screens
    blockWidth = math.max(1, screenWidth / 100);
    blockHeight = math.max(1, screenHeight / 100);

    // sensible mapping: keep most sizes relative to screen height
    iconMedium = blockHeight * 2.4; // ~2.4% of screen
    iconLarge = blockHeight * 6.5;

    fireIconSize = blockHeight * 3.2;
    mediumButtonSize = blockHeight * 5.0;

    paddingSmall = blockHeight * 1.2;
    paddingMedium = blockHeight * 3.0;
    paddingLarge = blockHeight * 5.0;
    screenVPadding = blockHeight * 1.5;
    screenHPadding = blockWidth * 4;

    defaultHeight1 = blockHeight * 5.5;
    defaultHeight2 = blockHeight * 2.5;
    defaultTileHeight = blockHeight * 9;
  }

  // helpful helper to clamp heights (avoid overflow)
  static double clampHeight(double fractionOfScreen,
      {double min = 48, double max = double.infinity}) {
    final val = screenHeight * fractionOfScreen;
    return math.min(math.max(val, min), max);
  }
}
