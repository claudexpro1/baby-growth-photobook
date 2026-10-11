import 'schedule.dart';

enum Gender { girl, boy, neutral }

/// Where this baby's photos live.
enum StorageMode { googleDrive, iCloud, appOnly }

class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.hour = 18,
    this.minute = 0,
  });
  final bool enabled;
  final int hour;
  final int minute;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
  };

  factory ReminderSettings.fromJson(Map<String, dynamic> j) => ReminderSettings(
    enabled: j['enabled'] as bool,
    hour: j['hour'] as int,
    minute: j['minute'] as int,
  );
}

class Baby {
  const Baby({
    required this.id,
    required this.name,
    required this.gender,
    required this.birth,
    this.birthPlace = '',
    required this.phases,
    this.reminder = const ReminderSettings(),
    this.storage = StorageMode.appOnly,
  });

  final String id;
  final String name;
  final Gender gender;

  /// Local date and time of birth.
  final DateTime birth;
  final String birthPlace;
  final List<Phase> phases;
  final ReminderSettings reminder;
  final StorageMode storage;

  PhotoSchedule get schedule => PhotoSchedule(birth, phases);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gender': gender.name,
    'birth': birth.toIso8601String(),
    'birthPlace': birthPlace,
    'phases': phases.map(phaseToJson).toList(),
    'reminder': reminder.toJson(),
    'storage': storage.name,
  };

  factory Baby.fromJson(Map<String, dynamic> j) => Baby(
    id: j['id'] as String,
    name: j['name'] as String,
    gender: Gender.values.byName(j['gender'] as String),
    birth: DateTime.parse(j['birth'] as String),
    birthPlace: j['birthPlace'] as String? ?? '',
    phases: (j['phases'] as List)
        .map((p) => phaseFromJson(p as Map<String, dynamic>))
        .toList(),
    reminder: ReminderSettings.fromJson(j['reminder'] as Map<String, dynamic>),
    storage: StorageMode.values.byName(j['storage'] as String),
  );
}

Map<String, dynamic> phaseToJson(Phase p) => {
  'start': {'value': p.start.value, 'unit': p.start.unit.name},
  'every': p.frequency.every,
  'unit': p.frequency.unit.name,
};

Phase phaseFromJson(Map<String, dynamic> j) {
  final s = j['start'] as Map<String, dynamic>;
  return Phase(
    start: Age(s['value'] as int, TimeUnit.values.byName(s['unit'] as String)),
    frequency: Frequency(
      j['every'] as int,
      TimeUnit.values.byName(j['unit'] as String),
    ),
  );
}
