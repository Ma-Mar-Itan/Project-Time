import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utilities/duration_formatter.dart';
import '../../../../data/database/app_database.dart';
import '../../../../domain/services/project_service.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/providers/project_providers.dart';
import '../../../../shared/providers/settings_provider.dart';
import '../../../../shared/widgets/app_dialogs.dart';

/// Create (projectId == null) or edit a project.
class AddEditProjectScreen extends ConsumerStatefulWidget {
  const AddEditProjectScreen({this.projectId, super.key});

  final String? projectId;

  bool get isEditing => projectId != null;

  @override
  ConsumerState<AddEditProjectScreen> createState() =>
      _AddEditProjectScreenState();
}

class _AddEditProjectScreenState extends ConsumerState<AddEditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _client = TextEditingController();
  final _notes = TextEditingController();
  final _rate = TextEditingController();
  final _currency = TextEditingController();

  final _initMonths = TextEditingController();
  final _initDays = TextEditingController();
  final _initHours = TextEditingController();
  final _initMinutes = TextEditingController();

  int _colorValue = AppColors.defaultProjectColor().toARGB32();
  DateTime? _deadline;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency.text = '';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _client,
      _notes,
      _rate,
      _currency,
      _initMonths,
      _initDays,
      _initHours,
      _initMinutes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(Project p) {
    if (_initialized) return;
    _initialized = true;
    _name.text = p.name;
    _description.text = p.description ?? '';
    _client.text = p.clientOrCategory ?? '';
    _notes.text = p.notes ?? '';
    _rate.text = p.hourlyRateMinorUnits == null
        ? ''
        : (p.hourlyRateMinorUnits! / 100).toStringAsFixed(2);
    _currency.text = p.currencyCode ?? '';
    _colorValue = p.colorValue;
    _deadline = p.deadlineUtc?.toLocal();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final rateText = _rate.text.trim();
    int? rateMinor;
    if (rateText.isNotEmpty) {
      final parsed = double.tryParse(rateText);
      if (parsed != null) rateMinor = (parsed * 100).round();
    }

    final input = ProjectInput(
      name: _name.text,
      description: _description.text,
      clientOrCategory: _client.text,
      notes: _notes.text,
      colorValue: _colorValue,
      hourlyRateMinorUnits: rateMinor,
      currencyCode: _currency.text.trim().isEmpty
          ? ref.read(settingsProvider).preferredCurrency
          : _currency.text.trim().toUpperCase(),
      deadlineUtc: _deadline?.toUtc(),
      initialTime: widget.isEditing
          ? Duration.zero
          : DurationFormatter.fromUnits(
              months: int.tryParse(_initMonths.text) ?? 0,
              days: int.tryParse(_initDays.text) ?? 0,
              hours: int.tryParse(_initHours.text) ?? 0,
              minutes: int.tryParse(_initMinutes.text) ?? 0,
            ),
    );

    final service = ref.read(projectServiceProvider);
    try {
      if (widget.isEditing) {
        await service.edit(widget.projectId!, input);
      } else {
        await service.create(input);
      }
      if (mounted) {
        Navigator.of(context).pop();
        AppDialogs.showSnack(
            context, widget.isEditing ? 'Project updated' : 'Project created');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppDialogs.showSnack(context, 'Could not save project.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final projectAsync = ref.watch(projectByIdProvider(widget.projectId!));
      final project = projectAsync.valueOrNull;
      if (project != null) _hydrate(project);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit project' : 'New project'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !widget.isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Project name *',
                hintText: 'e.g. Research Project',
              ),
              maxLength: 100,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Project name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _client,
              decoration:
                  const InputDecoration(labelText: 'Client or category'),
              maxLength: 100,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _ColorPicker(
              selected: _colorValue,
              onSelected: (value) => setState(() => _colorValue = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rate,
                    decoration: const InputDecoration(
                      labelText: 'Hourly rate',
                      prefixText: '',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]')),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final parsed = double.tryParse(value.trim());
                      if (parsed == null) return 'Invalid number';
                      if (parsed < 0) return 'Cannot be negative';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      hintText: 'USD',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Deadline'),
              subtitle: Text(_deadline == null
                  ? 'None'
                  : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'),
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    ),
              onTap: _pickDeadline,
            ),
            if (!widget.isEditing) ...[
              const Divider(height: 32),
              Text('Initial time (optional)',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  _initUnit('MO', _initMonths),
                  _initUnit('DD', _initDays),
                  _initUnit('HH', _initHours),
                  _initUnit('MM', _initMinutes),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _initUnit(String label, TextEditingController controller) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: TextFormField(
          controller: controller,
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

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final entry in AppColors.projectPalette.entries)
          _Swatch(
            label: entry.key,
            color: entry.value,
            selected: entry.value.toARGB32() == selected,
            onTap: () => onSelected(entry.value.toARGB32()),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label color${selected ? ', selected' : ''}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
