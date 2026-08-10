/// 사용자 유형 — 로그인 없이 온보딩에서 1회 선택, 기기에 로컬 저장.
///
/// 유형에 따라 "데이터"가 달라진다(레이아웃은 동일):
/// - 초/중/고: NEIS 학교 연동(시간표·급식·학사일정) 가능
/// - 대학생/일반인: 학교 연동 없이 일반 캘린더처럼 사용
enum UserType {
  general,     // 일반인
  elementary,  // 초등학생
  middle,      // 중학생
  high,        // 고등학생
  university;  // 대학생

  /// 저장/복원용 안정적인 문자열 키 (enum 순서 변경에도 안전하도록 name 사용).
  String get storageValue => name;

  static UserType? fromStorage(String? raw) {
    if (raw == null) return null;
    for (final t in UserType.values) {
      if (t.name == raw) return t;
    }
    return null;
  }

  String get label => switch (this) {
        UserType.general => '일반',
        UserType.elementary => '초등학생',
        UserType.middle => '중학생',
        UserType.high => '고등학생',
        UserType.university => '대학생',
      };

  String get emoji => switch (this) {
        UserType.general => '🙂',
        UserType.elementary => '🎒',
        UserType.middle => '📘',
        UserType.high => '🎓',
        UserType.university => '🏛️',
      };

  /// 온보딩 카드에 쓰는 한 줄 설명.
  String get tagline => switch (this) {
        UserType.general => '학교 없이 일정·할 일 중심으로',
        UserType.elementary => '시간표·급식·학사일정 자동',
        UserType.middle => '시간표·급식·학사일정 자동',
        UserType.high => '시간표·급식·학사일정 자동',
        UserType.university => '시간표는 직접 입력, 일정 중심',
      };

  /// NEIS(초·중·고)로 학교 연동이 가능한 유형인가.
  bool get isSchoolStudent =>
      this == UserType.elementary ||
      this == UserType.middle ||
      this == UserType.high;

  /// 급식 데이터를 사용하는가(초·중·고만).
  bool get usesMeal => isSchoolStudent;

  /// 시간표를 NEIS에서 자동으로 받아오는가(초·중·고만).
  /// 대학생/일반인도 스케줄표는 쓰지만 "직접 입력"이다.
  bool get usesSchoolTimetable => isSchoolStudent;

  /// 학년 최대값 — 초등 6, 중·고 3, 그 외 1.
  int get maxGrade => switch (this) {
        UserType.elementary => 6,
        UserType.middle || UserType.high => 3,
        _ => 1,
      };
}

/// NEIS 학교 종류 문자열(SCHUL_KND_SC_NM)로부터 학년 최대값을 구한다.
/// 초등학교 → 6, 그 외(중/고) → 3.
int maxGradeForSchoolKind(String kind) {
  if (kind.contains('초등')) return 6;
  return 3;
}

/// NEIS 학교 종류(SCHUL_KND_SC_NM)에서 사용자 유형을 유추한다.
///
/// 핸드오프 F1: 학교를 먼저 고르면 학교 종류에서 사용자 유형을 유추한다.
/// 판단이 서지 않으면 null 을 돌려 사용자가 직접 고르게 둔다.
UserType? inferUserType(String schoolKind) {
  if (schoolKind.contains('초등')) return UserType.elementary;
  if (schoolKind.contains('중학')) return UserType.middle;
  if (schoolKind.contains('고등')) return UserType.high;
  return null;
}
