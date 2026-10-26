import '../domain/baby.dart';

/// Used outside the browser (unit and widget tests): the app only runs as a web
/// app, where reminders go into Google Calendar, so there is nothing to
/// schedule here. Mirrors the API of `reminder_service_web.dart`.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  Future<bool> requestPermission() async => true;

  Future<bool> notificationsAllowed() async => false;

  Future<void> sendTest(String babyName) async {}

  Future<void> rescheduleAll(
    List<Baby> babies,
    Future<Set<DateTime>> Function(Baby) photoDatesFor,
  ) async {}

  Future<void> addToCalendar(Baby baby) async {}
}
