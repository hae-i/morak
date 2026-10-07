/** No provider credentials or raw provider errors are returned to the client. */
export interface Dependencies {
  authorize: (token: string, groupId: string) => Promise<boolean>;
  allowSearch: (token: string) => Promise<boolean>;
  clientId?: string;
  clientSecret?: string;
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
  try {
    if (!await deps.authorize(token, groupId)) return json(403, {error: 'access_denied'});
  } catch { return json(503, {error: 'search_unavailable'}); }
  if (!deps.clientId || !deps.clientSecret) return json(503, {error: 'search_unavailable'});
  try {
    if (!await deps.allowSearch(token)) return json(429, {error: 'search_rate_limited'});
  } catch { return json(503, {error: 'search_unavailable'}); }

  const url = new URL('https://openapi.naver.com/v1/search/local.json');
  url.search = new URLSearchParams({query, display: '5', start: '1', sort: 'random'}).toString();
  try {
    const response = await (deps.fetcher ?? fetch)(url, {
      headers: {'X-Naver-Client-Id': deps.clientId, 'X-Naver-Client-Secret': deps.clientSecret},
      signal: AbortSignal.timeout(8000), redirect: 'error',
    });
    if (!response.ok) return json(response.status === 429 ? 429 : 502, {error: 'search_unavailable'});
    const data = await response.json();
    if (!Array.isArray(data.items) || data.items.length > 5) return json(502, {error: 'invalid_search_response'});
    const items = data.items.map((item: Record<string, unknown>) => {
      // Naver local API changed to WGS84 coordinates scaled by 10^7 in 2023.
      const longitude = (typeof item.mapx === 'string' && /^-?\d+$/.test(item.mapx)) || (typeof item.mapx === 'number' && Number.isSafeInteger(item.mapx)) ? Number(item.mapx) / 1e7 : NaN;
      const latitude = (typeof item.mapy === 'string' && /^-?\d+$/.test(item.mapy)) || (typeof item.mapy === 'number' && Number.isSafeInteger(item.mapy)) ? Number(item.mapy) / 1e7 : NaN;
      const name = plainText(item.title, 200);
      const address = plainText(item.roadAddress, 500) || plainText(item.address, 500);
      if (!name || !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
          latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 ||
          (latitude === 0 && longitude === 0)) throw new Error('Invalid coordinates');
      return {name, address, latitude, longitude, source: 'naver_search'};
    });
    return json(200, {items});
  } catch { return json(502, {error: 'search_unavailable'}); }
}
