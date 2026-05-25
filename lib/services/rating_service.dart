import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RatingService {
  static const _keyLaunchCount = 'app_launch_count';
  static const _keyInstallDate = 'install_date';
  static const _keyDismissedForever = 'rating_dismissed_forever';
  static const _keyLastAsked = 'rating_last_asked';
  static const _keyCompleted = 'rating_completed';
  static const _keyActionCount = 'rating_action_count';

  static const _minLaunches = 5;
  static const _minDaysSinceInstall = 3;
  static const _minActions = 1;
  static const _daysBetweenPrompts = 7;

  static Future<void> incrementLaunchCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLaunchCount, (prefs.getInt(_keyLaunchCount) ?? 0) + 1);
    if (!prefs.containsKey(_keyInstallDate)) {
      await prefs.setInt(_keyInstallDate, DateTime.now().millisecondsSinceEpoch);
    }
  }

  static Future<void> _recordPositiveAction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyActionCount, (prefs.getInt(_keyActionCount) ?? 0) + 1);
  }

  static Future<bool> _canShow() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyCompleted) == true) return false;
    if (prefs.getBool(_keyDismissedForever) == true) return false;
    if ((prefs.getInt(_keyLaunchCount) ?? 0) < _minLaunches) return false;
    if ((prefs.getInt(_keyActionCount) ?? 0) < _minActions) return false;

    final installMs = prefs.getInt(_keyInstallDate);
    if (installMs != null) {
      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(installMs))
          .inDays;
      if (days < _minDaysSinceInstall) return false;
    }

    final lastMs = prefs.getInt(_keyLastAsked);
    if (lastMs != null) {
      final days = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
          .inDays;
      if (days < _daysBetweenPrompts) return false;
    }

    return true;
  }

  /// Records a meaningful user action and shows the soft rating prompt
  /// if all smart-trigger conditions are met.
  static Future<void> triggerAfterPositiveAction(BuildContext context) async {
    await _recordPositiveAction();
    if (!context.mounted) return;
    if (!await _canShow()) return;
    if (!context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastAsked, DateTime.now().millisecondsSinceEpoch);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RatingSheet(
        onRate: () async {
          Navigator.pop(ctx);
          await prefs.setBool(_keyCompleted, true);
          final review = InAppReview.instance;
          if (await review.isAvailable()) await review.requestReview();
        },
        onLater: () => Navigator.pop(ctx),
        onNever: () async {
          Navigator.pop(ctx);
          await prefs.setBool(_keyDismissedForever, true);
        },
      ),
    );
  }
}

class _RatingSheet extends StatelessWidget {
  final VoidCallback onRate;
  final VoidCallback onLater;
  final VoidCallback onNever;

  const _RatingSheet({
    required this.onRate,
    required this.onLater,
    required this.onNever,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text('⭐', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Suka ResepKu?',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Beri rating bintang 5 untuk mendukung pengembangan aplikasi ini!',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Beri Rating Sekarang',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onLater,
                  child: const Text('Nanti'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onNever,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                  ),
                  child: const Text('Jangan Tanya Lagi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
