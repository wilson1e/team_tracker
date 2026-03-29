import 'package:add_2_calendar/add_2_calendar.dart';

class CalendarService {
  static Future<bool> addMatchToCalendar({
    required String teamName,
    required String opponent,
    required DateTime dateTime,
    required String venue,
    required String league,
    required bool isHome,
  }) async {
    final event = Event(
      title: '🏀 $teamName vs $opponent',
      description: '聯賽: $league\n場地: $venue\n主/客: ${isHome ? '主場' : '作客'}',
      location: venue,
      startDate: dateTime,
      endDate: dateTime.add(const Duration(hours: 2)),
    );
    return await Add2Calendar.addEvent2Cal(event);
  }

  static Future<bool> addTrainingToCalendar({
    required String teamName,
    required String title,
    required DateTime dateTime,
    required String venue,
    String? notes,
  }) async {
    final event = Event(
      title: '💪 $teamName - $title',
      description: '場地: $venue${notes != null && notes.isNotEmpty ? '\n備註: $notes' : ''}',
      location: venue,
      startDate: dateTime,
      endDate: dateTime.add(const Duration(hours: 2)),
    );
    return await Add2Calendar.addEvent2Cal(event);
  }
}
