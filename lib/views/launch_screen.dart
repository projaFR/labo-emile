import 'dart:math';
import 'package:flutter/material.dart';

/// Écran de lancement animé affiché au démarrage de l'app.
/// Se ferme automatiquement après l'animation (~2.5s).
class LaunchScreen extends StatefulWidget {
  final VoidCallback onDone;

  const LaunchScreen({super.key, required this.onDone});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _starsController;
  late AnimationController _textController;
  late AnimationController _exitController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _exitOpacity;

  final List<_StarData> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Génère 18 étoiles à positions aléatoires
    for (int i = 0; i < 18; i++) {
      _stars.add(
        _StarData(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: _random.nextDouble() * 14 + 6,
          delay: _random.nextDouble() * 0.6,
          emoji: ['⭐', '✨', '💎', '🌟'][_random.nextInt(4)],
        ),
      );
    }

    // Logo : pop in
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0, 0.4)),
    );

    // Étoiles : flottent en boucle
    _starsController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Texte : glisse depuis le bas
    _textController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(_textController);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Exit : fade out
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(_exitController);

    // Séquence
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    await _exitController.forward();
    widget.onDone();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _starsController.dispose();
    _textController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _exitOpacity,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1A237E), // Bleu nuit
                Color(0xFF283593),
                Color(0xFF1565C0),
                Color(0xFF0D47A1),
              ],
            ),
          ),
          child: Stack(
            children: [
              // ── Étoiles flottantes ─────────────────────────────────────
              ..._stars.map(
                (star) => AnimatedBuilder(
                  animation: _starsController,
                  builder: (context, _) {
                    final double dy =
                        sin((_starsController.value + star.delay) * pi) * 8;
                    return Positioned(
                      left: star.x * size.width,
                      top: star.y * size.height + dy,
                      child: Opacity(
                        opacity: 0.6 + _starsController.value * 0.4,
                        child: Text(
                          star.emoji,
                          style: TextStyle(fontSize: star.size),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Contenu centré ─────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo animé
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('🔬', style: TextStyle(fontSize: 60)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Titre animé
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            const Text(
                              "Labo d'Émile",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '✨ Apprends en t\'amusant !',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Indicateur de chargement
                    FadeTransition(
                      opacity: _textOpacity,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          3,
                          (i) => AnimatedBuilder(
                            animation: _starsController,
                            builder: (context, _) {
                              final double phase =
                                  (_starsController.value + i * 0.33) % 1.0;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                    0.3 + phase * 0.7,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarData {
  final double x, y, size, delay;
  final String emoji;
  const _StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
    required this.emoji,
  });
}
