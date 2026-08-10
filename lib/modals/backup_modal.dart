import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/constants/storage_keys.dart';
import '../i18n/strings.dart';
import '../utils/ical_export.dart';
import '../providers/events_provider.dart';
import '../providers/themes_provider.dart';
import '../storage/local_store.dart';
import '../supabase/account_scope.dart';
import '../supabase/auth_service.dart';
import '../supabase/user_data_sync.dart';
import '../supabase/events_sync.dart';

/// 백업 파일 스키마 버전. 향후 형식이 바뀌면 올리고 복원 쪽에서 분기한다.
const _backupSchemaVersion = 2;

Future<void> showBackupModal(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const BackupModal(),
    );

class BackupModal extends ConsumerStatefulWidget {
  const BackupModal({super.key});
  @override ConsumerState<BackupModal> createState() => _BackupModalState();
}

class _BackupModalState extends ConsumerState<BackupModal> {
  String? _msg;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final sh = context.sh;
    final user = ref.watch(authProvider);
    final isLoggedIn = user != null;

    return FractionallySizedBox(
      heightFactor: isLoggedIn ? 0.7 : 0.55,
      child: Container(
        color: sh.card,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(children: [
                const Text('💾 ', style: TextStyle(fontSize: 20)),
                Text(tr('정보 백업'),
                    style: AppType.cardTitle.copyWith(fontWeight: FontWeight.w700, color: sh.ink)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close, color: sh.inkSoft, size: 20),
                    onPressed: () => Navigator.pop(context)),
              ]),
            ),
            Divider(color: sh.border, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── 파일 백업 ──
                  _Section(tr('📁 파일 백업'), sh),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _Btn(tr('⬇️ 파일로 내보내기'), sh,
                        onTap: _export, loading: _loading)),
                    const SizedBox(width: 10),
                    Expanded(child: _Btn(tr('⬆️ 파일에서 복원'), sh,
                        onTap: _import, loading: _loading)),
                  ]),
                  const SizedBox(height: 10),
                  _Btn(tr('📅 iCal(.ics)로 내보내기'), sh,
                      onTap: _exportIcal, loading: _loading),
                  // ── 클라우드 백업 (로그인 시) ──
                  if (isLoggedIn) ...[
                    const SizedBox(height: 20),
                    _Section(trf('☁️ 클라우드 동기화 ({0})', [userDisplayName(user)]), sh),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _Btn(tr('⬆️ 클라우드 업로드'), sh,
                          onTap: _cloudPush, loading: _loading)),
                      const SizedBox(width: 10),
                      Expanded(child: _Btn(tr('⬇️ 클라우드 내려받기'), sh,
                          onTap: _cloudPull, loading: _loading)),
                    ]),
                  ],
                  if (_msg != null) ...[
                    const SizedBox(height: 10),
                    Text(_msg!,
                        style: AppType.body.copyWith(color: sh.inkSoft)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _collect() {
    // `_v`/`_ts` 는 웹·구버전 앱이 읽는 필드라 그대로 두고,
    // 읽기 쉬운 이름을 나란히 추가한다(스펙 §23).
    final now = DateTime.now().toIso8601String();
    final snap = <String, dynamic>{
      '_v': _backupSchemaVersion,
      '_ts': now,
      'schemaVersion': _backupSchemaVersion,
      'createdAt': now,
    };
    for (final k in StorageKeys.backupKeys) {
      final v = LocalStore.instance.getString(k);
      if (v != null) snap[k] = v;
    }
    return snap;
  }

  Future<void> _export() async {
    setState(() { _loading = true; _msg = null; });
    try {
      final snap = _collect();
      final json = const JsonEncoder.withIndent('  ').convert(snap);
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fname = '달력_백업_${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}.json';
      final file = File('${dir.path}/$fname');
      await file.writeAsString(json);
      setState(() => _msg = trf('저장됨: {0}', [file.path]));
    } catch (e) {
      setState(() => _msg = trf('오류: {0}', [e]));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    setState(() { _loading = true; _msg = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.single.path == null) {
        setState(() { _loading = false; }); return;
      }
      final content = await File(result.files.single.path!).readAsString();
      final snap = jsonDecode(content) as Map<String, dynamic>;
      final version = snap['schemaVersion'] ?? snap['_v'];
      if (version is! int || version < 2) {
        throw Exception('올바른 백업 파일이 아닙니다 (버전 불일치)');
      }
      var restored = 0;
      for (final k in StorageKeys.backupKeys) {
        final v = snap[k];
        if (v is String) {
          await LocalStore.instance.setString(k, v);
          restored++;
        }
      }
      // 복원한 데이터를 화면에 반영 — 예전에는 일정·테마만 새로고침해서
      // 할 일·생일 등은 앱을 다시 켜야 보였다.
      AccountScope.invalidateAccountProviders(ref.invalidate);
      setState(() => _msg = trf('복원 완료 · {0}개 항목 ({1})',
          [restored, snap['createdAt'] ?? snap['_ts'] ?? '']));
    } catch (e) {
      setState(() => _msg = trf('오류: {0}', [e]));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportIcal() async {
    setState(() { _loading = true; _msg = null; });
    try {
      final events = ref.read(eventsProvider);
      await IcalExport.exportAndShare(events);
      setState(() => _msg = tr('iCal 공유 시트를 열었어요'));
    } catch (e) {
      setState(() => _msg = trf('오류: {0}', [e]));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cloudPush() async {
    setState(() { _loading = true; _msg = null; });
    try {
      EventsSync.forceReady();
      await UserDataSync.pushAll();
      final events = ref.read(eventsProvider);
      await EventsSync.pushAll(events);
      setState(() => _msg = tr('클라우드 업로드 완료'));
    } catch (e) {
      setState(() => _msg = trf('오류: {0}', [e]));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cloudPull() async {
    setState(() { _loading = true; _msg = null; });
    try {
      await UserDataSync.pullAll();
      ref.invalidate(eventsProvider);
      ref.invalidate(themesProvider);
      setState(() => _msg = tr('클라우드 내려받기 완료 — 앱을 재시작하면 모두 반영됩니다.'));
    } catch (e) {
      setState(() => _msg = trf('오류: {0}', [e]));
    } finally {
      setState(() => _loading = false);
    }
  }
}

class _Section extends StatelessWidget {
  final String text; final SurlapColors sh;
  const _Section(this.text, this.sh);
  @override Widget build(BuildContext context) =>
      Text(text, style: AppType.body.copyWith(fontWeight: FontWeight.w700, color: sh.inkSoft));
}

class _Btn extends StatelessWidget {
  final String label; final SurlapColors sh;
  final VoidCallback onTap; final bool loading;
  const _Btn(this.label, this.sh, {required this.onTap, required this.loading});
  @override Widget build(BuildContext context) => OutlinedButton(
    onPressed: loading ? null : onTap,
    style: OutlinedButton.styleFrom(
        foregroundColor: sh.ink, side: BorderSide(color: sh.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card))),
    child: Text(label, style: AppType.caption),
  );
}
