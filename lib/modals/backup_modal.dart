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
import '../supabase/auth_service.dart';
import '../supabase/user_data_sync.dart';
import '../supabase/events_sync.dart';

// 백업 대상 키 목록 (backup.js의 BACKUP_KEYS와 동일)
const _backupKeys = [
  StorageKeys.events,
  StorageKeys.themes,
  StorageKeys.dayTemplates,
  StorageKeys.dayWidgetValues,
  StorageKeys.motto,
  StorageKeys.neisSchool,
  StorageKeys.themeFilter,
  StorageKeys.circles,
  StorageKeys.starred,
  StorageKeys.continuousView,
  StorageKeys.weekStart,
];

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
                    style: AppType.titleMedium.copyWith(fontWeight: FontWeight.w700, color: sh.ink)),
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
                        style: AppType.bodyLarge.copyWith(color: sh.inkSoft)),
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
    final snap = <String, dynamic>{'_v': 2, '_ts': DateTime.now().toIso8601String()};
    for (final k in _backupKeys) {
      final v = LocalStore.instance.getString(k);
      if (v != null) { snap[k] = v; }
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
      if (snap['_v'] != 2) { throw Exception('올바른 백업 파일이 아닙니다 (버전 불일치)'); }
      for (final k in _backupKeys) {
        if (snap.containsKey(k)) {
          await LocalStore.instance.setString(k, snap[k] as String);
        }
      }
      // providers 재로드
      ref.invalidate(eventsProvider);
      ref.invalidate(themesProvider);
      setState(() => _msg = trf('복원 완료 ({0})', [snap['_ts'] ?? '']));
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
      Text(text, style: AppType.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: sh.inkSoft));
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
    child: Text(label, style: AppType.bodySmall),
  );
}
