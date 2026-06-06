import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bustracking/core/constants.dart';
import 'package:bustracking/models/bus.dart';
import 'package:bustracking/providers/bus_provider.dart';
import 'package:bustracking/screens/tracking/live_tracking_screen.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final busesAsync = ref.watch(busesProvider);
    final selectedBusId = ref.watch(selectedBusIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(busesProvider);
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppConstants.darkBg, const Color(0xFF1E293B)]
                : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon badge
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      size: 48,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header
                  Text(
                    'Track School Bus',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppConstants.darkText : AppConstants.lightText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Description
                  Text(
                    'Select your designated bus to begin viewing its real-time location and estimated arrival times.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Dropdown Card
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: busesAsync.when(
                      data: (buses) {
                        if (buses.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              "No buses available. Please ensure the backend server is running and seeded.",
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        final selectedBus = buses.any((b) => b.id == selectedBusId)
                            ? buses.firstWhere((b) => b.id == selectedBusId)
                            : null;
                        
                        return DropdownButtonFormField<Bus>(
                          initialValue: selectedBus,
                          decoration: InputDecoration(
                            labelText: 'Select School Bus',
                            prefixIcon: const Icon(Icons.directions_bus_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: buses.map((bus) {
                            return DropdownMenuItem<Bus>(
                              value: bus,
                              child: Text(bus.name),
                            );
                          }).toList(),
                          onChanged: (Bus? bus) {
                            if (bus != null) {
                              ref.read(selectedBusIdProvider.notifier).state = bus.id;
                            }
                          },
                        );
                      },
                      error: (err, stack) => Text("Error loading buses: $err", style: const TextStyle(color: AppConstants.danger)),
                      loading: () => const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Track Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppConstants.primaryColor.withValues(alpha: 0.4),
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: selectedBusId != null ? 4 : 0,
                    ),
                    icon: const Icon(Icons.near_me_rounded),
                    label: const Text(
                      'Track Bus Live',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: selectedBusId != null
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LiveTrackingScreen(busId: selectedBusId),
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
