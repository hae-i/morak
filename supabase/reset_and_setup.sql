-- ==========================================
-- Morak DB 초기화 및 통합 재설정 스크립트
-- 작성일: 2026-10-06 / 파일만 작성했으며 DB에는 실행하지 않았습니다.
-- ==========================================
-- === 수정한 내용: 기존 테이블 설정에 C1/H7 RPC를 포함하고 초기화 범위와 H4 외부 설정을 명시한다 ===
-- 주의: 아래 DROP TABLE은 앱의 기존 데이터와 종속 객체를 삭제합니다.
-- 실행 전 백업하고 Supabase SQL Editor에서 전체를 하나의 작업으로 실행할 용도입니다.
-- auth.users의 로그인 계정, storage의 실제 파일, Dashboard 설정은 초기화하지 않습니다.
-- Auth 계정이 남더라도 public.users 프로필은 삭제되어 앱에서 프로필 재설정이 필요합니다.
-- 기존 공개 bucket 및 광범위한 authenticated RLS 정책을 유지한 개발/재설정용입니다.
-- 이 정책은 다른 로그인 사용자의 데이터 조작을 막지 않습니다. 보안 완료본이 아닙니다.
-- SQL이 중간에 실패하면 COMMIT되지 않도록 전체를 트랜잭션으로 묶었습니다.
-- 파일 일부만 선택해서 실행하지 마세요.

BEGIN;

-- ==========================================
-- 0. 앱 테이블 및 이번에 관리하는 RPC 초기화
-- ==========================================
-- === 수정한 내용: 이미 적용된 RPC도 재생성하여 함수 중복 오류를 방지한다 ===
DROP FUNCTION IF EXISTS public.save_meetup_atomic(jsonb, jsonb, text);
DROP FUNCTION IF EXISTS public.create_group_atomic(uuid, jsonb, jsonb);
DROP TABLE IF EXISTS public.attendances, public.meetups, public.group_members, public.groups, public.users CASCADE;

-- ==========================================
-- 1. 테이블 생성: 현재 Flutter 모델/Repository의 컬럼 유지
-- ==========================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL CHECK (char_length(trim(display_name)) > 0),
  profile_image_url TEXT,
  birthday DATE,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (char_length(trim(name)) > 0),
  theme_color TEXT,
  theme_emoji TEXT,
  cover_image_url TEXT,
  logo_image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE public.group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL CHECK (char_length(trim(display_name)) > 0),
  role TEXT DEFAULT 'member' NOT NULL CHECK (role IN ('host', 'member')),
  profile_image_url TEXT,
  bio TEXT,
  -- H6 관련 쿼리: 가입 시 선택한 생일 공개 여부를 저장하는 기존 컬럼 유지.
  is_birthday_public BOOLEAN DEFAULT true,
  joined_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT unique_group_user UNIQUE (group_id, user_id)
);

CREATE TABLE public.meetups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  title TEXT,
  meet_date TIMESTAMPTZ NOT NULL,
  location TEXT,
  menu TEXT,
  photos TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE TABLE public.attendances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meetup_id UUID NOT NULL REFERENCES public.meetups(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES public.group_members(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  UNIQUE (meetup_id, member_id)
);

-- ==========================================
-- 2. Storage bucket 및 기존 정책 재설정
-- ==========================================
-- 실제 사진 파일은 삭제하지 않습니다. 기존 bucket의 public/크기/MIME 설정도 바꾸지 않습니다.
-- 새 bucket은 기존 앱의 getPublicUrl 사용에 맞춰 public=true로 생성합니다.
INSERT INTO storage.buckets (id, name, public) VALUES
  ('profiles', 'profiles', true),
  ('group_covers', 'group_covers', true),
  ('meetup_photos', 'meetup_photos', true)
ON CONFLICT (id) DO NOTHING;

-- === 수정한 내용: Storage 테이블은 남으므로 동일 이름의 기존 정책을 먼저 제거해 재실행 오류를 막는다 ===
-- 아래 이름 이외의 사용자 정책은 삭제하지 않습니다. 추가 정책이 있으면 별도로 확인하세요.
DROP POLICY IF EXISTS "프로필 사진 누구나 보기 가능" ON storage.objects;
DROP POLICY IF EXISTS "프로필 사진 조작은 로그인한 유저만" ON storage.objects;
DROP POLICY IF EXISTS "커버 누구나 보기 가능" ON storage.objects;
DROP POLICY IF EXISTS "커버 조작은 로그인한 유저만" ON storage.objects;
DROP POLICY IF EXISTS "기록 사진 누구나 보기 가능" ON storage.objects;
DROP POLICY IF EXISTS "기록 사진 조작은 로그인한 유저만" ON storage.objects;

CREATE POLICY "프로필 사진 누구나 보기 가능" ON storage.objects FOR SELECT USING (bucket_id = 'profiles');
CREATE POLICY "프로필 사진 조작은 로그인한 유저만" ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'profiles') WITH CHECK (bucket_id = 'profiles');
CREATE POLICY "커버 누구나 보기 가능" ON storage.objects FOR SELECT USING (bucket_id = 'group_covers');
CREATE POLICY "커버 조작은 로그인한 유저만" ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'group_covers') WITH CHECK (bucket_id = 'group_covers');
CREATE POLICY "기록 사진 누구나 보기 가능" ON storage.objects FOR SELECT USING (bucket_id = 'meetup_photos');
CREATE POLICY "기록 사진 조작은 로그인한 유저만" ON storage.objects FOR ALL TO authenticated
  USING (bucket_id = 'meetup_photos') WITH CHECK (bucket_id = 'meetup_photos');

-- ==========================================
-- 3. 앱 테이블 RLS 및 클라이언트 역할 권한
-- ==========================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendances ENABLE ROW LEVEL SECURITY;

-- === 수정한 내용: 재생성된 테이블의 authenticated 권한을 기본 grant 설정에 의존하지 않고 명시한다 ===
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users, public.groups, public.group_members,
  public.meetups, public.attendances TO authenticated;
-- 위 GRANT는 RLS를 우회하지 않습니다. 실제 행 접근은 아래 정책으로 결정됩니다.
CREATE POLICY "로그인한 유저는 프로필 조회 가능" ON public.users FOR SELECT TO authenticated USING (true);
CREATE POLICY "본인 프로필만 생성 가능" ON public.users FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "본인 프로필만 수정 가능" ON public.users FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 원본과 동일한 개발용 정책입니다. 모임 멤버/방장별 권한 제한을 적용한 정책이 아닙니다.
CREATE POLICY "Enable all for authenticated users on groups" ON public.groups
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for authenticated users on group_members" ON public.group_members
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for authenticated users on meetups" ON public.meetups
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Enable all for authenticated users on attendances" ON public.attendances
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ==========================================
-- 4. H4 관련 안내: DB에 적용할 쿼리는 없습니다.
-- ==========================================
-- H4는 iOS Google 로그인 client ID 및 callback URL scheme 누락 문제입니다.
-- 이 항목은 SQL로 해결할 수 없으므로 H4 관련 DB 함수/테이블을 만들지 않습니다.
-- ios/Flutter/GoogleSignIn.xcconfig에 GOOGLE_IOS_CLIENT_ID와
-- GOOGLE_IOS_REVERSED_CLIENT_ID를 실제 발급값으로 설정해야 합니다.
-- Supabase Dashboard Google provider/redirect 설정과 실기기 복귀도 따로 확인하세요.

-- ==========================================
-- 5. C1 관련 쿼리: 만남 기록 및 출석 원자적 저장 RPC
-- ==========================================
-- === 수정한 내용: 만남 수정과 출석 교체를 하나의 트랜잭션으로 처리하여 중간 실패의 데이터 손실을 방지한다 ===
-- Apply before releasing the client that calls save_meetup_atomic.
-- Existing table grants and RLS policies remain authoritative.
create function public.save_meetup_atomic(
  p_meetup jsonb,
  p_member_ids jsonb,
  p_meetup_id text default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_data public.meetups%rowtype;
  v_target public.meetups%rowtype;
  v_saved_id public.meetups.id%type;
  v_attendances jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_meetup is null or jsonb_typeof(p_meetup) <> 'object'
      or p_member_ids is null or jsonb_typeof(p_member_ids) <> 'array' then
    raise exception 'Invalid meetup payload' using errcode = '22023';
  end if;

  -- Use the deployed column types, including the photos column type.
  select * into v_data
  from jsonb_populate_record(null::public.meetups, p_meetup);

  if p_meetup_id is null then
    insert into public.meetups (
      group_id, title, meet_date, location, menu, photos
    ) values (
      v_data.group_id, v_data.title, v_data.meet_date,
      v_data.location, v_data.menu, v_data.photos
    ) returning id into v_saved_id;
  else
    select * into v_target
    from jsonb_populate_record(
      null::public.meetups, jsonb_build_object('id', p_meetup_id)
    );

    -- Serialize edits to the same meetup before replacing its attendances.
    select m.id into v_saved_id
    from public.meetups as m
    where m.id = v_target.id
    for update;

    if not found then
      raise exception 'Meetup unavailable' using errcode = '42501';
    end if;

    update public.meetups set
      group_id = v_data.group_id,
      title = v_data.title,
      meet_date = v_data.meet_date,
      location = v_data.location,
      menu = v_data.menu,
      photos = v_data.photos
    where id = v_saved_id
    returning id into v_saved_id;

    -- RLS may filter an UPDATE without producing a database error.
    if not found then
      raise exception 'Meetup update denied' using errcode = '42501';
    end if;

    delete from public.attendances where meetup_id = v_saved_id;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object(
      'meetup_id', v_saved_id, 'member_id', member_id
    )), '[]'::jsonb
  ) into v_attendances
  from jsonb_array_elements(p_member_ids) as selected(member_id);

  insert into public.attendances (meetup_id, member_id)
  select a.meetup_id, a.member_id
  from jsonb_populate_recordset(
    null::public.attendances, v_attendances
  ) as a;

  -- Do not catch errors here: every DB write must roll back on failure.
end;
$$;

revoke all on function public.save_meetup_atomic(jsonb, jsonb, text)
  from public, anon;
grant execute on function public.save_meetup_atomic(jsonb, jsonb, text)
  to authenticated;


-- ==========================================
-- 6. H7 관련 쿼리: 그룹과 최초 방장을 원자적으로 생성하는 RPC
-- ==========================================
-- Flutter GroupRepository.createGroup에서 호출합니다.
-- 같은 생성 요청 UUID는 중복 그룹 대신 기존 결과를 반환합니다.
-- user_id와 host 역할은 클라이언트 값이 아닌 함수 내부에서 결정합니다.
-- === 수정한 내용: 그룹과 최초 방장을 하나의 트랜잭션으로 생성하고 같은 요청의 재시도를 중복 저장하지 않는다 ===
-- 검토용 파일이며 실제 DB에는 실행하지 않았습니다.
create function public.create_group_atomic(
  p_group_id uuid,
  p_group jsonb,
  p_member jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_group public.groups%rowtype;
  v_member public.group_members%rowtype;
  v_id public.groups.id%type;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_group_id is null or p_group is null or jsonb_typeof(p_group) <> 'object'
      or p_member is null or jsonb_typeof(p_member) <> 'object' then
    raise exception 'Invalid group payload' using errcode = '22023';
  end if;
  select * into v_group from jsonb_populate_record(null::public.groups, p_group);
  select * into v_member from jsonb_populate_record(null::public.group_members, p_member);
  if coalesce(btrim(v_group.name), '') = ''
      or coalesce(btrim(v_member.display_name), '') = ''
      or v_member.is_birthday_public is null then
    raise exception 'Invalid group fields' using errcode = '22023';
  end if;

  -- SERIALIZE 동일 UUID 요청; 선행 트랜잭션 실패 시 다음 요청이 정상 생성합니다.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_group_id::text, 0));
  select g.id into v_id from public.groups g where g.id = p_group_id;
  if found then
    if not exists (
      select 1 from public.group_members m
      where m.group_id = v_id and m.user_id = auth.uid() and m.role = 'host'
    ) then
      raise exception 'Group unavailable' using errcode = '42501';
    end if;
    return jsonb_build_object('id', v_id, 'created', false);
  end if;

  insert into public.groups(id, name, theme_color, theme_emoji, cover_image_url, logo_image_url)
  values (p_group_id, v_group.name, v_group.theme_color, v_group.theme_emoji,
    v_group.cover_image_url, v_group.logo_image_url)
  returning id into v_id;
  insert into public.group_members(group_id, user_id, role, display_name, profile_image_url, is_birthday_public)
  values (v_id, auth.uid(), 'host', v_member.display_name,
    v_member.profile_image_url, v_member.is_birthday_public);
  return jsonb_build_object('id', v_id, 'created', true);
end;
$$;
revoke all on function public.create_group_atomic(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.create_group_atomic(uuid, jsonb, jsonb) to authenticated;


-- ==========================================
-- 7. 별도 확인 항목 및 완료
-- ==========================================
-- 기존 delete_user() 함수는 첨부 SQL에 정의가 없어 재작성/삭제하지 않았습니다.
-- 테이블 DROP CASCADE로 소실된 별도 view/function/trigger는 자동 복원되지 않습니다.
-- 따라서 기존 회원탈퇴 RPC와 사용자 정의 객체는 실행 전 정의를 백업하고 확인해야 합니다.
-- Auth 계정 전체 삭제나 Storage 파일 전체 삭제가 필요하면 별도의 명시적인 작업이 필요합니다.
-- 이 파일은 5개 앱 테이블과 C1/H7 RPC를 재설정하는 스크립트입니다.
COMMIT;