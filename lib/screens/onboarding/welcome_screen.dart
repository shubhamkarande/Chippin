import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../groups/groups_list_screen.dart';
import '../../state/providers.dart';

/// Welcome screen with sign up, login, and guest options.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E1B4B),
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE0E7FF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Hero section
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Illustration
                      Container(
                        width: size.width * 0.7,
                        height: size.width * 0.5,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Background circles
                            Positioned(
                              left: 20,
                              top: 20,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ).animate(
                                onPlay: (c) => c.repeat(),
                              ).scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.2, 1.2),
                                duration: const Duration(seconds: 2),
                              ),
                            ),
                            Positioned(
                              right: 30,
                              bottom: 30,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ).animate(
                                onPlay: (c) => c.repeat(),
                              ).scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.3, 1.3),
                                duration: const Duration(seconds: 3),
                              ),
                            ),
                            // Money emoji
                            const Text(
                              '💰',
                              style: TextStyle(fontSize: 80),
                            )
                                .animate()
                                .fadeIn()
                                .scale(curve: Curves.elasticOut)
                                .then()
                                .animate(onPlay: (c) => c.repeat())
                                .shimmer(
                                  duration: const Duration(seconds: 2),
                                  color: Colors.white.withOpacity(0.3),
                                ),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: -0.2, end: 0),

                      const SizedBox(height: 48),

                      // App name
                      Text(
                        'Chippin',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                          letterSpacing: -1,
                        ),
                      )
                          .animate(delay: const Duration(milliseconds: 200))
                          .fadeIn()
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 12),

                      // Tagline
                      Text(
                        'Split expenses fairly, instantly,\nand stress-free.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                          height: 1.5,
                        ),
                      )
                          .animate(delay: const Duration(milliseconds: 400))
                          .fadeIn()
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 24),

                      // Features
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _FeatureChip(
                            icon: '📷',
                            label: 'Scan Receipts',
                            delay: 500,
                          ),
                          _FeatureChip(
                            icon: '⚡',
                            label: 'Offline-First',
                            delay: 600,
                          ),
                          _FeatureChip(
                            icon: '🔄',
                            label: 'Auto Sync',
                            delay: 700,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Buttons section
                Column(
                  children: [
                    // Sign Up button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                        .animate(delay: const Duration(milliseconds: 800))
                        .fadeIn()
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 12),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: BorderSide(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'I already have an account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                        .animate(delay: const Duration(milliseconds: 900))
                        .fadeIn()
                        .slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 20),

                    // Guest mode
                    TextButton(
                      onPressed: () => _continueAsGuest(context, ref),
                      child: Text(
                        'Continue without account',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.lightTextSecondary,
                        ),
                      ),
                    )
                        .animate(delay: const Duration(milliseconds: 1000))
                        .fadeIn(),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _continueAsGuest(BuildContext context, WidgetRef ref) async {
    await ref.read(authStateProvider.notifier).continueAsGuest();

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GroupsListScreen()),
      );
    }
  }
}

class _FeatureChip extends StatelessWidget {
  final String icon;
  final String label;
  final int delay;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn().scale();
  }
}
