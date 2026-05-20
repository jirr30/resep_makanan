import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/recipe.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  const CookingModeScreen({super.key, required this.recipe});

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  int _step = 0;
  int _remaining = 0;
  bool _timerRunning = false;
  Timer? _timer;
  late PageController _pageCtrl;
  final _notif = NotificationService();

  @override
  void initState() {
    super.initState();
    _remaining = widget.recipe.cookingTime * 60;
    _pageCtrl = PageController();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) {
        _timer?.cancel();
        setState(() => _timerRunning = false);
        _notif.showTimerDone(widget.recipe.title);
      } else {
        setState(() => _remaining--);
      }
    });
    setState(() => _timerRunning = true);
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _timerRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remaining = widget.recipe.cookingTime * 60;
      _timerRunning = false;
    });
  }

  String _formatTime(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<bool> _onWillPop() async {
    if (!_timerRunning) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari Mode Memasak?'),
        content: const Text('Timer sedang berjalan. Yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Lanjutkan')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final steps   = widget.recipe.steps;
    final isFirst = _step == 0;
    final isLast  = _step == steps.length - 1;
    final progress = (_step + 1) / steps.length;
    final timerDone = _remaining == 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _onWillPop();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () async {
                      final leave = await _onWillPop();
                      if (leave && context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  Expanded(child: Text(
                    widget.recipe.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  )),
                  // Timer mini
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: timerDone ? Colors.green : _timerRunning ? AppTheme.primary : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.timer, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(_formatTime(_remaining), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ]),
                  ),
                ]),
              ),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Langkah ${_step + 1} dari ${steps.length}',
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    Text('${(progress * 100).round()}%',
                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      color: AppTheme.primary,
                      minHeight: 6,
                    ),
                  ),
                ]),
              ),

              // Step content
              Expanded(
                child: PageView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: steps.length,
                  controller: _pageCtrl,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          steps[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Timer controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white60, size: 28), onPressed: _resetTimer),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: timerDone ? null : (_timerRunning ? _pauseTimer : _startTimer),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: timerDone ? Colors.green : AppTheme.primary,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(timerDone ? Icons.check : (_timerRunning ? Icons.pause : Icons.play_arrow), color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(timerDone ? 'Selesai!' : (_timerRunning ? 'Jeda' : 'Mulai Timer'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    ),
                  ),
                ]),
              ),

              // Navigation buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: isFirst ? null : () {
                      setState(() => _step--);
                      _pageCtrl.animateToPage(_step,
                          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Sebelumnya'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: isLast
                        ? () => Navigator.of(context).pop()
                        : () {
                            setState(() => _step++);
                            _pageCtrl.animateToPage(_step,
                                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                          },
                    icon: Icon(isLast ? Icons.check_circle : Icons.arrow_forward),
                    label: Text(isLast ? 'Selesai!' : 'Selanjutnya'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  )),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
