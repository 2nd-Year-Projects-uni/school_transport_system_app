import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'welcome_action_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late final PageController _pageController;

  static const Color navy = Color(0xFF001F3F);
  static const Color lightNavy = Color(0xFF2C4F78);
  static const Color lighterNavy = Color(0xFF3F648E);
  static const Color blue = Color(0xFF005792);
  static const Color teal = Color(0xFF00B894);
  static const String firstWelcomeImagePath =
      'assets/images/welcome_school_bus.png';

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.96);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
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
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              children: const [
                Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: _FirstWelcomeContent(),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: WelcomeActionContent(),
                ),
              ],
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.47),
                child: _SwipeIndicators(controller: _pageController),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeIndicators extends StatelessWidget {
  const _SwipeIndicators({required this.controller});

  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final double page = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();
        final double fade = (1 - page).clamp(0.0, 1.0);

        return Opacity(
          opacity: fade,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProgressDot(progress: (1 - (page - 0).abs()).clamp(0.0, 1.0)),
              const SizedBox(width: 8),
              _ProgressDot(progress: (1 - (page - 1).abs()).clamp(0.0, 1.0)),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final double width = 18 + (30 - 18) * progress;

    return Container(
      width: width,
      height: 8.5,
      decoration: BoxDecoration(
        color: _WelcomePageState.lighterNavy,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _FirstWelcomeContent extends StatelessWidget {
  const _FirstWelcomeContent();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double topInset = MediaQuery.of(context).padding.top;
        final double titleTop = topInset + constraints.maxHeight * 0.12;
        final double titleSize = constraints.maxWidth < 370 ? 42 : 46;

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.white),
            Positioned.fill(
              child: Image.asset(
                _WelcomePageState.firstWelcomeImagePath,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFEFF6FF),
                    alignment: Alignment.center,
                    child: Text(
                      'Image not found:\n${_WelcomePageState.firstWelcomeImagePath}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _WelcomePageState.navy.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: titleTop,
              child: Center(
                child: Text(
                  'Ride Safe',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: _WelcomePageState.lightNavy,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.48),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
