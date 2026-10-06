<!-- === 수정한 내용: 작성자·부방장·탈퇴 이력에 필요한 최신 추가 SQL과 적용 전제를 안내한다 === -->
최신 앱에 필요한 추가 변경: [20261007000000_membership_history_and_authors.sql](migrations/20261007000000_membership_history_and_authors.sql).
사용자가 앞선 사진 비공개/방장 위임 SQL 적용 및 실기기 성공을 확인했습니다.
새 SQL은 그 상태에서 추가 적용하는 파일이며 아직 실행하지 않았습니다.
[검증/변경 파일/적용 순서](../docs/membership_history_and_authors.md)를 먼저 확인하세요.
새 컬럼/RPC가 필요하므로 추가 SQL을 검증·적용한 후 새 앱을 실행합니다.
초기화 SQL과 이전 정책 통합본을 다시 실행하면 안 됩니다. 아래 설명은 이전 작성 시점의 기록입니다.

<!-- === 수정한 내용: 사진 비공개·방장 위임 정책을 포함하는 최신 데이터 보존용 SQL을 우선 안내한다 === -->
현재 정책의 최신 적용안은 [apply_private_photos_and_host_rules.sql](apply_private_photos_and_host_rules.sql)입니다.
먼저 [읽기 전용 확인](verify_private_photos_and_host_rules.sql)을 실행하고 별도 테스트 프로젝트에서 검증하세요.
실제 DB 적용과 SQL 테스트는 아직 실행하지 않았습니다.
아래 개별 정책 초안을 함께 추가 적용하거나 reset SQL을 다시 실행하지 마세요.
화면·클라이언트 변경과 순서는 [최신 작업 기록](../docs/private_photos_and_host_rules.md)에 있습니다.

# C1: atomic meetup and attendance saves

<!-- === 수정한 내용: 사용자 DB 적용 완료와 추가 데이터 보존용 SQL의 순서를 안내한다 === -->
사용자가 기존 초기화/C1/H7 DB 적용 완료를 확인했습니다. 아래 설명은 이전 작성 시점의 기록입니다.
기존 `reset_and_setup.sql`을 다시 실행하지 마세요. 새 추가 SQL은 아직 실행하지 않았습니다.
`check_current_configuration.sql`로 읽기 전용 확인 후 staging에서
`migrations/20261006010000_group_summary.sql`,
`migrations/20261006020000_access_policies.sql` 순서로 검증합니다.
권한 SQL은 실행 검증 전 초안이며 현재 데이터를 보존합니다. 정책 변경 후에는 H7 함수가
SECURITY DEFINER로 바뀌므로 기존 INVOKER 전제의 SQL 테스트만으로 충분하지 않습니다.
현재 구현·외부 검증 범위는 [app_completion.md](../docs/app_completion.md)에 정리했습니다.

<!-- === 수정한 내용: 실제 조회 결과와 본인 탈퇴 함수 권한 보완 SQL을 연결한다 === -->
사용자 제공 실제 조회 결과는 [current_database_review.md](../docs/current_database_review.md)에 기록했습니다.
`migrations/20261006030000_delete_user_permissions.sql`은 기존 본인 탈퇴 계약을 유지하고
익명 실행 권한을 제거하는 추가 초안입니다. DB에는 실행하지 않았으며 별도 테스트 계정으로 검증해야 합니다.

<!-- === 수정한 내용: DB 초기화용 통합본의 경로와 삭제 범위 및 H4/H7 구분을 안내한다 === -->
## 초기화 후 통합 재설정

`reset_and_setup.sql`은 첨부된 기존 테이블/Storage/RLS 구성에 C1과 H7 RPC를
합친 독립 실행용 파일입니다. 실제 DB에 실행하지 않았습니다.
전체 파일을 하나의 트랜잭션으로 구성하고 기존 RPC와 동일 이름의 Storage 정책을
재생성하도록 했습니다. 개별 migration을 추가 실행할 필요는 없습니다.

- **5개 앱 테이블의 데이터와 CASCADE 종속 객체를 삭제합니다.** 기존 데이터 유지용 migration이 아닙니다.
- Auth 로그인 계정과 Storage 파일은 삭제하지 않습니다. 기존 사용자는 프로필을 다시 설정해야 합니다.
- 원본의 광범위한 authenticated 정책을 유지하므로 보안 정책 개선 완료본이 아닙니다.
- `H4 관련 안내`에는 SQL로 해결할 수 없는 iOS OAuth 설정을,
  `H7 관련 쿼리`에는 `create_group_atomic` 함수를 표시했습니다.
- 첨부에 정의가 없는 `delete_user()` 및 별도 view/trigger/function은 복원하지 않습니다.
  실행 전 정의를 백업하고 초기화 후 존재 여부와 권한을 확인해야 합니다.
- 기존 bucket 설정은 변경하지 않습니다. 비공개로 설정된 기존 bucket과 별도 Storage 정책은 따로 확인합니다.

아래 설명의 개별 migration 적용 순서는 데이터를 보존하여 업데이트하는 경우의 안내입니다.

Apply `migrations/20261005000000_save_meetup_atomic.sql` to a staging database
before releasing the updated Flutter client. This repository does not contain
the existing database schema, RLS policies, or a Supabase CLI configuration.
Do not treat this migration as a complete database bootstrap.

The function uses `SECURITY INVOKER`, an empty `search_path`, an authenticated
user check, and existing table permissions/RLS. It does not add table grants,
change policies, or use a service-role key. Verify RLS is enabled and that the
existing intended users can SELECT/INSERT/UPDATE meetups and SELECT/DELETE/INSERT
attendances. Policies must expose all attendances the caller is allowed to
replace; silently filtered DELETE rows will otherwise remain, as with the old
client. A denied or missing meetup UPDATE now raises an error instead of
continuing to delete its attendances.

The migration assumes the tables and columns already referenced by the app:
`public.meetups(id, group_id, title, meet_date, location, menu, photos)` and
`public.attendances(meetup_id, member_id)`. Row types perform conversions using
the actual database column types. Defaults, foreign keys, triggers, and policies
must be checked in staging; they cannot be verified from this repository.

## Validation

Client regression tests use a local HTTP server and do not verify PostgreSQL
transaction behavior. They reproduce the old partial-write failure and verify
that the new client makes one RPC request, preserves its error, and never falls
back to separate destructive writes.

`tests/save_meetup_atomic_test.sql` is an integration test for a **disposable,
empty PostgreSQL database only**. It creates fixture tables and auth helpers,
loads the migration, verifies real rollback after a failed attendance INSERT,
and rolls back all fixtures. It is not a script for a deployed Supabase project.
Run with `psql -X -v ON_ERROR_STOP=1 -d <disposable_database> -f
supabase/tests/save_meetup_atomic_test.sql`.

Also verify in staging with actual authenticated users:

- Failed attendance insertion restores the old meetup and all old attendances.
- Failed creation leaves neither a meetup nor attendances.
- Successful creation/edit and intentionally empty attendance lists work.
- Existing unauthorized users remain unable to write through the RPC.
- Two edits of the same meetup do not interleave attendance replacements.

Photo uploads still happen before the RPC and are not part of the DB transaction.
New uploads are cleaned after a definite DB rejection; shared existing files are
preserved. Meetup creation retry idempotency is not added by this C1 RPC. A lost response
after the server commits remains an ambiguous success, but does not produce a
partially committed meetup/attendance replacement.

## Deployment order

1. Check the live schema and permissions, apply the migration in staging, and
   complete the DB validation above.
2. Apply the migration to the target Supabase database before updating the app.
3. Release the app only after the RPC is available to authenticated users.

Old clients retain their separate-write behavior until they are updated. The new
client propagates a missing/denied RPC as a save failure; it deliberately does not
fall back to the old non-atomic flow. Cloudflare configuration is unchanged.

<!-- === 수정한 내용: 최초 방장 원자적 생성과 미실행 테스트 및 기존 SQL 주의사항을 안내한다 === -->
## H7: atomic group and initial host creation

`migrations/20261006000000_create_group_atomic.sql` adds
`create_group_atomic(uuid,jsonb,jsonb)`. It inserts `groups` and the first
`group_members` host in one transaction, returns `{id, created}`, and forces
`user_id = auth.uid()` and `role = 'host'`. A same-UUID retry returns
`created:false` only if the caller can read that group and its host membership.
An advisory lock serializes same-ID requests. Already committed requests return
the original group rather than modifying its fields.

No tables or policies are added. Required group columns are UUID `id`, `name`,
`theme_color`, `theme_emoji`, `cover_image_url`, `logo_image_url`. Member columns
are `group_id`, `user_id`, `role`, `display_name`, `profile_image_url`,
`is_birthday_public`; IDs/joined_at retain existing defaults. The supplied SQL has
these columns, but the live DB may differ. RLS must permit creator insert,
initial host insert and retry SELECT. SECURITY INVOKER does not bypass RLS.

`tests/create_group_atomic_test.sql` is for an empty disposable PostgreSQL DB
only. It verifies rollback after denied host insertion, forced identity/role,
privacy, retries and anonymous/different-user rejection. Run with `psql -X -v
ON_ERROR_STOP=1 -d <disposable_database> -f supabase/tests/create_group_atomic_test.sql`.
It has not been run here. Neither migration was executed against live Supabase.

The historical supplied SQL starts with `DROP TABLE ... CASCADE` and includes
permissive authenticated-all table/storage policies. Do not rerun it on existing
data. Atomic transactions do not make those policies secure. Check actual
policies, triggers/defaults and authorized/unauthorized users in staging before
applying either migration. Checkbox privacy does not restrict server access to
`users.birthday` or public photo URLs.
