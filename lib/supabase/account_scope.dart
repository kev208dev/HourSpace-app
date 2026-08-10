// 계정 단위 데이터 분리의 단일 진입점.
// auth 상태가 바뀌면: 스코프 전환 → (로그인 시) 클라우드 pull → provider invalidate.
// 데이터 변경 시: 로그인 상태면 디바운스 push.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/storage_keys.dart';
import '../storage/local_store.dart';
import '../providers/events_provider.dart';
import '../providers/themes_provider.dart';
import '../providers/extras_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/day_widget_provider.dart';
import '../providers/birthdays_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/cell_design_provider.dart';
import '../providers/todos_provider.dart';
import '../providers/academic_schedule_provider.dart';
import '../providers/record_templates_provider.dart';
import '../providers/template_ranges_provider.dart';
import '../providers/sports_provider.dart';
import '../providers/user_type_provider.dart';
import 'events_sync.dart';
import 'user_data_sync.dart';

class AccountScope {
  static String? _pulledFor; // 이미 pull 시도한 스코프
  static Timer? _pushTimer;
  static final Set<String> _dirty = {};

  static String scopeFor(User? user) =>
      user != null ? 'user_${user.id}' : 'guest';

  /// 앱 시작 시 1회: 계정 데이터 변경 → 디바운스 push 훅 설치.
  static void installPushHook() {
    LocalStore.instance.onAccountKeyChanged = (key) {
      if (!LocalStore.instance.scope.startsWith('user_')) return; // 로그인 시에만
      _dirty.add(key);
      _pushTimer?.cancel();
      _pushTimer = Timer(const Duration(milliseconds: 700), _flush);
    };
  }

  static Future<void> _flush() async {
    final keys = Set<String>.from(_dirty);
    _dirty.clear();
    for (final k in keys) {
      if (k == StorageKeys.events) {
        await EventsSync.pushLocal();
      } else if (StorageKeys.userDataKeys.contains(k)) {
        await UserDataSync.pushKey(k);
      }
    }
  }

  /// auth 변화 단일 처리: 스코프 전환 → pull → invalidate.
  static Future<void> applyAuth(Ref ref, User? user) async {
    final newScope = scopeFor(user);
    final changed = LocalStore.instance.scope != newScope;
    LocalStore.instance.setScope(newScope);

    var pulled = false;
    if (user != null && _pulledFor != newScope) {
      _pulledFor = newScope;
      EventsSync.forceReady();
      // pull 성공 시에만 로컬 교체(각 sync가 실패 시 로컬 보존).
      final ev = await EventsSync.pullToLocal();
      final ud = await UserDataSync.pullAll();
      pulled = ev || ud;
    }
    if (user == null) _pulledFor = null; // 로그아웃 → 다음 로그인 시 재pull

    if (changed || pulled) invalidateAccountProviders(ref.invalidate);
  }

  /// 계정 스코프 데이터를 읽는 provider 전체를 다시 읽게 한다.
  ///
  /// 계정 전환·클라우드 pull·백업 복원 뒤에 공통으로 쓴다. [invalidate] 는
  /// `ref.invalidate` — `Ref` 와 `WidgetRef` 가 공통 타입을 갖지 않아 함수로 받는다.
  /// 여기 빠진 provider 가 있으면 그 데이터만 앱을 다시 켤 때까지 옛 값으로 남는다.
  static void invalidateAccountProviders(
      void Function(ProviderOrFamily) invalidate) {
    invalidate(eventsProvider);
    invalidate(themesProvider);
    invalidate(starredProvider);
    invalidate(memosProvider);
    invalidate(circlesProvider);
    invalidate(filterProvider);
    invalidate(dayTemplatesProvider);
    invalidate(widgetValuesProvider);
    invalidate(birthdaysProvider);
    invalidate(settingsProvider); // 모토(계정) 재읽기
    invalidate(recurringProvider); // 반복 일정(계정) 재읽기
    invalidate(cellDesignProvider); // 셀 디자인(계정) 재읽기
    invalidate(todosProvider); // 할 일(계정) 재읽기
    invalidate(academicScheduleProvider); // 학사일정(학교) 재요청
    invalidate(recordTemplatesProvider); // 기록 템플릿(계정)
    invalidate(templateRangesProvider); // 기록 템플릿 적용 기간(계정)
    invalidate(sportsSubscriptionsProvider); // 스포츠 구독(계정)
    invalidate(userTypeProvider);
  }
}
