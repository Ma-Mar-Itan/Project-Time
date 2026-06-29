import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utilities/duration_formatter.dart';
import '../../../../domain/models/project_view.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/providers/settings_provider.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/duration_display.dart';

/// Bottom sheet for adding or removing manual time. [isAddition] selects the
/// mode. Returns true if an adjustment was applied.
class AdjustTimeSheet extends ConsumerStatefulWidget {
  const AdjustTimeSheet({
    required this.project,
    required this.isAddition,
    super.key,
  });

  final ProjectView project;
  final bool isAddition;

  static Future<bool?> show(
    BuildContext context, {
    required ProjectView project,
    required bool isAddition,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AdjustTimeSheet(project: project, isAddition: isAddition),
    );
  }

  @override
  ConsumerState<AdjustTimeSheet> createState() => _AdjustTimeSheetState();
}

class _AdjustTimeSheetState extends ConsumerState<AdjustTimeSheet> {
  final _months = TextEditingController();
  final _days = TextEditingController();
  final _hours = TextEditingController();
  final _minutes = TextEditingController();
  final _seconds = TextEditingController();
  final _note = TextEditingController();
  DateTime _effective = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_months, _days, _hours, _minutes, _seconds, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  int _read(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Duration get _entered => DurationFormatter.fromUnits(
        months: _read(_months),
        days: _read(_days),
        hours: _read(_hours),
        minutes: _read(_minutes),
        seconds: _read(_seconds),
      );

  void _applyPreset(Duration d) {
    final c = DurationComponents.fromDuration(d);
    setState(() {
      _months.text = c.months == 0 ? '' : c.months.toString();
      _days.text = c.days == 0 ? '' : c.days.toString();
      _hours.text = c.hours == 0 ? '' : c.hours.toString();
      _minutes.text = c.minutes == 0 ? '' : c.minutes.toString();
      _seconds.text = c.seconds == 0 ? '' : c.seconds.toString();
    });
  }

  Future<void> _submit() async {
    final amount = _entered;
    if (amount.inSeconds <= 0) {
      AppDialogs.showSnack(context, 'Enter a duration greater than zero.');
      return;
    }

    final settings = ref.read(settingsProvider);
    // Confirm large removals.
    if (!widget.isAddition &&
        settings.confirmLargeAdjustments &&
        amount.inHours >= 1) {
      final ok = await AppDialogs.confirm(
        context,
        title: 'Remove a large amount of time?',
        message:
            'This will remove ${DurationFormatter.compact(amount)} from "${widget.project.name}".',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!ok) return;
    }

    setState(() => _busy = true);
    final service = ref.read(adjustmentServiceProvider);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    try {
      if (widget.isAddition) {
        await service.addManualTime(
          widget.project.id,
          amount: amount,
          note: note,
          effectiveAtUtc: _effective.toUtc(),
        );
      } else {
        await service.removeManualTime(
          widget.project.id,
          amount: amount,
          note: note,
          effectiveAtUtc: _effective.toUtc(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppDialogs.showSnack(
        context,
        widget.isAddition
            ? '${DurationFormatter.compact(amount)} added'
            : '${DurationFormatter.compact(amount)} removed',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final message = e.toString().replaceFirst('AdjustmentException: ', '');
      AppDialogs.showSnack(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(_nowOnce);
    final currentTotal = widget.project.totalAt(now);
    final entered = _entered;
    final afterSeconds = widget.isAddition
        ? currentTotal.inSeconds + entered.inSeconds
        : (currentTotal.inSeconds - entered.inSeconds);
    final after = Duration(seconds: afterSeconds < 0 ? 0 : afterSeconds);
    final colors = StatusColors.of(context);
    final accent = widget.isAddition ? colors.running : colors.destructive;

    final addPresets = <(String, Duration)>[
      ('+15m', const Duration(minutes: 15)),
      ('+30m', const Duration(minutes: 30)),
      ('+1h', const Duration(hours: 1)),
      ('+2h', const Duration(hours: 2)),
      ('+1d', const Duration(days: 1)),
    ];
    final removePresets = <(String, Duration)>[
      ('−15m', const Duration(minutes: 15)),
      ('−30m', const Duration(minutes: 30)),
      ('−1h', const Duration(hours: 1)),
      ('−8h', const Duration(hours: 8)),
    ];
    final presets = widget.isAddition ? addPresets : removePresets;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAddition ? 'Add time' : 'Remove time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.project.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final p in presets)
                  ActionChip(
                    label: Text(p.$1),
                    onPressed: () => _applyPreset(p.$2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _unit('MO', _months),
                _unit('DD', _days),
                _unit('HH', _hours),
                _unit('MM', _minutes),
                _unit('SS', _seconds),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Forgot to start the timer',
              ),
              maxLength: 200,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Effective date'),
              subtitle: Text(
                '${_effective.year}-${_effective.month.toString().padLeft(2, '0')}-${_effective.day.toString().padLeft(2, '0')}',
              ),
              onTap: _pickDate,
            ),
            const Divider(height: 24),
            _totalRow('Current total', currentTotal, null),
            const SizedBox(height: 6),
            _totalRow('After adjustment', after, accent),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(widget.isAddition ? Icons.add : Icons.remove),
                label: Text(widget.isAddition ? 'Add time' : 'Remove time'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effective,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _effective = picked);
  }

  Widget _unit(String label, TextEditingController controller) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            counterText: '',
          ),
          maxLength: 4,
        ),
      ),
    );
  }

  Widget _totalRow(String label, Duration value, Color? accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        CompactDuration(
          duration: value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Reads "now" a single time for total previews (no per-second rebuild needed
/// inside the sheet).
final _nowOnce = Provider<DateTime>((ref) {
  return ref.read(clockProvider).nowUtc();
});
