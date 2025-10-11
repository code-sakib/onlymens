import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PongGame extends StatefulWidget {
  const PongGame({super.key});

  @override
  State<PongGame> createState() => _PongGameState();
}

class _PongGameState extends State<PongGame>
    with SingleTickerProviderStateMixin {
  static const double paddleWidth = 100, paddleHeight = 15, ballSize = 15;
  static const Color accent = Colors.deepPurple;

  late double ballX, ballY, ballDX, ballDY;
  late double playerX, aiX;
  bool isPlaying = false;
  bool isBouncing = false;
  late Timer gameTimer;
  List<ConfettiParticle> particles = [];

  int playerScore = 0;
  int aiScore = 0;

  final Random random = Random();

  @override
  void initState() {
    super.initState();
    resetGame();
  }

  void resetGame() {
    ballX = 0;
    ballY = 0;
    ballDX = 0.015;
    ballDY = 0.02;
    playerX = 0;
    aiX = 0;
    particles.clear();
    isBouncing = false;
    isPlaying = false;
  }

  void startGame() {
    isPlaying = true;
    gameTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      moveBall();
      moveAI();
      updateParticles();
    });
  }

  void moveBall() {
    setState(() {
      ballX += ballDX;
      ballY += ballDY;

      // Bounce from side walls
      if (ballX <= -1 || ballX >= 1) {
        ballDX = -ballDX;
        triggerBounceEffect();
      }

      // Bounce from top (AI)
      if (ballY <= -0.9 &&
          (ballX - aiX).abs() < paddleWidth / 300 &&
          ballDY < 0) {
        ballDY = -ballDY;
        triggerBounceEffect();
      }

      // Bounce from bottom (player)
      if (ballY >= 0.9 &&
          (ballX - playerX).abs() < paddleWidth / 300 &&
          ballDY > 0) {
        ballDY = -ballDY;
        triggerBounceEffect();
      }

      // Game over if ball goes out
      if (ballY.abs() > 1.2) {
        gameTimer.cancel();

        // Update scores based on who lost
        if (ballY > 1.2) {
          // Ball went past player - AI scores
          aiScore++;
        } else {
          // Ball went past AI - Player scores
          playerScore++;
        }

        resetGame();
      }
    });
  }

  void moveAI() {
    if (aiX < ballX) {
      aiX += 0.015;
    } else {
      aiX -= 0.015;
    }
  }

  void triggerBounceEffect() {
    setState(() => isBouncing = true);
    spawnParticles();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => isBouncing = false);
    });
  }

  void spawnParticles() {
    for (int i = 0; i < 12; i++) {
      particles.add(
        ConfettiParticle(
          x: ballX,
          y: ballY,
          dx: (random.nextDouble() - 0.5) * 0.06,
          dy: (random.nextDouble() - 0.5) * 0.06,
          lifetime: 30 + random.nextInt(20),
          color: accent.withOpacity(0.7 + random.nextDouble() * 0.3),
        ),
      );
    }
  }

  void updateParticles() {
    setState(() {
      particles.removeWhere((p) => p.lifetime <= 0);
      for (var p in particles) {
        p.x += p.dx;
        p.y += p.dy;
        p.lifetime--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Back button
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => context.pop(),
            ),
          ),

          // Score display
          Positioned(
            top: 16,
            right: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$aiScore - $playerScore",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),

          GestureDetector(
            onTap: () {
              if (!isPlaying) startGame();
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                playerX +=
                    details.delta.dx / MediaQuery.of(context).size.width * 2;
                playerX = playerX.clamp(-1.0, 1.0);
              });
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Confetti Particles
                    ...particles.map((p) {
                      return Positioned(
                        top: height / 2 + p.y * height / 2,
                        left: width / 2 + p.x * width / 2,
                        child: Opacity(
                          opacity: (p.lifetime / 40).clamp(0.0, 1.0),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: p.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: p.color.withOpacity(0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Ball
                    Positioned(
                      top: height / 2 + ballY * height / 2 - ballSize / 2,
                      left: width / 2 + ballX * width / 2 - ballSize / 2,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: ballSize,
                        height: ballSize,
                        decoration: BoxDecoration(
                          color: isBouncing ? accent : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: isBouncing
                              ? [
                                  BoxShadow(
                                    color: accent.withOpacity(0.7),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : [],
                        ),
                      ),
                    ),

                    // Player Paddle
                    Positioned(
                      bottom: 40,
                      left: width / 2 + playerX * width / 2 - paddleWidth / 2,
                      child: Container(
                        width: paddleWidth,
                        height: paddleHeight,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    // AI Paddle
                    Positioned(
                      top: 40,
                      left: width / 2 + aiX * width / 2 - paddleWidth / 2,
                      child: Container(
                        width: paddleWidth,
                        height: paddleHeight,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    // Tap hint
                    if (!isPlaying)
                      const Center(
                        child: Text(
                          "Tap to Start",
                          style: TextStyle(color: Colors.white54, fontSize: 20),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ConfettiParticle {
  double x, y, dx, dy;
  int lifetime;
  final Color color;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.lifetime,
    required this.color,
  });
}

class QuickDrawGame extends StatefulWidget {
  const QuickDrawGame({super.key});

  @override
  State<QuickDrawGame> createState() => _QuickDrawGameState();
}

class _QuickDrawGameState extends State<QuickDrawGame> {
  static const Color accent = Colors.deepPurple;
  static const double targetSize = 80;

  int playerScore = 0;
  int aiScore = 0;

  bool isPlaying = false;
  bool showTarget = false;
  bool roundOver = false;

  double targetX = 0;
  double targetY = 0;

  String statusMessage = "Tap to Start";
  Color statusColor = Colors.white54;

  late Timer countdownTimer;
  late Timer aiReactionTimer;

  final Random random = Random();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    if (isPlaying) {
      if (countdownTimer.isActive) countdownTimer.cancel();
      if (aiReactionTimer.isActive) aiReactionTimer.cancel();
    }
    super.dispose();
  }

  void stopGame() {
    if (isPlaying) {
      if (countdownTimer.isActive) countdownTimer.cancel();
      if (aiReactionTimer.isActive) aiReactionTimer.cancel();
      setState(() {
        isPlaying = false;
      });
    }
  }

  void startGame() {
    setState(() {
      isPlaying = true;
      statusMessage = "Get Ready...";
      statusColor = Colors.orange;
    });

    startRound();
  }

  void startRound() {
    setState(() {
      showTarget = false;
      roundOver = false;
    });

    // Random delay before showing target (1-3 seconds)
    int delayMs = 1000 + random.nextInt(2000);

    countdownTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;

      setState(() {
        showTarget = true;
        statusMessage = "TAP NOW!";
        statusColor = Colors.green;

        // Random target position
        targetX = random.nextDouble() * 1.4 - 0.7;
        targetY = random.nextDouble() * 1.2 - 0.6;
      });

      // AI reaction time (200-600ms after target appears)
      int aiDelay = 200 + random.nextInt(400);
      aiReactionTimer = Timer(Duration(milliseconds: aiDelay), () {
        if (!mounted || roundOver) return;
        aiTapsTarget();
      });
    });
  }

  void playerTapsTarget() {
    if (!showTarget || roundOver) return;

    setState(() {
      roundOver = true;
      playerScore++;
      statusMessage = "You Win!";
      statusColor = Colors.green;
      showTarget = false;
    });

    if (aiReactionTimer.isActive) {
      aiReactionTimer.cancel();
    }

    // Start next round
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && isPlaying) startRound();
    });
  }

  void aiTapsTarget() {
    if (roundOver) return;

    setState(() {
      roundOver = true;
      aiScore++;
      statusMessage = "AI Wins!";
      statusColor = Colors.red;
      showTarget = false;
    });

    // Start next round
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && isPlaying) startRound();
    });
  }

  void onTapOutside() {
    // Player tapped too early or missed
    if (isPlaying && !showTarget && !roundOver) {
      setState(() {
        statusMessage = "Too Early!";
        statusColor = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Back button
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () {
                stopGame();
                context.pop();
              },
            ),
          ),
      
          // Score display
          Positioned(
            top: 16,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$aiScore - $playerScore",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          ),
      
          // Main game area
          GestureDetector(
            onTap: () {
              if (!isPlaying) {
                startGame();
              } else {
                onTapOutside();
              }
            },
            child: Container(
              color: Colors.transparent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
      
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Target (appears randomly)
                      if (showTarget)
                        Positioned(
                          top:
                              height / 2 +
                              targetY * height / 2 -
                              targetSize / 2,
                          left:
                              width / 2 +
                              targetX * width / 2 -
                              targetSize / 2,
                          child: GestureDetector(
                            onTap: playerTapsTarget,
                            child: TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 200),
                              builder: (context, double value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    width: targetSize,
                                    height: targetSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent.withOpacity(0.6),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.circle,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
      
                      // Status message
                      Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: isPlaying ? 28 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                          child: Text(statusMessage),
                        ),
                      ),
      
                      // Instructions at bottom
                      if (!isPlaying)
                        const Positioned(
                          bottom: 40,
                          left: 0,
                          right: 0,
                          child: Text(
                            "Tap the target when it appears!\nBeat the AI's reaction time!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
