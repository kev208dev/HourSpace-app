// NEIS 교육정보 개방포털 API
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/storage_keys.dart';
import '../storage/local_store.dart';

const _neisKey = '21e74fc6a71d49d38adda2f572fdde85';
const _base = 'https://open.neis.go.kr/hub';

class NeisSchool {
  final String name;
  final String code; // SD_SCHUL_CODE
  final String officeCode; // ATPT_OFCDC_SC_CODE
  final String kind; // 학교 종류 (고등학교 etc.)
  final int grade;
  final int classNm;

  /// 학교 홈페이지 주소 (NEIS HMPG_ADRES). 파비콘 로고 추출에 사용.
  final String homepage;

  /// 학교 슬로건/교훈 — 공식 API에 없어 사용자가 직접 입력.
  final String slogan;

  /// 로고 이미지 URL 직접 지정(override). 비어 있으면 [logoUrl]이 파비콘으로 대체.
  final String logoOverride;

  const NeisSchool({
    required this.name,
    required this.code,
    required this.officeCode,
    required this.kind,
    required this.grade,
    required this.classNm,
    this.homepage = '',
    this.slogan = '',
    this.logoOverride = '',
  });

  /// 실제로 표시할 로고 URL. 직접 지정한 값이 있으면 그것을,
  /// 없으면 홈페이지 도메인의 파비콘을 쓴다. 둘 다 없으면 null.
  String? get logoUrl {
    if (logoOverride.trim().isNotEmpty) return logoOverride.trim();
    return faviconUrlFor(homepage);
  }

  /// [logoUrl] 고화질 로드 실패 시 쓸 저화질 파비콘.
  /// 직접 지정 로고면 폴백 없음(null).
  String? get logoFallbackUrl {
    if (logoOverride.trim().isNotEmpty) return null;
    return faviconFallbackUrlFor(homepage);
  }

  NeisSchool copyWith({
    String? name,
    String? code,
    String? officeCode,
    String? kind,
    int? grade,
    int? classNm,
    String? homepage,
    String? slogan,
    String? logoOverride,
  }) => NeisSchool(
    name: name ?? this.name,
    code: code ?? this.code,
    officeCode: officeCode ?? this.officeCode,
    kind: kind ?? this.kind,
    grade: grade ?? this.grade,
    classNm: classNm ?? this.classNm,
    homepage: homepage ?? this.homepage,
    slogan: slogan ?? this.slogan,
    logoOverride: logoOverride ?? this.logoOverride,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'code': code,
    'officeCode': officeCode,
    'kind': kind,
    'grade': grade,
    'classNm': classNm,
    if (homepage.isNotEmpty) 'homepage': homepage,
    if (slogan.isNotEmpty) 'slogan': slogan,
    if (logoOverride.isNotEmpty) 'logoUrl': logoOverride,
  };

  factory NeisSchool.fromJson(Map<String, dynamic> j) => NeisSchool(
    name: j['name'] as String,
    code: j['code'] as String,
    officeCode: j['officeCode'] as String? ?? '',
    kind: j['kind'] as String? ?? '',
    grade: j['grade'] as int? ?? 1,
    classNm: j['classNm'] as int? ?? 1,
    homepage: j['homepage'] as String? ?? '',
    slogan: j['slogan'] as String? ?? '',
    // logoOverride는 이전 저장 형식과의 호환용이다.
    logoOverride: j['logoUrl'] as String? ?? j['logoOverride'] as String? ?? '',
  );

  static NeisSchool? load() {
    final raw = LocalStore.instance.getString(StorageKeys.neisSchool);
    if (raw == null) {
      return null;
    }
    try {
      return NeisSchool.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    await LocalStore.instance.setString(
      StorageKeys.neisSchool,
      jsonEncode(toJson()),
    );
  }
}

/// 학사일정 표시 필터 — 다른 학년만 언급한 항목은 숨긴다.
/// 학년 표기가 없으면(=전체 일정) 항상 표시. 내 학년이 포함되면 표시.
bool academicVisibleForGrade(String title, int? grade) {
  if (grade == null || grade <= 0) return true;
  final mentioned = RegExp(
    r'([1-6])\s*학년',
  ).allMatches(title).map((m) => int.parse(m.group(1)!)).toSet();
  return mentioned.isEmpty || mentioned.contains(grade);
}

/// 홈페이지 주소에서 도메인을 뽑아 고화질 아이콘 URL을 만든다.
/// Google faviconV2 는 apple-touch-icon 등 큰 아이콘을 우선 가져와
/// 최대 256px 로고를 돌려준다(없으면 자체 폴백). 기존 s2/favicons(16~32px)보다
/// 학교 로고로 쓰기 적합. 주소가 비었거나 파싱 실패면 null.
String? faviconUrlFor(String homepage) {
  final raw = homepage.trim();
  if (raw.isEmpty) return null;
  // 스킴이 없으면 붙여서 파싱(예: 'www.school.kr').
  final withScheme = raw.startsWith('http') ? raw : 'https://$raw';
  final host = Uri.tryParse(withScheme)?.host ?? '';
  if (host.isEmpty) return null;
  final target = Uri.encodeComponent('https://$host');
  return 'https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON'
      '&fallback_opts=TYPE,SIZE,URL&url=$target&size=256';
}

/// 저화질 폴백(faviconV2 실패 시). Google s2 파비콘(128px).
String? faviconFallbackUrlFor(String homepage) {
  final raw = homepage.trim();
  if (raw.isEmpty) return null;
  final withScheme = raw.startsWith('http') ? raw : 'https://$raw';
  final host = Uri.tryParse(withScheme)?.host ?? '';
  if (host.isEmpty) return null;
  return 'https://www.google.com/s2/favicons?domain=$host&sz=128';
}

/// 학교 공식 홈페이지 HTML에서 교표/로고 후보를 찾는다.
/// 학교명이 붙은 이미지와 `교표`, `school logo` 표기를 가장 우선한다.
String? extractOfficialSchoolLogoUrl(
  String html,
  Uri homepage,
  String schoolName,
) {
  final candidates = <(int, String)>[];
  final normalizedSchool = schoolName.replaceAll(RegExp(r'\s+'), '');

  String? attr(String tag, String name) {
    final match = RegExp(
      '$name\\s*=\\s*(["\'])(.*?)\\1',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(2)?.trim();
  }

  void addCandidate(String? raw, int score) {
    if (raw == null || raw.isEmpty || raw.startsWith('data:')) return;
    final resolved = raw.startsWith('//')
        ? Uri.parse('${homepage.scheme}:$raw')
        : homepage.resolve(raw);
    if (!resolved.isScheme('http') && !resolved.isScheme('https')) return;
    final path = resolved.path.toLowerCase();
    if (path.endsWith('.svg') ||
        path.contains('banner') ||
        path.contains('popup') ||
        path.contains('background')) {
      return;
    }
    candidates.add((score, resolved.toString()));
  }

  final linkTags = RegExp(
    r'<link\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html);
  for (final match in linkTags) {
    final tag = match.group(0)!;
    final rel = attr(tag, 'rel')?.toLowerCase() ?? '';
    if (rel.contains('apple-touch-icon')) {
      addCandidate(attr(tag, 'href'), 88);
    } else if (rel.contains('icon')) {
      addCandidate(attr(tag, 'href'), 62);
    }
  }

  final metaTags = RegExp(
    r'<meta\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html);
  for (final match in metaTags) {
    final tag = match.group(0)!;
    final property = (attr(tag, 'property') ?? attr(tag, 'name') ?? '')
        .toLowerCase();
    if (property == 'og:image' || property == 'twitter:image') {
      addCandidate(attr(tag, 'content'), 72);
    }
  }

  final imageTags = RegExp(
    r'<img\b[^>]*>',
    caseSensitive: false,
  ).allMatches(html);
  for (final match in imageTags) {
    final tag = match.group(0)!;
    final description = [
      attr(tag, 'alt'),
      attr(tag, 'title'),
      attr(tag, 'class'),
      attr(tag, 'id'),
    ].whereType<String>().join(' ').replaceAll(RegExp(r'\s+'), '');
    final lower = description.toLowerCase();
    var score = 0;
    if (normalizedSchool.isNotEmpty && description.contains(normalizedSchool)) {
      score += 70;
    }
    if (description.contains('교표') || description.contains('학교로고')) {
      score += 80;
    }
    if (lower.contains('schoollogo') ||
        lower.contains('emblem') ||
        lower.contains('symbol')) {
      score += 65;
    } else if (lower.contains('logo')) {
      score += 45;
    }
    if (score > 0) {
      addCandidate(attr(tag, 'src') ?? attr(tag, 'data-src'), 80 + score);
    }
  }

  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.$1.compareTo(a.$1));
  return candidates.first.$2;
}

/// Extracts the most likely school emblem from reader-proxy Markdown.
String? extractOfficialSchoolLogoFromMarkdown(
  String markdown,
  String schoolName,
) {
  final normalizedSchool = schoolName.replaceAll(RegExp(r'\s+'), '');
  final candidates = <(int, String)>[];
  final imagePattern = RegExp(
    r'!\[([^\]]*)\]\((https?://[^\s\)]+)',
    caseSensitive: false,
  );

  for (final match in imagePattern.allMatches(markdown)) {
    final alt = (match.group(1) ?? '').replaceAll(RegExp(r'\s+'), '');
    final url = match.group(2);
    if (url == null) continue;
    final uri = Uri.tryParse(url);
    final lower = '$alt $url'.toLowerCase();
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        uri.path.toLowerCase().endsWith('.svg') ||
        lower.contains('banner') ||
        lower.contains('popup') ||
        lower.contains('background')) {
      continue;
    }

    var score = 0;
    if (normalizedSchool.isNotEmpty && alt.contains(normalizedSchool)) {
      score += 70;
    }
    if (alt.contains('교표') || alt.contains('학교로고')) score += 100;
    if (lower.contains('schoollogo') ||
        lower.contains('emblem') ||
        lower.contains('symbol')) {
      score += 70;
    } else if (lower.contains('logo')) {
      score += 50;
    }
    if (score > 0) candidates.add((score, url));
  }

  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.$1.compareTo(a.$1));
  return candidates.first.$2;
}

/// 학교의 공식 홈페이지에서 학교별 교표 URL을 찾아 반환한다.
/// 네트워크/CORS/페이지 구조 문제로 찾지 못하면 호출부가 파비콘으로 폴백한다.
Future<String?> resolveOfficialSchoolLogo({
  required String schoolName,
  required String homepage,
  http.Client? client,
}) async {
  final raw = homepage.trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
  if (uri == null || uri.host.isEmpty) return null;
  final ownedClient = client == null;
  final httpClient = client ?? http.Client();
  try {
    try {
      final response = await httpClient
          .get(
            uri,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (compatible; Surlap/1.0; school-logo-preview)',
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = response.body.length > 1000000
            ? response.body.substring(0, 1000000)
            : response.body;
        final logo = extractOfficialSchoolLogoUrl(
          body,
          response.request?.url ?? uri,
          schoolName,
        );
        if (logo != null) return logo;
      }
    } catch (error) {
      debugPrint(
        '[NEIS] direct school-logo lookup failed ($schoolName): $error',
      );
    }

    // Web builds often cannot read older school sites because of CORS or TLS.
    // The reader endpoint returns the public page as Markdown with image URLs.
    final readerUri = Uri.parse('https://r.jina.ai/${uri.toString()}');
    final readerResponse = await httpClient
        .get(readerUri, headers: const {'Accept': 'text/plain'})
        .timeout(const Duration(seconds: 9));
    if (readerResponse.statusCode < 200 || readerResponse.statusCode >= 300) {
      return null;
    }
    return extractOfficialSchoolLogoFromMarkdown(
      readerResponse.body,
      schoolName,
    );
  } catch (error) {
    debugPrint('[NEIS] school-logo lookup failed ($schoolName): $error');
    return null;
  } finally {
    if (ownedClient) httpClient.close();
  }
}

// 학교 검색
Future<List<Map<String, dynamic>>> searchSchools(String query) async {
  final uri = Uri.parse(
    '$_base/schoolInfo?KEY=$_neisKey&Type=json&pSize=10&SCHUL_NM=${Uri.encodeComponent(query)}',
  );
  debugPrint('[NEIS] 1) 학교 검색 → "$query"');
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    debugPrint('[NEIS] 학교 검색 HTTP ${res.statusCode}');
    return [];
  }
  try {
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['RESULT'] != null) {
      debugPrint('[NEIS] 학교 검색 결과 없음: ${(j['RESULT'] as Map?)?['MESSAGE']}');
      return [];
    }
    final rows = j['schoolInfo']?[1]['row'] as List? ?? [];
    debugPrint('[NEIS] 학교 ${rows.length}건 검색됨');
    return rows.cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('[NEIS] 학교 검색 파싱 오류: $e');
    return [];
  }
}

// 시간표 조회
Future<Map<int, String>?> fetchTimetable(NeisSchool school, String date) async {
  if (school.officeCode.isEmpty) {
    debugPrint('[NEIS] 시간표: 교육청코드(ATPT_OFCDC_SC_CODE) 없음 — 학교 재연결 필요');
    return null;
  }
  final apiName = _timetableApiName(school.kind);
  if (apiName == null) {
    debugPrint('[NEIS] 시간표: 지원하지 않는 학교 종류 "${school.kind}"');
    return null;
  }

  final uri = Uri.parse(
    '$_base/$apiName?KEY=$_neisKey&Type=json&pSize=100'
    '&ATPT_OFCDC_SC_CODE=${school.officeCode}'
    '&SD_SCHUL_CODE=${school.code}'
    '&TI_FROM_YMD=$date&TI_TO_YMD=$date'
    '&GRADE=${school.grade}&CLASS_NM=${school.classNm}',
  );
  debugPrint(
    '[NEIS] 2) 시간표 호출 $apiName $date '
    '(${school.grade}학년 ${school.classNm}반)',
  );

  final res = await http.get(uri);
  if (res.statusCode != 200) {
    debugPrint('[NEIS] 시간표 HTTP ${res.statusCode}');
    return null;
  }
  try {
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['RESULT'] != null) {
      debugPrint(
        '[NEIS] 시간표 데이터 없음 ($date): ${(j['RESULT'] as Map?)?['MESSAGE']}',
      );
      return {};
    }
    final rows = j[apiName]?[1]['row'] as List? ?? [];
    final result = <int, String>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final period = int.tryParse(row['PERIO']?.toString() ?? '') ?? 0;
      final subject = row['ITRT_CNTNT']?.toString() ?? '';
      if (period > 0 && subject.isNotEmpty) {
        result[period] = subject;
      }
    }
    debugPrint('[NEIS] 시간표 $date → ${result.length}교시 수신 $result');
    return result;
  } catch (e) {
    debugPrint('[NEIS] 시간표 파싱 오류 ($date): $e');
    return null;
  }
}

/// 하루 급식(기숙사 학교는 조식·중식·석식 모두). MMEAL_SC_CODE 1=조식·2=중식·3=석식.
class SchoolMeals {
  final String? breakfast;
  final String? lunch;
  final String? dinner;
  const SchoolMeals({this.breakfast, this.lunch, this.dinner});
  bool get isEmpty => breakfast == null && lunch == null && dinner == null;
}

String _cleanMenu(String raw) =>
    raw.replaceAll('<br/>', '\n').replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

/// 그 날 급식 전체(조/중/석) 조회.
Future<SchoolMeals?> fetchMeals(NeisSchool school, String date) async {
  if (school.officeCode.isEmpty) return null;
  final uri = Uri.parse(
    '$_base/mealServiceDietInfo?KEY=$_neisKey&Type=json&pSize=10'
    '&ATPT_OFCDC_SC_CODE=${school.officeCode}'
    '&SD_SCHUL_CODE=${school.code}'
    '&MLSV_FROM_YMD=$date&MLSV_TO_YMD=$date',
  );
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    debugPrint('[NEIS] 급식 HTTP ${res.statusCode}');
    return null;
  }
  try {
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['RESULT'] != null) {
      debugPrint('[NEIS] 급식 없음 ($date): ${(j['RESULT'] as Map?)?['MESSAGE']}');
      return null;
    }
    final rows = j['mealServiceDietInfo']?[1]['row'] as List? ?? [];
    String? b, l, d;
    for (final r in rows) {
      final menu = _cleanMenu(r['DDISH_NM']?.toString() ?? '');
      if (menu.isEmpty) continue;
      switch (r['MMEAL_SC_CODE']?.toString()) {
        case '1':
          b = menu;
          break;
        case '2':
          l = menu;
          break;
        case '3':
          d = menu;
          break;
        default:
          l ??= menu; // 코드 없으면 중식 취급
      }
    }
    return SchoolMeals(breakfast: b, lunch: l, dinner: d);
  } catch (e) {
    debugPrint('[NEIS] 급식 파싱 오류 ($date): $e');
    return null;
  }
}

// 급식(중식) 조회 — 시간표 급식 행/캐시용. 기숙사면 조식이 먼저 와도 중식 우선.
Future<String?> fetchLunch(NeisSchool school, String date) async {
  final m = await fetchMeals(school, date);
  return m?.lunch ?? m?.breakfast ?? m?.dinner;
}

// 학사일정 한 건.
class AcademicEvent {
  final String dateKey; // 'YYYY-MM-DD'
  final String name; // EVENT_NM
  final String content; // EVENT_CNTNT
  const AcademicEvent({
    required this.dateKey,
    required this.name,
    required this.content,
  });
}

// 학사일정 조회 (SchoolSchedule) — 시간표/급식과 동일 패턴, 같은 NEIS 설정 재사용.
// from/to: 'YYYYMMDD'. 학교 미연결(officeCode 비어있음)이면 빈 결과.
Future<List<AcademicEvent>> fetchSchoolSchedule(
  NeisSchool school,
  String from,
  String to,
) async {
  if (school.officeCode.isEmpty) {
    debugPrint('[NEIS] 학사일정: 교육청코드 없음 — 학교 재연결 필요');
    return [];
  }
  final uri = Uri.parse(
    '$_base/SchoolSchedule?KEY=$_neisKey&Type=json&pSize=1000'
    '&ATPT_OFCDC_SC_CODE=${school.officeCode}'
    '&SD_SCHUL_CODE=${school.code}'
    '&AA_FROM_YMD=$from&AA_TO_YMD=$to',
  );
  debugPrint('[NEIS] 학사일정 호출 $from~$to');

  final res = await http.get(uri);
  if (res.statusCode != 200) {
    debugPrint('[NEIS] 학사일정 HTTP ${res.statusCode}');
    return [];
  }
  try {
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['RESULT'] != null) {
      debugPrint('[NEIS] 학사일정 데이터 없음: ${(j['RESULT'] as Map?)?['MESSAGE']}');
      return [];
    }
    final rows = j['SchoolSchedule']?[1]['row'] as List? ?? [];
    final result = <AcademicEvent>[];
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final ymd = (row['AA_YMD']?.toString() ?? '').trim(); // YYYYMMDD
      if (ymd.length != 8) continue;
      final name = (row['EVENT_NM']?.toString() ?? '').trim();
      final content = (row['EVENT_CNTNT']?.toString() ?? '').trim();
      final label = name.isNotEmpty ? name : content;
      if (label.isEmpty) continue;
      final dateKey =
          '${ymd.substring(0, 4)}-${ymd.substring(4, 6)}-${ymd.substring(6, 8)}';
      result.add(
        AcademicEvent(dateKey: dateKey, name: label, content: content),
      );
    }
    debugPrint('[NEIS] 학사일정 ${result.length}건 수신');
    return result;
  } catch (e) {
    debugPrint('[NEIS] 학사일정 파싱 오류: $e');
    return [];
  }
}

String? _timetableApiName(String kind) {
  if (kind.contains('고등')) {
    return 'hisTimetable';
  }
  if (kind.contains('중학')) {
    return 'misTimetable';
  }
  if (kind.contains('초등')) {
    return 'elsTimetable';
  }
  return null;
}
