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
    this.end,
    this.reminder = const ReminderSettings(),
    this.storage = StorageMode.appOnly,
    this.driveFolderId,
    this.driveSharedFolderId,
    this.googleCalendarId,
  });

  final String id;
  final String name;
  final Gender gender;

  /// Local date and time of birth.
  final DateTime birth;
  final String birthPlace;
  final List<Phase> phases;

  /// Finish line: the age at which the photo series stops (null: never).
  final Age? end;
  final ReminderSettings reminder;
  final StorageMode storage;

  /// Google Drive folder ids (set once the folders have been created).
  final String? driveFolderId;
  final String? driveSharedFolderId;

  /// The Google Calendar holding this baby's photo reminders, if linked.
  final String? googleCalendarId;

  Baby copyWith({
    String? name,
    Gender? gender,
    DateTime? birth,
    String? birthPlace,
    List<Phase>? phases,
    Age? end,
    bool clearEnd = false,
    ReminderSettings? reminder,
    StorageMode? storage,
    String? driveFolderId,
    String? driveSharedFolderId,
    String? googleCalendarId,
    bool clearGoogleCalendar = false,
  }) => Baby(
    id: id,
    name: name ?? this.name,
    gender: gender ?? this.gender,
    birth: birth ?? this.birth,
    birthPlace: birthPlace ?? this.birthPlace,
    phases: phases ?? this.phases,
    end: clearEnd ? null : (end ?? this.end),
    reminder: reminder ?? this.reminder,
    storage: storage ?? this.storage,
    driveFolderId: driveFolderId ?? this.driveFolderId,
    driveSharedFolderId: driveSharedFolderId ?? this.driveSharedFolderId,
    googleCalendarId: clearGoogleCalendar
        ? null
        : (googleCalendarId ?? this.googleCalendarId),
  );

  PhotoSchedule get schedule => PhotoSchedule(birth, phases, end: end);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gender': gender.name,
    'birth': birth.toIso8601String(),
    'birthPlace': birthPlace,
    'phases': phases.map(phaseToJson).toList(),
    if (end != null) 'end': {'value': end!.value, 'unit': end!.unit.name},
    'reminder': reminder.toJson(),
    'storage': storage.name,
    'driveFolderId': driveFolderId,
    'driveSharedFolderId': driveSharedFolderId,
    'googleCalendarId': googleCalendarId,
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
    end: j['end'] == null
        ? null
        : Age(
            (j['end'] as Map<String, dynamic>)['value'] as int,
            TimeUnit.values.byName(
              (j['end'] as Map<String, dynamic>)['unit'] as String,
            ),
          ),
    reminder: ReminderSettings.fromJson(j['reminder'] as Map<String, dynamic>),
    storage: StorageMode.values.byName(j['storage'] as String),
    driveFolderId: j['driveFolderId'] as String?,
    driveSharedFolderId: j['driveSharedFolderId'] as String?,
    googleCalendarId: j['googleCalendarId'] as String?,
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
