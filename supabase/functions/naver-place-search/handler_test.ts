import {test} from 'node:test';
import assert from 'node:assert/strict';
import {handleSearch, type Dependencies} from './handler.ts';

const groupId = '00000000-0000-0000-0000-000000000001';
const request = (body: unknown = {group_id: groupId, query: '송파 카페'}, auth = true) => new Request('https://example.invalid/search', {
  method: 'POST', headers: auth ? {Authorization: 'Bearer test-token'} : {}, body: JSON.stringify(body),
});
const defaults: Dependencies = {authorize: async () => true, allowSearch: async () => true,
  clientId: 'test-id', clientSecret: 'test-secret'};

test('unauthenticated and non-member requests never reach the provider', async () => {
  let calls = 0;
  const deps = {...defaults, fetcher: async () => {calls++; return new Response('{}');}};
  assert.equal((await handleSearch(request(undefined, false), deps)).status, 401);
  assert.equal((await handleSearch(request(), {...deps, authorize: async () => false})).status, 403);
  assert.equal(calls, 0);
});

test('invalid query and oversized body are rejected before authorization', async () => {
  let checks = 0;
  const deps = {...defaults, authorize: async () => {checks++; return true;}};
  assert.equal((await handleSearch(request({group_id: groupId, query: ' '}), deps)).status, 400);
  assert.equal((await handleSearch(request({group_id: groupId, query: 'x'.repeat(5000)}), deps)).status, 413);
  assert.equal(checks, 0);
});

test('quota exhaustion does not call the upstream API', async () => {
  let calls = 0;
  const response = await handleSearch(request(), {...defaults,
    allowSearch: async () => false, fetcher: async () => {calls++; return new Response('{}');}});
  assert.equal(response.status, 429);
  assert.equal(calls, 0);
});

test('provider coordinates are converted from scaled WGS84 and titles are plain text', async () => {
  let target: URL | undefined;
  const response = await handleSearch(request(), {...defaults, fetcher: async (url) => {
    target = new URL(String(url));
    return Response.json({items: [{title: '<b>카페</b> &amp; 식당', address: '서울 송파구',
      roadAddress: '서울특별시 송파구 올림픽로 10', mapx: '1271000000', mapy: '375000000'}]});
  }});
  assert.equal(response.status, 200);
  assert.equal(target!.host, 'openapi.naver.com');
  assert.equal(target!.searchParams.get('display'), '5');
  assert.deepEqual(await response.json(), {items: [{name: '카페 & 식당',
    address: '서울특별시 송파구 올림픽로 10', longitude: 127.1, latitude: 37.5, source: 'naver_search'}]});
});

test('missing keys, invalid coordinates, and provider errors never expose secrets', async () => {
  assert.equal((await handleSearch(request(), {...defaults, clientSecret: undefined})).status, 503);
  for (const coords of [{mapx: '', mapy: '375000000'}, {mapx: 'NaN', mapy: 'Infinity'}, {mapx: '9000000000', mapy: '375000000'}]) {
    const response = await handleSearch(request(), {...defaults, fetcher: async () => Response.json({items: [{title: '카페', ...coords}]})});
    assert.equal(response.status, 502);
    assert.equal((await response.text()).includes('test-secret'), false);
  }
  const response = await handleSearch(request(), {...defaults, fetcher: async () => new Response('private provider details: test-secret', {status: 403})});
  assert.equal(response.status, 502);
  assert.equal((await response.text()).includes('test-secret'), false);
});

test('address mode uses Maps geocoding with longitude-first center and unscaled coordinates', async () => {
  let target: URL | undefined;
  const response = await handleSearch(request({group_id: groupId, query: '올림픽로 10', mode: 'address',
    center: {latitude: 37.5, longitude: 127.1}}), {...defaults, mapClientId: 'map-id', mapClientSecret: 'map-secret', fetcher: async (url, init) => {
      target = new URL(String(url));
      assert.equal(new Headers(init?.headers).get('x-ncp-apigw-api-key'), 'map-secret');
      return Response.json({status: 'OK', addresses: [{roadAddress: '서울특별시 송파구 올림픽로 10', x: '127.1', y: '37.5'}]});
    }});
  assert.equal(response.status, 200);
  assert.equal(target!.pathname, '/map-geocode/v2/geocode');
  assert.equal(target!.searchParams.get('coordinate'), '127.1,37.5');
  const body = await response.json();
  assert.equal(body.items[0].source, 'naver_geocode');
  assert.equal(body.items[0].longitude, 127.1);
});

test('nearby place query uses the map region and ranks its returned candidates by distance', async () => {
  const calls: URL[] = [];
  const response = await handleSearch(request({group_id: groupId, query: '카페',
    center: {latitude: 37.5, longitude: 127.1}}), {...defaults, mapClientId: 'map-id', mapClientSecret: 'map-secret', fetcher: async (url) => {
      const target = new URL(String(url)); calls.push(target);
      if (target.pathname.endsWith('/gc')) return Response.json({status: {code: 0}, results: [{region: {
        area1: {name: '서울특별시'}, area2: {name: '송파구'}, area3: {name: '잠실동'}}}]});
      return Response.json({items: [
        {title: '먼 카페', mapx: '1272000000', mapy: '375000000'},
        {title: '가까운 카페', mapx: '1271000000', mapy: '375000000'},
      ]});
    }});
  assert.equal(response.status, 200);
  assert.equal(calls[0].searchParams.get('coords'), '127.1,37.5');
  assert.equal(calls[1].searchParams.get('query'), '서울특별시 송파구 잠실동 카페');
  assert.equal((await response.json()).items[0].name, '가까운 카페');
});

test('API HUB uses its own endpoint and authentication, accepting documented WGS84 coordinates', async () => {
  for (const [mapx, mapy] of [['127.1', '37.5'], ['1271000000', '375000000']]) {
    const response = await handleSearch(request(), {...defaults, searchProvider: 'hub', fetcher: async (url, init) => {
      assert.equal(new URL(String(url)).host, 'naverapihub.apigw.ntruss.com');
      const headers = new Headers(init?.headers);
      assert.equal(headers.get('x-ncp-apigw-api-key-id'), 'test-id');
      assert.equal(headers.get('X-Naver-Client-Id'), null);
      return Response.json({items: [{title: '카페', mapx, mapy}]});
    }});
    assert.equal(response.status, 200);
    assert.equal((await response.json()).items[0].latitude, 37.5);
  }
});

test('invalid modes and center coordinates are rejected before quota or provider calls', async () => {
  let calls = 0;
  const deps = {...defaults, allowSearch: async () => {calls++; return true;}};
  for (const extra of [{mode: 'anything'}, {center: {latitude: 999, longitude: 127}}, {center: {latitude: '37', longitude: 127}}]) {
    assert.equal((await handleSearch(request({group_id: groupId, query: '카페', ...extra}), deps)).status, 400);
  }
  assert.equal(calls, 0);
});

test('missing Maps credentials distinguish address and nearby failures without consuming quota', async () => {
  let calls = 0;
  const deps = {...defaults, allowSearch: async () => {calls++; return true;}};
  for (const [extra, code] of [
    [{mode: 'address'}, 'address_search_not_configured'],
    [{center: {latitude: 37.5, longitude: 127.1}}, 'nearby_search_not_configured'],
  ] as const) {
    const response = await handleSearch(request({group_id: groupId, query: '카페', ...extra}), deps);
    assert.equal(response.status, 503);
    assert.equal((await response.json()).error, code);
  }
  assert.equal(calls, 0);
});

test('automatic name search excludes menu-only matches and never prefixes the initial map location', async () => {
  const response = await handleSearch(request({group_id: groupId, query: '만주', mode: 'auto',
    center: {latitude: 37.5666, longitude: 126.979}}), {...defaults, fetcher: async (url) => {
      const target = new URL(String(url));
      assert.equal(target.host, 'openapi.naver.com');
      assert.equal(target.searchParams.get('query'), '만주');
      return Response.json({items: [
        {title: '중화요리집', description: '만주 메뉴', mapx: '1271000000', mapy: '375000000'},
        {title: '<b>만주</b> 송파점', mapx: '1271000000', mapy: '375000000'},
      ]});
    }});
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).items.map((item: {name: string}) => item.name), ['만주 송파점']);
});

test('automatic street address search goes directly to Geocoding', async () => {
  const response = await handleSearch(request({group_id: groupId, query: '올림픽로 10', mode: 'auto'}), {
    ...defaults, mapClientId: 'map-id', mapClientSecret: 'map-secret', fetcher: async (url) => {
      assert.equal(new URL(String(url)).pathname, '/map-geocode/v2/geocode');
      return Response.json({status: 'OK', addresses: [{roadAddress: '서울 송파구 올림픽로 10', x: '127.1', y: '37.5'}]});
    }});
  assert.equal(response.status, 200);
  assert.equal((await response.json()).items[0].source, 'naver_geocode');
});

test('automatic ambiguous query falls back to address search only when no shop name matches', async () => {
  const paths: string[] = [];
  const response = await handleSearch(request({group_id: groupId, query: '잠실', mode: 'auto'}), {
    ...defaults, mapClientId: 'map-id', mapClientSecret: 'map-secret', fetcher: async (url) => {
      const path = new URL(String(url)).pathname; paths.push(path);
      if (path.endsWith('local.json')) return Response.json({items: []});
      return Response.json({status: 'OK', addresses: [{jibunAddress: '서울 송파구 잠실동', x: '127.1', y: '37.5'}]});
    }});
  assert.equal(response.status, 200);
  assert.deepEqual(paths, ['/v1/search/local.json', '/map-geocode/v2/geocode']);
});

test('shop-name filtering allows region-qualified queries without accepting menu-only matches', async () => {
  const response = await handleSearch(request({group_id: groupId, query: '송파구 만주', mode: 'auto'}), {
    ...defaults, fetcher: async () => Response.json({items: [
      {title: '만주', address: '서울 송파구', mapx: '1271000000', mapy: '375000000'},
      {title: '다른 식당', address: '서울 송파구', description: '만주', mapx: '1271000000', mapy: '375000000'},
    ]})});
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).items.map((item: {name: string}) => item.name), ['만주']);
});

test('unset search provider supports both Developers and API HUB keys without logging raw errors', async () => {
  const hosts: string[] = [];
  const response = await handleSearch(request(), {...defaults, fetcher: async (url) => {
    const host = new URL(String(url)).host; hosts.push(host);
    if (host === 'openapi.naver.com') return new Response('secret provider detail', {status: 401});
    return Response.json({items: [{title: '카페', mapx: '127.1', mapy: '37.5'}]});
  }});
  assert.equal(response.status, 200);
  assert.deepEqual(hosts, ['openapi.naver.com', 'naverapihub.apigw.ntruss.com']);
  assert.equal((await response.json()).items[0].latitude, 37.5);
});

test('address search supports legacy Maps credentials after the new endpoint rejects authentication', async () => {
  const hosts: string[] = [];
  const response = await handleSearch(request({group_id: groupId, query: '올림픽로 10', mode: 'auto'}), {
    ...defaults, mapClientId: 'map-id', mapClientSecret: 'map-secret', fetcher: async (url) => {
      const host = new URL(String(url)).host; hosts.push(host);
      if (host === 'maps.apigw.ntruss.com') return new Response('private key details', {status: 403});
      return Response.json({status: 'OK', addresses: [{roadAddress: '서울 송파구 올림픽로 10', x: '127.1', y: '37.5'}]});
    }});
  assert.equal(response.status, 200);
  assert.deepEqual(hosts, ['maps.apigw.ntruss.com', 'naveropenapi.apigw.ntruss.com']);
});

test('failed fallback address lookup keeps primary search empty instead of failing the whole search', async () => {
  const response = await handleSearch(request({group_id: groupId, query: '만주', mode: 'auto'}), {
    ...defaults, mapClientId: 'map-id', mapClientSecret: 'map-secret', fetcher: async (url) => {
      if (new URL(String(url)).pathname.endsWith('local.json')) return Response.json({items: []});
      return new Response('private map authentication details', {status: 403});
    }});
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {items: [], warning: 'address_search_auth_failed'});
});

test('quota failures do not trigger provider fallback and are distinct from provider authentication failures', async () => {
  let calls = 0;
  const response = await handleSearch(request(), {...defaults, fetcher: async () => {
    calls++; return new Response('quota', {status: 429});
  }});
  assert.equal(response.status, 429); assert.equal(calls, 1);
  const invalid = await handleSearch(request(), {...defaults, fetcher: async () => new Response('private secret', {status: 401})});
  assert.equal(invalid.status, 502);
  assert.deepEqual(await invalid.json(), {error: 'place_search_auth_failed'});
});

test('a shop name ending in a region suffix is still matched as a whole name', async () => {
  const response = await handleSearch(request({group_id: groupId, query: '아무도', mode: 'auto'}), {
    ...defaults, fetcher: async () => Response.json({items: [{title: '아무도', mapx: '1271000000', mapy: '375000000'}]})});
  assert.equal(response.status, 200);
  assert.equal((await response.json()).items[0].name, '아무도');
});
