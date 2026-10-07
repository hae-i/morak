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
