/** No provider credentials or raw provider errors are returned to the client. */
export interface Dependencies {
  authorize: (token: string, groupId: string) => Promise<boolean>;
  allowSearch: (token: string) => Promise<boolean>;
  clientId?: string;
  clientSecret?: string;
  mapClientId?: string;
  mapClientSecret?: string;
  searchProvider?: 'legacy' | 'hub';
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
  constructor(status: number, code: string) { super(code); this.status = status; this.code = code; }
}
const mapHeaders = (deps: Dependencies) => ({
  'x-ncp-apigw-api-key-id': deps.mapClientId!,
  'x-ncp-apigw-api-key': deps.mapClientSecret!, Accept: 'application/json',
});
async function provider(url: URL, headers: Record<string, string>, deps: Dependencies, timeout = 5000) {
  const response = await (deps.fetcher ?? fetch)(url, {
    headers, signal: AbortSignal.timeout(timeout), redirect: 'error',
  });
  if (!response.ok) throw new SearchFailure(response.status === 429 ? 429 : 502, 'search_unavailable');
  return response.json();
}
function coordinates(latitude: number, longitude: number) {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 ||
      (latitude === 0 && longitude === 0)) throw new Error('Invalid coordinates');
  return {latitude, longitude};
}
async function searchAddress(query: string, center: Center | undefined, deps: Dependencies) {
  const url = new URL('https://maps.apigw.ntruss.com/map-geocode/v2/geocode');
  url.searchParams.set('query', query);
  url.searchParams.set('count', '5');
  if (center) url.searchParams.set('coordinate', `${center.longitude},${center.latitude}`);
  const data = await provider(url, mapHeaders(deps), deps);
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
  const data = await provider(url, mapHeaders(deps), deps, 3000);
  if (data.status?.code !== 0 || !Array.isArray(data.results) || !data.results.length) throw new Error('Invalid region');
  const region = data.results[0].region;
  const names = [region?.area1?.name, region?.area2?.name, region?.area3?.name];
  if (names.some((name) => typeof name !== 'string' || !name || name.length > 60 || !/^[가-힣\s]+$/.test(name))) throw new Error('Invalid region');
  return names.join(' ');
}
function distance(point: Center, center: Center) {
  const rad = (n: number) => n * Math.PI / 180;
  return Math.sin(rad(point.latitude - center.latitude) / 2) ** 2 +
    Math.cos(rad(center.latitude)) * Math.cos(rad(point.latitude)) *
    Math.sin(rad(point.longitude - center.longitude) / 2) ** 2;
}
async function searchPlaces(query: string, center: Center | undefined, deps: Dependencies) {
  // Local Search has no radius/center parameter. Bias its query by the map's
  // administrative region, then sort only the returned candidates by distance.
  if (center && !/[가-힣]{2,}(시|군|구|동|읍|면|로|길)(\s|$)/.test(query)) {
    query = `${await regionAt(center, deps)} ${query}`;
  }
  const hub = deps.searchProvider === 'hub';
  const url = new URL(hub ? 'https://naverapihub.apigw.ntruss.com/search/v1/local' : 'https://openapi.naver.com/v1/search/local.json');
  url.search = new URLSearchParams({query, display: '5', start: '1', sort: 'random'}).toString();
  const data = await provider(url, hub
    ? {'x-ncp-apigw-api-key-id': deps.clientId!, 'x-ncp-apigw-api-key': deps.clientSecret!}
    : {'X-Naver-Client-Id': deps.clientId!, 'X-Naver-Client-Secret': deps.clientSecret!}, deps);
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
  if (center) items.sort((a: Center, b: Center) => distance(a, center) - distance(b, center));
  return items;
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
  if (!query || query.length > 100 || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(groupId)) {
    return json(400, {error: 'invalid_request'});
  }
  const mode = body.mode ?? 'place';
  if (mode !== 'place' && mode !== 'address') return json(400, {error: 'invalid_request'});
  let center: Center | undefined;
  if (body.center !== undefined) {
    const value = body.center as Record<string, unknown> | null;
    if (!value || typeof value !== 'object' || Array.isArray(value) ||
        typeof value.latitude !== 'number' || typeof value.longitude !== 'number' ||
        !Number.isFinite(value.latitude) || !Number.isFinite(value.longitude) ||
        Math.abs(value.latitude) > 90 || Math.abs(value.longitude) > 180) return json(400, {error: 'invalid_request'});
    center = {latitude: value.latitude, longitude: value.longitude};
  }
  try {
    if (!await deps.authorize(token, groupId)) return json(403, {error: 'access_denied'});
  } catch { return json(503, {error: 'search_unavailable'}); }
  if (mode === 'place' && (!deps.clientId || !deps.clientSecret)) return json(503, {error: 'search_not_configured'});
  if ((mode === 'address' || center) && (!deps.mapClientId || !deps.mapClientSecret)) {
    return json(503, {error: mode === 'address' ? 'address_search_not_configured' : 'nearby_search_not_configured'});
  }
  try {
    if (!await deps.allowSearch(token)) return json(429, {error: 'search_rate_limited'});
  } catch { return json(503, {error: 'search_unavailable'}); }

  try {
    const items = mode === 'address' ? await searchAddress(query, center, deps) : await searchPlaces(query, center, deps);
    return json(200, {items});
  } catch (error) {
    return error instanceof SearchFailure ? json(error.status, {error: error.code}) : json(502, {error: 'search_unavailable'});
  }
}
