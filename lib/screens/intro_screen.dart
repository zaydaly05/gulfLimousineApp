import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'login_screen.dart';
import '../widgets/language_picker.dart';
import '../l10n/locale_service.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _videoController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  Timer? _navigationTimer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // Video
    _videoController = VideoPlayerController.asset('assets/videos/intro.mp4');

    unawaited(_initializeVideo());

    // Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();

    // Navigate after 6 seconds
    _navigationTimer = Timer(const Duration(seconds: 6), _goToLogin);
  }

  Future<void> _initializeVideo() async {
    try {
      await _videoController.initialize().timeout(const Duration(seconds: 4));

      if (!mounted) return;

      await _videoController.setLooping(true);
      await _videoController.setVolume(0.0);
      await _videoController.play();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Intro video initialization error or timeout: $e');
    }
  }

  Future<void> _goToLogin() async {
    if (!mounted || _isNavigating) return;

    _isNavigating = true;

    _navigationTimer?.cancel();
    _navigationTimer = null;

    try {
      if (_videoController.value.isInitialized) {
        await _videoController.pause();
      }
    } catch (e) {
      debugPrint('Video pause error: $e');
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();

    try {
      if (_videoController.value.isInitialized) {
        unawaited(_videoController.pause());
      }
    } catch (_) {}

    unawaited(_videoController.dispose());
    _fadeController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background video
          SizedBox.expand(
            child: _videoController.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          // Dark luxury overlay
          Container(color: Colors.black.withValues(alpha: 0.55)),

          // Top action buttons: Language toggle + Skip
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const LanguageToggleButton(dark: true),
                TextButton(
                  onPressed: _goToLogin,
                  child: Text(
                    context.t('skip'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Center branding
          FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: Colors.orange,
                    size: 90,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.t('appNameFull'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t('luxuryRides'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
