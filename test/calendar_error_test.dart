import 'package:baby_growth_photobook/notifications/google_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('names the real cause instead of always saying "allow access"', () {
    expect(
      calendarErrorMessage(const CalendarNotConnected()),
      contains('allow Calendar access'),
    );
    expect(
      calendarErrorMessage(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      contains('window was closed'),
    );
    final off = cal.DetailedApiRequestError(
      403,
      'Google Calendar API has not been used in project 1 before or it is disabled.',
    );
    expect(calendarErrorMessage(off), contains('not switched on'));
    expect(
      calendarErrorMessage(cal.DetailedApiRequestError(403, 'Forbidden')),
      contains('403'),
    );
    expect(
      calendarErrorMessage(cal.DetailedApiRequestError(401, 'x')),
      contains('expired'),
    );
    expect(calendarErrorMessage(StateError('x')), contains('StateError'));
  });
}
