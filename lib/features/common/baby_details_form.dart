import 'package:flutter/material.dart';

import '../../domain/baby.dart';

/// Earliest birth date offered: 25 years back covers parents adding an older
/// child's early photos; the schedule does not care about the exact year.
DateTime birthDateFirst(DateTime now) => DateTime(now.year - 25, 1, 1);

/// Latest birth date offered: an expected due date up to ten months ahead, so
/// parents can set up before the birth.
DateTime birthDateLast(DateTime now) =>
    DateTime(now.year, now.month + 10, now.day);

/// Name, colours, birth date and time, place of birth: the same form when
/// registering a baby and in Settings.
class BabyDetailsForm extends StatelessWidget {
  const BabyDetailsForm({
    super.key,
    required this.name,
    required this.place,
    required this.gender,
    required this.birthDate,
    required this.birthTime,
    required this.onGender,
    required this.onBirthDate,
    required this.onBirthTime,
    this.neutralLabel = 'Skip',
  });

  final TextEditingController name;
  final TextEditingController place;
  final Gender gender;
  final DateTime birthDate;
  final TimeOfDay birthTime;
  final ValueChanged<Gender> onGender;
  final ValueChanged<DateTime> onBirthDate;
  final ValueChanged<TimeOfDay> onBirthTime;
  final String neutralLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      const SizedBox(height: 20),
      const Text('Girl or boy? (This only picks the colours.)'),
      const SizedBox(height: 8),
      SegmentedButton<Gender>(
        showSelectedIcon: false,
        segments: [
          const ButtonSegment(value: Gender.girl, label: Text('Girl')),
          const ButtonSegment(value: Gender.boy, label: Text('Boy')),
          ButtonSegment(value: Gender.neutral, label: Text(neutralLabel)),
        ],
        selected: {gender},
        onSelectionChanged: (s) => onGender(s.first),
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Birth date'),
        subtitle: Text(
          MaterialLocalizations.of(context).formatFullDate(birthDate),
        ),
        trailing: const Icon(Icons.calendar_today),
        onTap: () async {
          final now = DateTime.now();
          final first = birthDateFirst(now);
          final last = birthDateLast(now);
          // Keep the shown date inside the allowed range.
          final initial = birthDate.isBefore(first)
              ? first
              : (birthDate.isAfter(last) ? last : birthDate);
          final d = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: first,
            lastDate: last,
          );
          if (d != null) onBirthDate(d);
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Birth time'),
        subtitle: Text(birthTime.format(context)),
        trailing: const Icon(Icons.schedule),
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: birthTime,
          );
          if (t != null) onBirthTime(t);
        },
      ),
      const SizedBox(height: 8),
      TextField(
        controller: place,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Place of birth (optional)',
        ),
      ),
    ],
  );
}
