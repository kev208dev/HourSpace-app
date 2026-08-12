// Supabase 프로젝트 URL / publishable(anon) 키.
// 빌드 시 --dart-define 으로 덮어쓸 수 있고, 없으면 아래 기본값을 사용한다.
//
// 여기 들어가는 키는 "publishable(anon)" 키로, 클라이언트에 노출되도록 설계된
// 공개 키다(데이터 보호는 Supabase의 RLS가 담당).
//
// secret 키(sb_secret_… / service_role JWT)는 RLS 를 우회하므로 절대 넣지 않는다.
// 새 키 체계에서는 sb_publishable_… 문자열이 예전 anon JWT 자리를 그대로 대신한다.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://enejjngrffugopgqeuxg.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_jQljuAxrNJyJi36FDoH9AQ_065D9_tx',
);
