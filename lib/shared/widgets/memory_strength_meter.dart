import 'package:flutter/material.dart';
import '../theme.dart';

/// Animated circular meter showing memory strength
class MemoryStrengthMeter extends StatelessWidget {
  final double strength;
  final double size;
  final bool showLabel;
  final String? label;

  const MemoryStrengthMeter({
    super.key,
    required this.strength,
    this.size = 60,
    this.showLabel = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getStrengthColor(strength);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: size * 0.1,
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: AlwaysStoppedAnimation(
                    AppTheme.surfaceLight,
                  ),
                ),
              ),
              // Progress circle
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: strength),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: size * 0.1,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeCap: StrokeCap.round,
                    ),
                  );
                },
              ),
              // Center text
              Text(
                '${(strength * 100).toInt()}%',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 8),
          Text(
            label ?? _getStrengthLabel(strength),
            style: AppTheme.bodySmall.copyWith(color: color),
          ),
        ],
      ],
    );
  }

  String _getStrengthLabel(double s) {
    if (s >= 0.8) return 'Very Strong';
    if (s >= 0.6) return 'Strong';
    if (s >= 0.4) return 'Moderate';
    if (s >= 0.2) return 'Weak';
    return 'Fading';
  }
}

/// Horizontal bar showing memory strength
class MemoryStrengthBar extends StatelessWidget {
  final double strength;
  final double height;
  final bool showPercentage;

  const MemoryStrengthBar({
    super.key,
    required this.strength,
    this.height = 8,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getStrengthColor(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: strength),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withAlpha(180)],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(height: 4),
          Text(
            '${(strength * 100).toInt()}%',
            style: AppTheme.bodySmall.copyWith(color: color),
          ),
        ],
      ],
    );
  }
}
