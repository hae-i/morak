/** No provider credentials or raw provider errors are returned to the client. */
export interface Dependencies {
  authorize: (token: string, groupId: string) => Promise<boolean>;
  allowSearch: (token: string) => Promise<boolean>;
  clientId?: string;
  clientSecret?: string;
  mapClientId?: string;
  mapClientSecret?: string;
  searchProvider?: 'legacy' | 'hub';
  mapProvider?: 'legacy' | 'maps';
  signal?: AbortSignal;
  fetcher?: typeof fetch;
}
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (status: number, data: unknown) => new Response(JSON.stringify(data), {
  status, headers: {...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store'},
});
const plainText = (value: unknown, limit: number) => typeof value === 'string'
  ? value.replace(/<[^>]*>/g, '').replace(/&amp;/g, '&').replace(/&quot;/g, '"')
      .replace(/&#39;|&apos;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .trim().slice(0, limit) : '';

type Center = {latitude: number; longitude: number};
class SearchFailure extends Error {
  readonly status: number;
  readonly code: string;
  readonly upstreamStatus?: number;
  constructor(status: number, code: string, upstreamStatus?: number) { super(code); this.status = status; this.code = code; this.upstreamStatus = upstreamStatus; }
}
const mapHeaders = (deps: Dependencies) => ({
  'x-ncp-apigw-api-key-id': deps.mapClientId!,
  'x-ncp-apigw-api-key': deps.mapClientSecret!, Accept: 'application/json',
});
async function provider(url: URL, headers: Record<string, string>, deps: Dependencies, timeout = 5000) {
  const response = await (deps.fetcher ?? fetch)(url, {
    headers, signal: deps.signal ? AbortSignal.any([deps.signal, AbortSignal.timeout(timeout)]) : AbortSignal.timeout(timeout), redirect: 'error',
  });
  if (!response.ok) throw new SearchFailure(response.status === 429 ? 429 : 502,
    response.status === 401 || response.status === 403 ? 'provider_auth_failed' : 'search_unavailable', response.status);
  return response.json();
}
function coordinates(latitude: number, longitude: number) {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 ||
      (latitude === 0 && longitude === 0)) throw new Error('Invalid coordinates');
  return {latitude, longitude};
}
async function compatibleProvider(
  urls: URL[], headers: Record<string, string>[], deps: Dependencies, code: string,
) {
  for (let i = 0; i < urls.length; i++) {
    try { return {data: await provider(urls[i], headers[i], deps), index: i}; }
    catch (error) {
      if (!(error instanceof SearchFailure) || error.code !== 'provider_auth_failed') throw error;
      if (i === urls.length - 1) throw new SearchFailure(502, code, error.upstreamStatus);
    }
  }
  throw new Error('No provider configured');
}
async function mapsProvider(url: URL, deps: Dependencies, code = 'address_search_auth_failed') {
  const current = new URL(url);
  const legacy = new URL(url); legacy.hostname = 'naveropenapi.apigw.ntruss.com';
  const urls = deps.mapProvider === 'legacy' ? [legacy] : deps.mapProvider === 'maps' ? [current] : [current, legacy];
  return (await compatibleProvider(urls, urls.map(() => mapHeaders(deps)), deps, code)).data;
}
async function searchAddress(query: string, center: Center | undefined, deps: Dependencies) {
  const url = new URL('https://maps.apigw.ntruss.com/map-geocode/v2/geocode');
  url.searchParams.set('query', query);
  url.searchParams.set('count', '5');
  if (center) url.searchParams.set('coordinate', `${center.longitude},${center.latitude}`);
  const data = await mapsProvider(url, deps);
  if (data.status !== 'OK' || !Array.isArray(data.addresses) || data.addresses.length > 5) throw new Error('Invalid addresses');
  return data.addresses.map((item: Record<string, unknown>) => {
    const address = plainText(item.roadAddress, 500) || plainText(item.jibunAddress, 500);
    if (!address || typeof item.x !== 'string' || typeof item.y !== 'string' ||
        !/^-?\d+(\.\d+)?$/.test(item.x) || !/^-?\d+(\.\d+)?$/.test(item.y)) throw new Error('Invalid address');
    return {name: address.slice(0, 200), address,
      ...coordinates(Number(item.y), Number(item.x)), source: 'naver_geocode'};
  });
}
async function regionAt(center: Center, deps: Dependencies) {
  const url = new URL('https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc');
  url.search = new URLSearchParams({coords: `${center.longitude},${center.latitude}`,
    sourcecrs: 'EPSG:4326', orders: 'legalcode', output: 'json'}).toString();
  const data = await mapsProvider(url, deps, 'nearby_search_auth_failed');
  if (data.status?.code !== 0 || !Array.isArray(data.results) || !data.results.length) throw new SearchFailure(502, 'nearby_search_unavailable');
  const region = data.results[0].region;
  const names = [region?.area1?.name, region?.area2?.name, region?.area3?.name];
  if (names.some((name) => typeof name !== 'string' || !name || name.length > 60 || !/^[가-힣\s]+$/.test(name))) throw new SearchFailure(502, 'nearby_search_unavailable');
  return names.join(' ');
}
async function reverseAddress(center: Center, deps: Dependencies) {
  const url = new URL('https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc');
  url.search = new URLSearchParams({coords: `${center.longitude},${center.latitude}`,
    sourcecrs: 'EPSG:4326', orders: 'roadaddr,addr', output: 'json'}).toString();
  const data = await mapsProvider(url, deps, 'reverse_search_auth_failed');
  if (data.status?.code === 3) throw new SearchFailure(404, 'address_not_found');
  if (data.status?.code !== 0 || !Array.isArray(data.results)) throw new Error('Invalid reverse address');
  for (const kind of ['roadaddr', 'addr']) {
    for (const result of data.results) {
      if (result.name !== kind) continue;
      const region = result.region;
      const land = result.land;
      const parts = [region?.area1?.name, region?.area2?.name];
      if (kind === 'roadaddr') parts.push(land?.name);
      else parts.push(region?.area3?.name, region?.area4?.name);
      const number1 = plainText(land?.number1, 20);
      const number2 = plainText(land?.number2, 20);
      if (!/^\d+$/.test(number1) || (number2 && !/^\d+$/.test(number2))) continue;
      const names = parts.map((part) => plainText(part, 100)).filter(Boolean);
      if (names.length < 2) continue;
      names.push(`${kind === 'addr' && land?.type === '2' ? '산 ' : ''}${number1}${number2 && number2 !== '0' ? '-' + number2 : ''}`);
      const address = names.join(' ');
      if (address.length > 500) throw new Error('Invalid reverse address');
      // Preserve the exact pin, never substitute a building/parcel centroid.
      return [{name: '직접 선택한 장소', address, ...center, source: 'manual_pin'}];
    }
  }
  throw new SearchFailure(404, 'address_not_found');
}
function distance(point: Center, center: Center) {
  const rad = (n: number) => n * Math.PI / 180;
  return Math.sin(rad(point.latitude - center.latitude) / 2) ** 2 +
    Math.cos(rad(center.latitude)) * Math.cos(rad(point.latitude)) *
    Math.sin(rad(point.longitude - center.longitude) / 2) ** 2;
}
function nameTerms(query: string) {
  return query.split(/\s+/).filter((part) =>
    !/^(서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주)$/.test(part) &&
    !/^[가-힣]{2,}(특별시|광역시|특별자치시|특별자치도|도|시|군|구|동|읍|면)$/.test(part));
}
function looksLikeAddress(query: string) {
  return /[가-힣]+(?:로|길)\s*\d/.test(query) || /[가-힣]+(?:동|읍|면|리)\s+\d/.test(query) ||
    /^(?:[가-힣]+(?:시|군|구|동|읍|면|로|길)\s*)+$/.test(query);
}
async function searchPlaces(query: string, center: Center | undefined, deps: Dependencies, nameOnly = false) {
  const originalQuery = query;
  // Local Search has no radius/center parameter. Bias its query by the map's
  // administrative region, then sort only the returned candidates by distance.
  if (center && nameTerms(query).length === query.split(/\s+/).length &&
      !/[가-힣]{2,}(시|군|구|동|읍|면|로|길)(\s|$)/.test(query)) {
    query = `${await regionAt(center, deps)} ${query}`;
  }
  const candidates = deps.searchProvider ? [deps.searchProvider] : ['legacy', 'hub'];
  const urls = candidates.map((candidate) => {
    const url = new URL(candidate === 'hub' ? 'https://naverapihub.apigw.ntruss.com/search/v1/local' : 'https://openapi.naver.com/v1/search/local.json');
    url.search = new URLSearchParams({query, display: '5', start: '1', sort: 'random'}).toString();
    return url;
  });
  const headers: Record<string, string>[] = candidates.map((candidate) => candidate === 'hub'
    ? {'x-ncp-apigw-api-key-id': deps.clientId!, 'x-ncp-apigw-api-key': deps.clientSecret!}
    : {'X-Naver-Client-Id': deps.clientId!, 'X-Naver-Client-Secret': deps.clientSecret!});
  const result = await compatibleProvider(urls, headers, deps, 'place_search_auth_failed');
  const data = result.data;
  const hub = candidates[result.index] === 'hub';
  if (!Array.isArray(data.items) || data.items.length > 5) throw new Error('Invalid places');
  const items = data.items.map((item: Record<string, unknown>) => {
    const coordinate = (value: unknown) => ((typeof value === 'string' && /^-?\d+$/.test(value)) ||
      (typeof value === 'number' && Number.isSafeInteger(value))) ? Number(value) / 1e7 : NaN;
    let longitude: number, latitude: number;
    if (hub) {
      const number = (value: unknown) => typeof value === 'number' ? value :
        typeof value === 'string' && /^-?\d+(\.\d+)?$/.test(value) ? Number(value) : NaN;
      longitude = number(item.mapx); latitude = number(item.mapy);
      // API HUB documents WGS84; accept decimal coordinates and the legacy
      // integer scale retained by some compatible responses.
      if (Math.abs(longitude) > 180 || Math.abs(latitude) > 90) {
        if (!Number.isSafeInteger(longitude) || !Number.isSafeInteger(latitude)) throw new Error('Invalid coordinates');
        longitude /= 1e7; latitude /= 1e7;
      }
    } else { longitude = coordinate(item.mapx); latitude = coordinate(item.mapy); }
    const name = plainText(item.title, 200);
    if (!name) throw new Error('Invalid name');
    return {name, address: plainText(item.roadAddress, 500) || plainText(item.address, 500),
      ...coordinates(latitude, longitude), source: 'naver_search'};
  });
  const normalized = (text: string) => text.normalize('NFKC').toLocaleLowerCase().replace(/[\s\p{P}\p{S}]/gu, '');
  const terms = nameTerms(originalQuery).map(normalized).filter(Boolean);
  const matches = nameOnly ? items.filter((item: {name: string}) => (normalized(item.name).includes(normalized(originalQuery)) || (terms.length > 0 && terms.every((term) => normalized(item.name).includes(term))))) : items;
  if (center) matches.sort((a: Center, b: Center) => distance(a, center) - distance(b, center));
  return matches;
}

export async function handleSearch(req: Request, deps: Dependencies): Promise<Response> {
  if (req.method === 'OPTIONS') return new Response(null, {status: 204, headers: cors});
  if (req.method !== 'POST') return json(405, {error: 'method_not_allowed'});
  const token = req.headers.get('Authorization');
  if (!token?.match(/^Bearer\s+\S+$/i)) return json(401, {error: 'authentication_required'});
  // Bound request bodies even when Content-Length is absent or inaccurate.
  let body: Record<string, unknown>;
  try {
    const reader = req.body?.getReader();
    if (!reader) return json(400, {error: 'invalid_request'});
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 4096) { await reader.cancel(); return json(413, {error: 'request_too_large'}); }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    const data = JSON.parse(new TextDecoder().decode(bytes));
    if (!data || typeof data !== 'object' || Array.isArray(data)) return json(400, {error: 'invalid_request'});
    body = data;
  } catch { return json(400, {error: 'invalid_request'}); }
  const query = typeof body.query === 'string' ? body.query.trim() : '';
  const groupId = typeof body.group_id === 'string' ? body.group_id : '';
  const reverse = body.mode === 'reverse';
  if ((!reverse && !query) || query.length > 100 || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(groupId)) {
    return json(400, {error: 'invalid_request'});
  }
  const mode = body.mode ?? 'place';
  if (mode !== 'place' && mode !== 'address' && mode !== 'auto' && mode !== 'reverse') return json(400, {error: 'invalid_request'});
  if (body.name_only !== undefined && typeof body.name_only !== 'boolean') return json(400, {error: 'invalid_request'});
  const nameOnly = body.name_only === true || mode === 'auto';
  const addressFirst = mode === 'address' || (mode === 'auto' && looksLikeAddress(query));
  let center: Center | undefined;
  if (body.center !== undefined) {
    const value = body.center as Record<string, unknown> | null;
    if (!value || typeof value !== 'object' || Array.isArray(value) ||
        typeof value.latitude !== 'number' || typeof value.longitude !== 'number' ||
        !Number.isFinite(value.latitude) || !Number.isFinite(value.longitude) ||
        Math.abs(value.latitude) > 90 || Math.abs(value.longitude) > 180) return json(400, {error: 'invalid_request'});
    center = {latitude: value.latitude, longitude: value.longitude};
  }
  if (body.scope !== undefined && body.scope !== 'map') return json(400, {error: 'invalid_request'});
  const mapScope = body.scope === 'map';
  if ((reverse || mapScope) && !center) return json(400, {error: 'invalid_request'});
  try {
    if (!await deps.authorize(token, groupId)) return json(403, {error: 'access_denied'});
  } catch { return json(503, {error: 'search_unavailable'}); }
  if (!reverse && !addressFirst && (!deps.clientId || !deps.clientSecret)) return json(503, {error: 'search_not_configured'});
  if ((reverse || addressFirst || center) && (!deps.mapClientId || !deps.mapClientSecret)) {
    return json(503, {error: reverse ? 'reverse_search_not_configured' : addressFirst ? 'address_search_not_configured' : 'nearby_search_not_configured'});
  }
  try {
    if (!await deps.allowSearch(token)) return json(429, {error: 'search_rate_limited'});
  } catch { return json(503, {error: 'search_quota_unavailable'}); }

  const runtime = {...deps, signal: AbortSignal.timeout(10000)};
  try {
    if (reverse) return json(200, {items: await reverseAddress(center!, runtime)});
    let items = addressFirst ? await searchAddress(query, center, runtime) : await searchPlaces(query, center, runtime, nameOnly);
    let warning: string | undefined;
    if (mode === 'auto' && items.length === 0) {
      try {
        if (addressFirst && deps.clientId && deps.clientSecret) items = await searchPlaces(query, center, runtime, true);
        else if (!addressFirst && deps.mapClientId && deps.mapClientSecret) items = await searchAddress(query, center, runtime);
      } catch (error) {
        warning = error instanceof SearchFailure ? error.code : 'fallback_search_unavailable';
      }
    }
    return json(200, {items, ...(warning ? {warning} : {}),
      ...(mapScope ? {search_scope: 'map', search_center: center} : {})});
  } catch (error) {
    return error instanceof SearchFailure ? json(error.status, {error: error.code}) : json(502, {error: 'search_unavailable'});
  }
}
