import 'package:flutter/material.dart';
import 'package:bustracking/core/constants.dart';
import 'package:bustracking/screens/driver/driver_dashboard.dart';
import 'package:bustracking/screens/student/student_dashboard.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppConstants.darkBg, const Color(0xFF1E1E38)]
                : [const Color(0xFFEEF2F6), const Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Animated Logo Circle
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ],
                        border: Border.all(
                          color: AppConstants.primaryColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_bus_filled_rounded,
                          size: 64,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App Title
                    Text(
                      'Bus Tracker',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppConstants.darkText : AppConstants.lightText,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Real-time GPS tracking for students and drivers',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Large Button Cards
                    _buildRoleCard(
                      context: context,
                      title: 'Student Mode',
                      subtitle: 'Track your school bus live, view ETAs and routes.',
                      icon: Icons.school_rounded,
                      color: AppConstants.primaryColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StudentDashboard()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    _buildRoleCard(
                      context: context,
                      title: 'Driver Mode',
                      subtitle: 'Stream coordinates from your device\'s GPS.',
                      icon: Icons.drive_eta_rounded,
                      color: AppConstants.accentColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DriverDashboard()),
                        );
                      },
                    ),
                    const SizedBox(height: 48),

                    // Bottom info label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 14,
                          color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'No login required • Free & open access',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              // Icon Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),

              // Description Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppConstants.darkText : AppConstants.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
