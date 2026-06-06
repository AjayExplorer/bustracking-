import 'package:flutter/material.dart';
import 'package:bustracking/core/constants.dart';
import 'package:bustracking/models/stop.dart';

class RouteInfoPanel extends StatelessWidget {
  final String busName;
  final Stop? currentStop;
  final Stop? nextStop;
  final Stop? destinationStop;
  final double distanceRemaining; // in meters
  final double distanceToNext;    // in meters
  final double speed;             // in m/s
  final String status;
  final List<Stop> stops;
  final int segmentIndex;

  const RouteInfoPanel({
    super.key,
    required this.busName,
    required this.currentStop,
    required this.nextStop,
    required this.destinationStop,
    required this.distanceRemaining,
    required this.distanceToNext,
    required this.speed,
    required this.status,
    required this.stops,
    required this.segmentIndex,
  });

  // Utility to format distance
  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  // Utility to format seconds into readable time
  String _formatEta(double seconds) {
    if (seconds <= 0) return '0 mins';
    final minutes = (seconds / 60).round();
    if (minutes < 1) return 'Under 1 min';
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      if (remainingMins == 0) return '$hours hr${hours > 1 ? 's' : ''}';
      return '$hours hr $remainingMins min${remainingMins > 1 ? 's' : ''}';
    }
    return '$minutes min${minutes > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine ETA speed fallback
    final isStationary = speed < 1.0;
    final calculationSpeed = isStationary ? AppConstants.fallbackSpeed : speed;

    final nextStopEtaSec = distanceToNext / calculationSpeed;
    final destEtaSec = distanceRemaining / calculationSpeed;

    // Status Badge Styling
    Color statusColor;
    switch (status) {
      case 'Reached Destination':
        statusColor = AppConstants.success;
        break;
      case 'Running':
        statusColor = AppConstants.info;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkBg : AppConstants.lightCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Bus Name and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                busName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppConstants.darkText : AppConstants.lightText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Text(
                  status,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stepper: Visual representation of stops passed
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                final isPassed = index <= segmentIndex;
                final isNext = index == segmentIndex + 1;
                
                Color nodeColor;
                if (isNext) {
                  nodeColor = AppConstants.accentColor;
                } else if (isPassed) {
                  nodeColor = AppConstants.primaryColor;
                } else {
                  nodeColor = isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1);
                }

                return Row(
                  children: [
                    // Node
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: nodeColor,
                            border: Border.all(
                              color: isDark ? AppConstants.darkBg : Colors.white,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: isPassed && !isNext
                                ? const Icon(Icons.check, size: 10, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stop.stopName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: isNext || (index == segmentIndex && status != 'Not Started')
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isNext 
                                ? AppConstants.accentColor 
                                : isPassed 
                                    ? (isDark ? AppConstants.darkText : AppConstants.lightText)
                                    : (isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted),
                          ),
                        ),
                      ],
                    ),
                    
                    // Connecting line (except for last node)
                    if (index < stops.length - 1)
                      Container(
                        width: 50,
                        height: 3,
                        color: index < segmentIndex 
                            ? AppConstants.primaryColor 
                            : isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Primary metrics cards (ETA, Distance remaining)
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'ETA to Next Stop',
                  value: _formatEta(nextStopEtaSec),
                  detail: nextStop != null ? 'Next: ${nextStop!.stopName}' : 'Reached',
                  icon: Icons.timer_outlined,
                  iconColor: AppConstants.accentColor,
                  isStationary: isStationary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'To Destination',
                  value: _formatEta(destEtaSec),
                  detail: destinationStop != null ? 'Dest: ${destinationStop!.stopName}' : 'Reached',
                  icon: Icons.flag_outlined,
                  iconColor: AppConstants.success,
                  isStationary: isStationary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Auxiliary stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppConstants.darkCard : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAuxStat(
                  theme: theme,
                  isDark: isDark,
                  label: 'Distance Remaining',
                  value: _formatDistance(distanceRemaining),
                ),
                _buildAuxStat(
                  theme: theme,
                  isDark: isDark,
                  label: 'Distance to Next',
                  value: _formatDistance(distanceToNext),
                ),
                _buildAuxStat(
                  theme: theme,
                  isDark: isDark,
                  label: 'Current Speed',
                  value: '${(speed * 3.6).toStringAsFixed(1)} km/h',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required String value,
    required String detail,
    required IconData icon,
    required Color iconColor,
    required bool isStationary,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppConstants.darkText : AppConstants.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
                  ),
                ),
              ),
              if (isStationary)
                const Tooltip(
                  message: 'Estimated using standard speed while stationary.',
                  child: Icon(Icons.info_outline_rounded, size: 12, color: Colors.amber),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuxStat({
    required ThemeData theme,
    required bool isDark,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: isDark ? AppConstants.darkTextMuted : AppConstants.lightTextMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppConstants.darkText : AppConstants.lightText,
          ),
        ),
      ],
    );
  }
}
