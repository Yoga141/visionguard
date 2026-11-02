import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/cv_constants.dart';
import '../application/reminder_controller.dart';
import '../domain/reminder.dart';

/// Lapisan pop-up pengingat (S-05) di atas seluruh aplikasi.
///
/// Dipasang lewat `MaterialApp.builder`. Pop-up muncul di **pojok kanan
/// bawah**, tidak modal, dan **tidak mengambil fokus keyboard** (USB-02):
/// seluruh isinya dibungkus [ExcludeFocus], sehingga ketikan pengguna tetap
/// masuk ke kolom yang sedang aktif.
class ReminderOverlay extends ConsumerWidget {
  const ReminderOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reminderControllerProvider);
    final active = s.active;
    return Stack(
      children: [
        child,
        if (active != null && s.popupVisible)
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: ExcludeFocus(
                child: ReminderPopup(key: ValueKey(active.shownAt), reminder: active),
              ),
            ),
          ),
      ],
    );
  }
}

class ReminderPopup extends ConsumerStatefulWidget {
  const ReminderPopup({super.key, required this.reminder});

  final ActiveReminder reminder;

  @override
  ConsumerState<ReminderPopup> createState() => _ReminderPopupState();
}

class _ReminderPopupState extends ConsumerState<ReminderPopup> {
  bool _choosingSnooze = false;

  ReminderController get _ctrl => ref.read(reminderControllerProvider.notifier);

  IconData _icon(ReminderType t) => switch (t) {
        ReminderType.rest => Icons.bedtime_outlined,
        ReminderType.distance => Icons.straighten,
        ReminderType.blink => Icons.remove_red_eye_outlined,
        ReminderType.rule202020 => Icons.landscape_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final r = widget.reminder;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: (width - 32).clamp(200, 360)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_icon(r.type), color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Pengingat: ${r.type.title}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 8),
              ..._body(r, theme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(ActiveReminder r, ThemeData theme) {
    switch (r.phase) {
      case ReminderPhase.prompt:
        return [
          Text(r.type.message),
          const SizedBox(height: 12),
          if (_choosingSnooze)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Tunda:'),
                for (final m in CvConstants.snoozeOptionsMin)
                  OutlinedButton(onPressed: () => _ctrl.snooze(m), child: Text('$m menit')),
                TextButton(
                    onPressed: () => setState(() => _choosingSnooze = false),
                    child: const Text('Batal')),
              ],
            )
          else
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                  onPressed: () => setState(() => _choosingSnooze = true),
                  child: const Text('Tunda')),
              const SizedBox(width: 8),
              FilledButton(
                // Tema memakai tombol lebar penuh; di dalam Row perlu lebar minimum.
                style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
                onPressed: _ctrl.acknowledge,
                child: const Text('Oke'),
              ),
            ]),
        ];
      case ReminderPhase.breakCountdown:
        final total = CvConstants.breakCountdown.inSeconds;
        return [
          Text(r.type.message),
          const SizedBox(height: 12),
          Text('${r.breakSecondsLeft} detik',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: 1 - r.breakSecondsLeft / total),
          if (r.verifyBreak) ...[
            const SizedBox(height: 8),
            Text('Palingkan pandangan dari layar; kamera memverifikasi istirahat.',
                style: theme.textTheme.bodySmall),
          ],
        ];
      case ReminderPhase.breakResult:
        final text = switch (r.breakVerified) {
          true => 'Istirahat terverifikasi. Timer 20-20-20 dimulai ulang.',
          false => 'Istirahat tidak terverifikasi (pandangan belum berpaling ≥ '
              '${CvConstants.breakVerifyMin.inSeconds} detik). Timer dimulai ulang.',
          null => 'Istirahat selesai. Timer 20-20-20 dimulai ulang.',
        };
        return [
          Text(text),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _ctrl.closeResult, child: const Text('Tutup')),
          ),
        ];
    }
  }
}
