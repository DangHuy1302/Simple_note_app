import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

class CalendarSyncService {
  CalendarSyncService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[gcal.CalendarApi.calendarEventsScope],
  );

  static Future<dynamic> _getAuthenticatedClient({
    bool interactive = false,
  }) async {
    final account = interactive
        ? await _googleSignIn.signIn()
        : await _googleSignIn.signInSilently();
    if (account == null) return null;
    return _googleSignIn.authenticatedClient();
  }

  static Future<bool> hasCalendarAccess() async {
    final client = await _getAuthenticatedClient();
    if (client == null) return false;
    client.close();
    return true;
  }

  static Future<bool> requestCalendarAccessInteractively() async {
    try {
      final client = await _getAuthenticatedClient(interactive: true);
      if (client == null) {
        return false;
      }

      client.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> upsertNoteEvent({
    required String noteId,
    required String title,
    required String description,
    required DateTime start,
    required DateTime end,
    String? existingEventId,
    bool recurringWeekly = false,
  }) async {
    final client = await _getAuthenticatedClient();
    if (client == null) {
      return existingEventId;
    }

    try {
      final api = gcal.CalendarApi(client);
      final event = gcal.Event(
        summary: title,
        description: description,
        start: gcal.EventDateTime(dateTime: start.toUtc()),
        end: gcal.EventDateTime(dateTime: end.toUtc()),
        extendedProperties: gcal.EventExtendedProperties(
          private: {'noteId': noteId},
        ),
      );

      if (recurringWeekly) {
        event.recurrence = ['RRULE:FREQ=WEEKLY'];
      }

      if (existingEventId != null && existingEventId.isNotEmpty) {
        try {
          final updated = await api.events.update(
            event,
            'primary',
            existingEventId,
          );
          return updated.id ?? existingEventId;
        } catch (_) {
          final inserted = await api.events.insert(event, 'primary');
          return inserted.id;
        }
      }

      final inserted = await api.events.insert(event, 'primary');
      return inserted.id;
    } finally {
      client.close();
    }
  }

  static Future<String?> findEventIdByNoteId(String noteId) async {
    if (noteId.isEmpty) return null;

    final client = await _getAuthenticatedClient();
    if (client == null) return null;

    try {
      final api = gcal.CalendarApi(client);
      final events = await api.events.list(
        'primary',
        privateExtendedProperty: <String>['noteId=$noteId'],
        maxResults: 1,
      );
      final items = events.items;
      if (items == null || items.isEmpty) return null;
      return items.first.id;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<void> deleteEventIfExists(
    String? eventId, {
    String? noteId,
  }) async {
    String? targetEventId = eventId;
    if ((targetEventId == null || targetEventId.isEmpty) &&
        noteId != null &&
        noteId.isNotEmpty) {
      targetEventId = await findEventIdByNoteId(noteId);
    }

    if (targetEventId == null || targetEventId.isEmpty) return;

    final client = await _getAuthenticatedClient();
    if (client == null) return;

    try {
      final api = gcal.CalendarApi(client);
      await api.events.delete('primary', targetEventId);
    } catch (_) {
    } finally {
      client.close();
    }
  }
}
