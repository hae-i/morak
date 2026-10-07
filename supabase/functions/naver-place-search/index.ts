import {createClient} from 'npm:@supabase/supabase-js@2';
import {handleSearch} from './handler.ts';

Deno.serve((request: Request) => handleSearch(request, {
  clientId: Deno.env.get('NAVER_SEARCH_CLIENT_ID'),
  clientSecret: Deno.env.get('NAVER_SEARCH_CLIENT_SECRET'),
  allowSearch: async (token) => {
    const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: {headers: {Authorization: token}},
      auth: {persistSession: false, autoRefreshToken: false},
    });
    const {data, error} = await client.rpc('morak_consume_place_search');
    if (error) throw new Error('Search quota unavailable');
    return data === true;
  },
  authorize: async (token, groupId) => {
    const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: {headers: {Authorization: token}},
      auth: {persistSession: false, autoRefreshToken: false},
    });
    const {data: {user}, error: authError} = await client.auth.getUser();
    if (authError || !user) return false;
    const {data, error} = await client.from('group_members').select('id')
      .eq('group_id', groupId).eq('user_id', user.id).eq('is_deleted', false).maybeSingle();
    if (error) throw new Error('Membership check failed');
    return data !== null;
  },
}));
