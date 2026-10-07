# 참고 화면에 맞춘 검색창 수정

상단 ‘만난 장소 찾기’ 제목과 검색창을 감싸는 흰색 패널을 제거했다. 지도 위에 뒤로 버튼·공통 입력창·44×44 원형 엔터 모양 검색 버튼만 표시한다. 입력 힌트는 ‘장소 검색하기’, 하단 안내는 ‘검색하거나 지도를 길게 눌러 장소를 선택해 주세요’다. 이 수정은 앱 화면만 변경한다. 관련 화면 테스트 7개 통과, 분석 오류/경고 0(info 28개).

# 최신 수정: 지도 전체 화면과 자동 검색

같은 `feature/restore-screens-and-improve-map-picker` 브랜치에서 이어서 수정했다. 사용자는 이전 검색 함수 배포 후 검색이 동작한다고 확인했다.

- 장소 선택은 처음부터 지도 전체 화면이다. 검색창은 지도 위에 떠 있고, 입력/검색 버튼 높이를 약 40px로 줄였다.
- 제목은 앱 본문 textTheme의 글꼴을 사용한다. 결과 패널 상단 패딩은 4px, 목록 자체 패딩은 0이다.
- 장소/주소와 지도 주변/전체 지역 선택을 제거했다. 입력이 도로명·지번 주소 형태면 주소를 우선 조회한다. 그 외에는 가게 이름 후보를 조회하며, 일치 후보가 없고 Maps 서버 인증이 준비되어 있으면 주소로 재조회한다. 자동 판별은 모든 모호한 단어의 뜻을 확정하지 않으며 두 검색 경로로 보완한다.
- 앱은 `mode:auto`, `name_only:true`를 보낸다. 초기 시청 좌표를 검색어의 지역으로 붙이지 않는다. 지도 중심은 후보 거리 정렬/주소 우선순위에만 사용한다. 결과를 얻으면 기존 지도 로직이 모든 후보 핀 범위로 이동한다. 검색 결과가 없을 때의 시청 화면은 지도 초기 카메라 위치이며 검색 범위 제한이 아니다. GPS를 새로 요청하지 않았다.
- 가게 이름 검색에서는 정규화한 상호명에 입력한 가게 이름이 포함된 후보만 표시한다. 지역명이 명시된 경우 지역 토큰은 이름 일치 검사에서 제외한다. 메뉴·설명에만 검색어가 들어간 결과는 제외한다. 네이버 지역 검색은 상호명 전용 서버 필터를 제공하지 않고 후보가 최대 5개라 실제 가게가 후보에서 누락되는 한계는 남는다. 클라이언트 필터로 전체 네이버 장소 DB를 검색할 수는 없다.

**이 수정은 새 SQL이 필요하지 않으며, 변경된 검색 함수를 다시 배포해야 한다.** 앞선 장소 SQL 2개의 적용 상태는 유지한다. 새 앱과 새 서버를 함께 사용해야 자동 검색과 이름 필터가 적용된다. 아래 명령은 저장소 루트에서 실행한다.

```bash
npx supabase functions deploy naver-place-search --project-ref <프로젝트-ID> --no-verify-jwt --use-api
```

이전 `place`/`address` 요청도 서버에서 계속 지원한다. 실제 서버에는 이번 수정본을 자동 배포하지 않았다.

---

# 로그인·홈 복원과 지도 선택 개선 — 2026-10-07

## 화면 변경

로그인은 `3d9d9d0` 시점의 이미지 소개 3장/하단 Google 버튼으로, 홈은 기존 최근 피드 목록으로 복원했다. 공식 Google 로고와 공통 Button은 유지한다. 숨겨진 로그인 로딩 표시의 애니메이션만 TickerMode로 중지한다. 기존 모임·만남 상세, 사진, 참석 통계는 유지한다.

선택 화면의 지도는 320px, 작성 화면의 선택한 장소 지도는 280px로 넓혔다. 우측 하단 대각선 확대 버튼을 누르면 상단 검색 입력/검색 버튼 아래를 지도 영역으로 사용하는 전체 화면이 열린다. 검색 후보와 확정 버튼은 지도 위 하단 패널에 표시한다. 확대 전 검색어·검색 종류·후보·지도 중심·선택을 유지하고 확정하면 작성 화면까지 선택을 전달한다. 취소하면 기존 작성 값은 유지한다.

지도 마커는 공통 빨간 위치 핀 PNG로 바꾸었다. 두 글자 이상 입력한 뒤 700ms 동안 변경이 없으면 후보를 조회한다. 수동 검색 버튼도 제공한다. 새 입력/검색 종류 변경/핀 선택/화면 폐기 시 이전 요청이 선택이나 최신 결과를 덮어쓰지 않는다.

## 검색이 실패한 원인

클라우드 앱의 Supabase 설정으로 `naver-place-search` 주소를 확인했으며, **HTTP 404 / NOT_FOUND**를 받았다. 사용자는 지도·검색 키를 추가했지만 검색 함수 배포와 추가 SQL은 하지 않았다고 확인했다. 지도 표시와 서버 검색은 별개다.

- **함수 배포 전:** 검색 서버가 없어서 검색이 실패한다.
- **첫 장소 SQL 적용 전:** 좌표를 저장할 컬럼/RPC와 검색 제한 RPC가 없다.
- **주소용 추가 SQL 적용 전:** 새 주소 검색 출처 `naver_geocode`를 저장할 수 없다.

이번 작업에서 실제 Supabase에 SQL을 적용하거나 함수를 배포하지 않았다. 제공자 인증·실제 검색 결과·실기기 지도 렌더링도 별도 검증이 필요하다.

## 검색 방식과 한계

- **장소:** 네이버 API HUB 지역 검색을 사용한다. 기존 Developers 검색 키가 이미 있는 경우 legacy 모드를 설정할 수 있다. 후보는 최대 5개다.
- **주소:** 네이버 Maps Geocoding을 사용한다. 지도 중심을 전달하면 주소 후보를 중심에 가까운 순서로 요청한다. 주소를 장소 이름과 혼동하지 않도록 검색 종류를 선택한다.
- **지도 주변 장소:** 지도 중심 좌표를 Reverse Geocoding으로 시/구/동 이름으로 변환하여 검색어에 반영하고, 반환된 후보를 거리 순서로 정렬한다. 지도 이동 후 ‘이 지도 위치에서 다시 검색’을 누를 수 있다. ‘전체 지역’으로 바꾸면 지역 보정을 하지 않는다.

**네이버 지도 앱의 자동완성이나 반경 내 전체 POI 검색과 동일한 API가 아니다.** 장소 API에는 중심/반경 파라미터가 없고, 지도 중심의 지역명으로 검색을 보정하는 방식이다. 지도 주변 검색에는 Maps Reverse Geocoding 인증/상품 설정도 필요하다. 결과가 없으면 지역명을 직접 넣거나 전체 지역/주소 검색으로 전환할 수 있다. 사용자 GPS를 수집하지 않는다.

참고 문서:

- [API HUB 지역 검색](https://api.ncloud-docs.com/docs/naver-api-hub-search-local)
- [Maps Geocoding](https://api.ncloud-docs.com/docs/en/application-maps-geocoding)
- [Maps Reverse Geocoding](https://api.ncloud-docs.com/docs/en/application-maps-reversegeocoding)
- [기존 Search API 이관 공지](https://developers.naver.com/notice/article/32530): 신규 Developers 신청은 중단되었으므로 신규 설정은 API HUB를 기준으로 한다.

## 무엇을 배포하는가

배포 대상은 Flutter 앱이 아니라 **Supabase Edge Function `naver-place-search`**다. 저장소의 `supabase/functions/naver-place-search/index.ts`와 `handler.ts`가 서버 코드다. 앱→Supabase 함수→네이버 API 순서로 요청한다. 검색 secret을 앱에 넣지 않는다.

### 1. SQL 적용

앞선 회원 이력/작성자 SQL 적용 상태를 유지하고, Supabase Dashboard → SQL Editor에서 아래 파일을 순서대로 검증·적용한다.

1. [20261008000000_meetup_places.sql](../supabase/migrations/20261008000000_meetup_places.sql)
2. [20261009000000_geocoded_places.sql](../supabase/migrations/20261009000000_geocoded_places.sql)

첫 파일을 이미 적용했다면 두 번째만 추가한다. 기존 reset/초기화 SQL과 임시 DB 테스트 파일은 운영 DB에서 실행하지 않는다. 기존 데이터나 관리자 역할을 초기화하는 작업이 아니다.

### 2. 서버 Secrets

Supabase Dashboard → Edge Functions → Secrets에 설정한다. **값 자체를 채팅에 공유하거나 Git에 커밋하지 않는다.**

| 이름 | 용도 |
|---|---|
| `NAVER_SEARCH_CLIENT_ID` | API HUB 지역 검색 Client ID |
| `NAVER_SEARCH_CLIENT_SECRET` | API HUB 지역 검색 Client Secret |
| `NAVER_SEARCH_PROVIDER` | 기본 `hub`. 이미 발급받은 Developers 키를 사용하는 경우만 `legacy` |
| `NAVER_MAP_CLIENT_ID` | Maps Geocoding/Reverse Geocoding 인증 식별자 |
| `NAVER_MAP_CLIENT_SECRET` | Maps 서버 API 인증 secret |

Maps 상품의 Geocoding/Reverse Geocoding과 검색 상품의 지역 검색 사용 설정을 각각 확인한다. 둘의 인증 설정을 자동으로 같다고 가정하지 않는다. 앱 `.env`에는 지도 표시용 `NAVER_MAP_CLIENT_ID`만 사용하며, 검색/Maps Client Secret은 서버에만 넣는다. 앱에 secret을 이미 포함했다면 앱에서 제거하고 해당 키를 재발급한 뒤 서버에 새 값을 설정한다. 앱에 배포한 값은 `.env` 파일이어도 비밀로 유지되지 않는다.

`SUPABASE_URL`과 `SUPABASE_ANON_KEY`는 Supabase Edge Function의 기본 환경 변수를 사용한다. `service_role` 키는 필요 없다.

### 3. 함수 배포

최신 feature 브랜치 코드를 받은 **저장소 루트**에서 최신 Supabase CLI로 로그인하고 배포한다. 프로젝트 ID는 Dashboard URL/Project Settings에서 확인할 수 있는 project ref다.

```bash
supabase login
supabase functions deploy naver-place-search --project-ref <프로젝트-ID> --no-verify-jwt --use-api
```

`--use-api`는 Docker 없이 서버에서 묶어 배포한다. 이 함수는 자체적으로 Bearer 토큰을 `auth.getUser(token)`로 검증하고 해당 모임의 활성 멤버십을 조회하므로, gateway JWT 검증을 끄더라도 비로그인/비멤버 검색은 차단한다. `supabase` 명령이 없으면 [공식 CLI 설치 안내](https://supabase.com/docs/guides/local-development/cli/getting-started)를 따른다. 로컬 CLI가 프로젝트 초기화를 요구하면 `supabase init`으로 로컬 설정을 준비한다. 배포에 `supabase db reset`, `--prune` 또는 데이터 초기화 명령은 필요 없다.

배포 후 Dashboard에 `naver-place-search`가 표시되는지 확인한다. 로그인 상태에서 실제 모임을 열고 장소/주소 검색, 지도 이동 후 다시 검색, 전체 화면 선택, 기록 저장과 재조회, 모임 장소 지도를 확인한다. 함수가 있더라도 잘못된 키·상품 미설정·검색 제한이면 실패할 수 있다. 앱은 미배포/권한/요청 제한/주소·주변 검색 미설정을 서로 다른 안내로 표시하며 원본 제공자 오류를 노출하지 않는다.

## 검증 범위

전체 결과는 [제품 작업 기록](product_direction.md)의 최신 후속 항목을 따른다. 자동 검증은 지도 SDK의 네이티브 렌더링과 실제 네이버 인증을 대신하지 않는다. SQL 테스트는 PostgreSQL 임시 DB에서 기존 장소·주소 출처 저장 및 RLS/트랜잭션 호환을 확인한다.
