import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login.dart';

class WelcomeActionPage extends StatelessWidget {
  const WelcomeActionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: WelcomeActionContent(),
      ),
    );
  }
}

class WelcomeActionContent extends StatelessWidget {
  const WelcomeActionContent({super.key});

  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);
  static const String secondWelcomeImagePath = 'assets/images/welcome2.png';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double topInset = MediaQuery.of(context).padding.top;
        final bool compact = constraints.maxWidth < 370;
        final double cardTop = topInset + (compact ? 72 : 88);

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.white),
            // Card and text at the top (existing content remains)
            // Image at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Image.asset(
                  secondWelcomeImagePath,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFEFF6FF),
                      alignment: Alignment.center,
                      child: Text(
                        'Image not found:\n$secondWelcomeImagePath',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: navy.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: cardTop,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x22005792)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Built for safer school journeys',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: navy,
                            fontSize: compact ? 19 : 21,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Live routing  •  Child safety  •  Instant alerts',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: blue.withValues(alpha: 0.92),
                            fontSize: compact ? 14 : 15,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Let's Get Started",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
