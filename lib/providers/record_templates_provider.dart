import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/storage_keys.dart';
import '../models/record_template.dart';
import '../storage/local_store.dart';
import 'template_ranges_provider.dart';

/// 사용자 정의 기록 템플릿(커스텀만 저장). 프리셋은 코드 상수.
class RecordTemplatesNotifier extends Notifier<List<RecordTemplate>> {
  @override
  List<RecordTemplate> build() {
    final raw = LocalStore.instance.getString(StorageKeys.recordTemplates);
    return raw != null ? RecordTemplate.listFromJson(raw) : [];
  }

  Future<void> add(RecordTemplate t) async {
    state = [...state, t];
    await _save();
  }

  Future<void> update(RecordTemplate t) async {
    state = [for (final e in state) e.id == t.id ? t : e];
    await _save();
  }

  Future<void> delete(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }

  Future<void> _save() async {
    await LocalStore.instance.setString(
        StorageKeys.recordTemplates, RecordTemplate.listToJson(state));
  }
}

final recordTemplatesProvider =
    NotifierProvider<RecordTemplatesNotifier, List<RecordTemplate>>(
        RecordTemplatesNotifier.new);

/// 프리셋 + 커스텀 합친 전체 목록.
final allRecordTemplatesProvider = Provider<List<RecordTemplate>>(
    (ref) => [...kPresetTemplates, ...ref.watch(recordTemplatesProvider)]);

/// id → 템플릿 빠른 조회(셀 뱃지/입력 시트용).
final recordTemplatesByIdProvider = Provider<Map<String, RecordTemplate>>(
    (ref) => {for (final t in ref.watch(allRecordTemplatesProvider)) t.id: t});

/// 그 날짜에 적용 중인 기록 템플릿(중복 제거).
///
/// 오늘 화면·날짜 액션 시트·기록 화면이 각자 적용 기간을 훑던 것을 한 곳으로.
final activeRecordTemplatesProvider =
    Provider.family<List<RecordTemplate>, String>((ref, dateKey) {
  final byId = ref.watch(recordTemplatesByIdProvider);
  final out = <RecordTemplate>[];
  final seen = <String>{};
  for (final r in ref.watch(templateRangesProvider)) {
    if (!r.covers(dateKey) || !seen.add(r.templateId)) continue;
    final tpl = byId[r.templateId];
    if (tpl != null) out.add(tpl);
  }
  return out;
});

// ─── 마이그레이션 ───────────────────────────────────────────────────────
// 구버전 공부 데이터(studyHours/subjects/note) → 일반 구조(primary/tags/memo).
// widgetValues[date]['study-tracker'] 의 필드 키만 리네임. 1회만 실행.
Future<void> migrateRecordDataOnce() async {
  final store = LocalStore.instance;
  if (store.getBool(StorageKeys.recordMigratedV1) == true) return;
  final raw = store.getString(StorageKeys.dayWidgetValues);
  if (raw != null) {
    try {
      final outer = jsonDecode(raw) as Map<String, dynamic>;
      var changed = false;
      outer.forEach((date, tpls) {
        if (tpls is! Map) return;
        final study = tpls['study-tracker'];
        if (study is! Map) return;
        void rename(String from, String to) {
          if (study.containsKey(from) && !study.containsKey(to)) {
            study[to] = study.remove(from);
            changed = true;
          }
        }

        rename('studyHours', kRecPrimary);
        rename('subjects', kRecTags);
        rename('note', kRecMemo);
      });
      if (changed) {
        await store.setString(StorageKeys.dayWidgetValues, jsonEncode(outer));
      }
    } catch (_) {}
  }
  await store.setBool(StorageKeys.recordMigratedV1, true);
}
