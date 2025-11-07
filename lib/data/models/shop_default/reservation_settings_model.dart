class ReservationSettingsModel {
  final DaySettings monday;
  final DaySettings tuesday;
  final DaySettings wednesday;
  final DaySettings thursday;
  final DaySettings friday;
  final DaySettings saturday;
  final DaySettings sunday;
  final LunchSettings lunch;
  final DaySettings holiday;
  final int relayTime;
  final int limitPerson;

  ReservationSettingsModel({
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    required this.lunch,
    required this.holiday,
    required this.relayTime,
    required this.limitPerson,
  });

  factory ReservationSettingsModel.fromJson(Map<String, dynamic> json) {
    return ReservationSettingsModel(
      monday: DaySettings.fromJson(json['monday'] ?? {}),
      tuesday: DaySettings.fromJson(json['tuesday'] ?? {}),
      wednesday: DaySettings.fromJson(json['wednesday'] ?? {}),
      thursday: DaySettings.fromJson(json['thursday'] ?? {}),
      friday: DaySettings.fromJson(json['friday'] ?? {}),
      saturday: DaySettings.fromJson(json['saturday'] ?? {}),
      sunday: DaySettings.fromJson(json['sunday'] ?? {}),
      lunch: LunchSettings.fromJson(json['lunch'] ?? {}),
      holiday: DaySettings.fromJson(json['holiday'] ?? {}),
      relayTime: json['relay_time'] ?? 30,
      limitPerson: json['limit_person'] ?? 15,
    );
  }
  
  DaySettings getSettingsForDay(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return monday;
      case DateTime.tuesday:
        return tuesday;
      case DateTime.wednesday:
        return wednesday;
      case DateTime.thursday:
        return thursday;
      case DateTime.friday:
        return friday;
      case DateTime.saturday:
        return saturday;
      case DateTime.sunday:
        return sunday;
      default:
        return monday;
    }
  }
}

class DaySettings {
  final String? startTime;
  final String? endTime;
  final bool active;

  DaySettings({
    this.startTime,
    this.endTime,
    required this.active,
  });

  factory DaySettings.fromJson(Map<String, dynamic> json) {
    return DaySettings(
      startTime: json['start_time'],
      endTime: json['end_time'],
      active: json['active'] ?? false,
    );
  }
}

class LunchSettings {
  final String? startTime;
  final String? endTime;

  LunchSettings({
    this.startTime,
    this.endTime,
  });

  factory LunchSettings.fromJson(Map<String, dynamic> json) {
    return LunchSettings(
      startTime: json['start_time'],
      endTime: json['end_time'],
    );
  }
}

