import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../domain/baby.dart';
import 'calendar_ics.dart';

/// In the browser there are no scheduled notifications (they would need a
/// server). Reminders go into the phone's Calendar instead: see
/// [addToCalendar].
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  /// Calendar reminders are added by the user on purpose, so there is no
  /// permission to ask for.
  Future<bool> requestPermission() async => true;

  /// Browsers cannot schedule notifications without a server.
  Future<bool> notificationsAllowed() async => false;

  /// No scheduled notifications in the browser, so nothing to test.
  Future<void> sendTest(String babyName) async {}

  Future<void> rescheduleAll(
    List<Baby> babies,
    Future<Set<DateTime>> Function(Baby) photoDatesFor,
  ) async {}

  /// Hands the reminders to the phone as a calendar file. On iPhone this opens
  /// "Add to Calendar".
  Future<void> addToCalendar(Baby baby) async {
    final ics = buildCalendarIcs(baby, DateTime.now());
    final blob = web.Blob(
      [utf8.encode(ics).toJS].toJS,
      web.BlobPropertyBag(type: 'text/calendar'),
    );
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = 'photo-reminders.ics';
    web.document.body!.append(a);
    a.click();
    a.remove();
  }
}
