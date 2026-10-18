/// Status of a 1-hour slot (matches DTEK time_type keys).
enum SlotStatus {
  yes, // Світло є
  no, // Світла немає
  maybe, // Можливо відключення
  first, // Світла не буде перші 30 хв.
  second, // Світла не буде другі 30 хв
  mfirst, // Світла можливо не буде перші 30 хв.
  msecond, // Світла можливо не буде другі 30 хв
  unknown;

  static SlotStatus fromString(String? s) {
    switch (s?.toLowerCase()) {
      case 'yes':
        return SlotStatus.yes;
      case 'no':
        return SlotStatus.no;
      case 'maybe':
        return SlotStatus.maybe;
      case 'first':
        return SlotStatus.first;
      case 'second':
        return SlotStatus.second;
      case 'mfirst':
        return SlotStatus.mfirst;
      case 'msecond':
        return SlotStatus.msecond;
      default:
        return SlotStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case SlotStatus.yes:
        return 'Світло є';
      case SlotStatus.no:
        return 'Світла немає';
      case SlotStatus.maybe:
        return 'Можливо відключення';
      case SlotStatus.first:
        return 'Світла не буде перші 30 хв.';
      case SlotStatus.second:
        return 'Світла не буде другі 30 хв';
      case SlotStatus.mfirst:
        return 'Світла можливо не буде перші 30 хв.';
      case SlotStatus.msecond:
        return 'Світла можливо не буде другі 30 хв';
      case SlotStatus.unknown:
        return 'Невідомо';
    }
  }

  /// True if electricity is guaranteed (white on site).
  bool get hasLight => this == SlotStatus.yes;

  /// True if definite or partial outage.
  bool get hasOutage =>
      this == SlotStatus.no ||
      this == SlotStatus.first ||
      this == SlotStatus.second;

  /// Possible outage (grey-ish on site).
  bool get mayHaveOutage =>
      hasOutage ||
      this == SlotStatus.maybe ||
      this == SlotStatus.mfirst ||
      this == SlotStatus.msecond;
}

class TimeSlot {
  final int index; // 1..24
  final String label; // "00-01"
  final String start; // "00:00"
  final String end; // "01:00"
  final SlotStatus status;

  const TimeSlot({
    required this.index,
    required this.label,
    required this.start,
    required this.end,
    required this.status,
  });
}

class DaySchedule {
  final DateTime date;
  final bool isToday;
  final bool isTomorrow;
  final bool isAvailable;
  final String? emptyMessage;
  final List<TimeSlot> slots;
  final String? updatedAt; // fact.update

  const DaySchedule({
    required this.date,
    required this.isToday,
    required this.isTomorrow,
    required this.isAvailable,
    this.emptyMessage,
    this.slots = const [],
    this.updatedAt,
  });
}

class OutageReason {
  /// Banner text shown at the top (HTML-ish plain text).
  final String message;
  final String? updateTimestamp;
  final bool isActiveOutage;
  final String? cause; // e.g. планові ремонтні роботи
  final String? startDate;
  final String? endDate;
  final bool isMultiGroup;
  final List<String> groups;

  const OutageReason({
    required this.message,
    this.updateTimestamp,
    this.isActiveOutage = false,
    this.cause,
    this.startDate,
    this.endDate,
    this.isMultiGroup = false,
    this.groups = const [],
  });
}

class AddressScheduleResult {
  final OutageReason reason;
  final DaySchedule today;
  final DaySchedule tomorrow;
  final String? primaryGroup;
  final List<String> groups;
  final String? updateTimestamp;

  const AddressScheduleResult({
    required this.reason,
    required this.today,
    required this.tomorrow,
    this.primaryGroup,
    this.groups = const [],
    this.updateTimestamp,
  });
}
