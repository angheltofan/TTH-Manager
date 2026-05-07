import 'package:flutter/material.dart';

import 'workshop_basic_info_section.dart';

// ── Workshop type options ─────────────────────────────────────────────────────

class _WTypeOption {
  const _WTypeOption(this.value, this.label);
  final String value;
  final String label;
}

const _workshopTypeOptions = [
  _WTypeOption('Robotica', 'Robotică'),
  _WTypeOption('Benzi desenate', 'Benzi desenate'),
  _WTypeOption('Modelare 3D', 'Modelare 3D'),
  _WTypeOption('Desen și pictură', 'Desen și pictură'),
  _WTypeOption('Povestiri', 'Povestiri'),
  _WTypeOption('Programare', 'Programare'),
  _WTypeOption('Lectura', 'Lectură'),
  _WTypeOption('Altele', 'Altele'),
];

const _typeAliases = <String, String>{
  'Robotică': 'Robotica',
  'Lectură': 'Lectura',
};

const _daysOfWeek = [
  'Luni',
  'Marți',
  'Miercuri',
  'Joi',
  'Vineri',
  'Sâmbătă',
  'Duminică',
];

/// Returns the canonical DB value if known; null if unrecognized.
String? normalizeWorkshopType(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final normalized = _typeAliases[raw] ?? raw;
  return _workshopTypeOptions.any((o) => o.value == normalized)
      ? normalized
      : null;
}

/// Returns [raw] if it exists in the allowed day list; null otherwise.
String? normalizeDayOfWeek(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return _daysOfWeek.contains(raw) ? raw : null;
}

// ── Type + day section ────────────────────────────────────────────────────────

class WorkshopTypeSection extends StatelessWidget {
  const WorkshopTypeSection({
    super.key,
    required this.workshopType,
    required this.dayOfWeek,
    required this.onTypeChanged,
    required this.onDayChanged,
    required this.isWide,
  });

  final String? workshopType;
  final String? dayOfWeek;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onDayChanged;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final typeField = WorkshopFormField(
      label: 'Tip atelier',
      required: true,
      child: DropdownButtonFormField<String>(
        value: workshopType,
        decoration: workshopInputDecoration(theme),
        hint: const Text('Selectează tipul'),
        items: _workshopTypeOptions
            .map((o) => DropdownMenuItem(
                  value: o.value,
                  child: Text(o.label),
                ))
            .toList(),
        onChanged: onTypeChanged,
        validator: (v) =>
            v == null ? 'Selectează tipul atelierului' : null,
      ),
    );

    final dayField = WorkshopFormField(
      label: 'Ziua săptămânii',
      required: true,
      child: DropdownButtonFormField<String>(
        value: dayOfWeek,
        decoration: workshopInputDecoration(theme),
        hint: const Text('Selectează ziua'),
        items: _daysOfWeek
            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
            .toList(),
        onChanged: onDayChanged,
        validator: (v) => v == null ? 'Selectează ziua' : null,
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: typeField),
          const SizedBox(width: 16),
          Expanded(child: dayField),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        typeField,
        const SizedBox(height: 16),
        dayField,
      ],
    );
  }
}
