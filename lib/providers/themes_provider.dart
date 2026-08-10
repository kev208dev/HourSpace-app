import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_theme.dart';
import '../core/constants/storage_keys.dart';
import '../storage/local_store.dart';
import 'holidays_provider.dart';

class ThemesNotifier extends Notifier<List<CalendarTheme>> {
  @override
  List<CalendarTheme> build() {
    final raw = LocalStore.instance.getString(StorageKeys.themes);
    if (raw != null) {
      final list = CalendarTheme.listFromJson(raw);
      final normalized = withSystemCalendarThemes(list);
      _persist(normalized);
      return normalized;
    }
    const defaults = [holidayCalendarTheme];
    _persist(defaults);
    return defaults;
  }

  void _persist(List<CalendarTheme> themes) {
    LocalStore.instance.setString(
      StorageKeys.themes,
      CalendarTheme.listToJson(userCalendarThemes(themes)),
    );
  }

  Future<void> add(CalendarTheme theme) async {
    if (isSystemCalendarTheme(theme.id)) return;
    state = [...state, theme];
    _persist(state);
  }

  Future<void> update(CalendarTheme theme) async {
    if (isSystemCalendarTheme(theme.id)) return;
    state = [for (final t in state) t.id == theme.id ? theme : t];
    _persist(state);
  }

  Future<void> delete(String id) async {
    if (isSystemCalendarTheme(id)) return;
    state = state.where((t) => t.id != id).toList();
    _persist(state);
  }

  CalendarTheme? byId(String id) {
    try {
      return state.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

final themesProvider = NotifierProvider<ThemesNotifier, List<CalendarTheme>>(
  ThemesNotifier.new,
);

/// Calendars that users can apply to events and manage themselves.
final userThemesProvider = Provider<List<CalendarTheme>>(
  (ref) => userCalendarThemes(ref.watch(themesProvider)),
);
