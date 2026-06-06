import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bustracking/core/constants.dart';
import 'package:bustracking/models/bus.dart';
import 'package:bustracking/providers/bus_provider.dart';
import 'package:bustracking/services/location_service.dart';

// Local provider for driver current location telemetry
final driverTelemetryProvider = StateProvider<SimPosition?>((ref) => null);

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final busesAsync = ref.watch(busesProvider);
    final selectedBusId = ref.watch(selectedBusIdProvider);
    final isTrackingActive = ref.watch(driverTrackingActiveProvider);
    final isSimulationMode = ref.watch(driverSimulationActiveProvider);
    final telemetry = ref.watch(driverTelemetryProvider);
    
    // Connectivity monitoring
    final connectivityAsync = ref.watch(connectivityStreamProvider);
    final isOnline = connectivityAsync.value ?? true;

    // Listen to GPS / Simulation telemetry stream updates and send them to the API
    ref.listen<AsyncValue<SimPosition>>(driverLocationStreamProvider, (prev, next) {
      next.whenOrNull(data: (position) async {
        final busId = ref.read(selectedBusIdProvider);
        if (busId != null && ref.read(driverTrackingActiveProvider)) {
          // Push update to the API
          final success = await ref.read(apiServiceProvider).updateLocation(
            busId: busId,
            latitude: position.latitude,
            longitude: position.longitude,
            speed: position.speed,
          );

          if (success) {
            ref.read(driverTelemetryProvider.notifier).state = position;
          } else {
            debugPrint("Failed to upload telemetry update");
          }
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
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
        child: Column(
          children: [
            // Offline Notification Banner
            if (!isOnline)
              Container(
                color: AppConstants.danger,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'You are offline. Telemetry won\'t upload.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card 1: Configuration Selection
                        _buildSectionCard(
                          theme: theme,
                          isDark: isDark,
                          title: 'Tracking Configuration',
                          icon: Icons.settings_applications_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Dropdown
                              busesAsync.when(
                                data: (buses) {
                                  if (buses.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Text("No buses configured on backend D1."),
                                    );
                                  }
                                  final selectedBus = buses.any((b) => b.id == selectedBusId)
                                      ? buses.firstWhere((b) => b.id == selectedBusId)
                                      : null;
                                  return DropdownButtonFormField<Bus>(
                                    initialValue: selectedBus,
                                    decoration: InputDecoration(
                                      labelText: 'Select Bus',
                                      prefixIcon: const Icon(Icons.directions_bus_rounded),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    disabledHint: Text(selectedBus?.name ?? "Select Bus"),
                                    items: buses.map((bus) {
                                      return DropdownMenuItem<Bus>(
                                        value: bus,
                                        child: Text(bus.name),
                                      );
                                    }).toList(),
                                    onChanged: isTrackingActive
                                        ? null // lock while tracking
                                        : (Bus? bus) {
                                            if (bus != null) {
                                              ref.read(selectedBusIdProvider.notifier).state = bus.id;
                                            }
                                          },
                                  );
                                },
                                error: (err, stack) => Text("Error loading buses: $err", style: const TextStyle(color: AppConstants.danger)),
                                loading: () => const Center(child: CircularProgressIndicator()),
                              ),
                              const SizedBox(height: 20),

                              // Simulation Toggle
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Simulation Mode'),
                                subtitle: const Text('Emits simulated route coordinates without GPS hardware.'),
                                value: isSimulationMode,
                                onChanged: isTrackingActive
                                    ? null // lock while tracking
                                    : (val) {
                                        ref.read(driverSimulationActiveProvider.notifier).state = val;
                                      },
                                secondary: Icon(
                                  Icons.route_rounded,
                                  color: isSimulationMode ? AppConstants.primaryColor : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Card 2: Status & Telemetry
                        _buildSectionCard(
                          theme: theme,
                          isDark: isDark,
                          title: 'Live Telemetry',
                          icon: Icons.speed_rounded,
                          child: Column(
                            children: [
                              _buildTelemetryRow(
                                label: 'Status',
                                value: isTrackingActive 
                                    ? (isSimulationMode ? 'Active (Simulated)' : 'Active (GPS)') 
                                    : 'Inactive',
                                icon: Icons.radar_rounded,
                                iconColor: isTrackingActive ? AppConstants.success : Colors.grey,
                                pulsing: isTrackingActive,
                              ),
                              const Divider(height: 24),
                              _buildTelemetryRow(
                                label: 'Latitude',
                                value: telemetry != null
                                    ? telemetry.latitude.toStringAsFixed(6)
                                    : '—',
                                icon: Icons.explore_rounded,
                                iconColor: AppConstants.primaryColor,
                              ),
                              const Divider(height: 24),
                              _buildTelemetryRow(
                                label: 'Longitude',
                                value: telemetry != null
                                    ? telemetry.longitude.toStringAsFixed(6)
                                    : '—',
                                icon: Icons.explore_rounded,
                                iconColor: AppConstants.primaryColor,
                              ),
                              const Divider(height: 24),
                              _buildTelemetryRow(
                                label: 'Current Speed',
                                value: telemetry != null
                                    ? '${(telemetry.speed * 3.6).toStringAsFixed(1)} km/h'
                                    : '—',
                                icon: Icons.speed_rounded,
                                iconColor: AppConstants.accentColor,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Start/Stop Control Button
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isTrackingActive
                              ? _buildControlButton(
                                  label: 'Stop Tracking',
                                  icon: Icons.stop_rounded,
                                  color: AppConstants.danger,
                                  onPressed: () => _handleStopTracking(),
                                )
                              : _buildControlButton(
                                  label: 'Start Tracking',
                                  icon: Icons.play_arrow_rounded,
                                  color: AppConstants.success,
                                  onPressed: selectedBusId != null ? () => _handleStartTracking() : null,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleStartTracking() async {
    final simulate = ref.read(driverSimulationActiveProvider);
    
    try {
      ref.read(driverTelemetryProvider.notifier).state = null; // Clear old telemetry
      ref.read(driverTrackingActiveProvider.notifier).state = true;
      
      await ref.read(locationServiceProvider).startTracking(simulate: simulate);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(simulate ? 'Started Simulated Route Tracking' : 'Started Live GPS Tracking'),
            backgroundColor: AppConstants.success,
          ),
        );
      }
    } catch (e) {
      ref.read(driverTrackingActiveProvider.notifier).state = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start tracking: $e'),
            backgroundColor: AppConstants.danger,
          ),
        );
      }
    }
  }

  void _handleStopTracking() {
    ref.read(locationServiceProvider).stopTracking();
    ref.read(driverTrackingActiveProvider.notifier).state = false;
    ref.read(driverTelemetryProvider.notifier).state = null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tracking stopped'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppConstants.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppConstants.darkText : AppConstants.lightText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTelemetryRow({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    bool pulsing = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pulsing)
              const _PulsingIndicator(color: AppConstants.success),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppConstants.darkText : AppConstants.lightText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: onPressed != null ? 4 : 0,
        shadowColor: color.withValues(alpha: 0.4),
      ),
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      onPressed: onPressed,
    );
  }
}

class _PulsingIndicator extends StatefulWidget {
  final Color color;
  const _PulsingIndicator({required this.color});

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          height: 10,
          width: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.3 + 0.7 * _controller.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 * _controller.value),
                blurRadius: 4,
                spreadRadius: 1,
              )
            ],
          ),
        );
      },
    );
  }
}
