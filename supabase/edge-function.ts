import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { status: 200, headers: cors });

  const url = new URL(req.url);
  // path after /ladle/ e.g. recipes, menu, shopping, inventory, logs, photo
  const parts = url.pathname.split('/').filter(Boolean);
  const idx = parts.indexOf('ladle');
  const resource = parts[idx + 1] ?? '';
  const resourceId = parts[idx + 2] ?? null;

  const tableMap: Record<string, string> = {
    recipes: 'recipes',
    menu: 'weekly_menu',
    shopping: 'shopping_items',
    inventory: 'inventory',
    logs: 'cook_logs',
  };

  try {
    // photo upload: POST /photo  { filename, base64 }
    if (resource === 'photo' && req.method === 'POST') {
      const { filename, base64 } = await req.json();
      if (!filename || !base64) return json({ error: 'filename and base64 required' }, 400);
      const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
      const path = `${Date.now()}-${filename}`;
      const { error } = await supabase.storage
        .from('ladle-photos')
        .upload(path, bytes, { contentType: 'image/jpeg' });
      if (error) return json({ error: error.message }, 500);
      const { data } = supabase.storage.from('ladle-photos').getPublicUrl(path);
      return json({ url: data.publicUrl });
    }

    const table = tableMap[resource];
    if (!table) return json({ error: 'unknown resource' }, 404);

    if (req.method === 'GET') {
      let query = supabase.from(table).select('*');
      // sensible default ordering per resource
      if (table === 'weekly_menu') {
        const from = url.searchParams.get('from');
        const to = url.searchParams.get('to');
        if (from) query = query.gte('menu_date', from);
        if (to) query = query.lte('menu_date', to);
        query = query.order('menu_date').order('slot');
      } else if (table === 'cook_logs') {
        query = query.order('log_date', { ascending: false }).order('id', { ascending: false });
      } else if (table === 'shopping_items') {
        query = query.order('checked').order('kind').order('id');
      } else if (table === 'inventory') {
        query = query.eq('is_used', false).order('location').order('added_on');
      } else {
        query = query.order('id', { ascending: false });
      }
      const { data, error } = await query;
      if (error) return json({ error: error.message }, 500);
      return json(data);
    }

    if (req.method === 'POST') {
      const body = await req.json();
      const { data, error } = await supabase.from(table).insert(body).select();
      if (error) return json({ error: error.message }, 500);
      return json(data, 201);
    }

    if (req.method === 'PATCH') {
      if (!resourceId) return json({ error: 'id required' }, 400);
      const body = await req.json();
      const { data, error } = await supabase
        .from(table)
        .update(body)
        .eq('id', resourceId)
        .select();
      if (error) return json({ error: error.message }, 500);
      return json(data);
    }

    return json({ error: 'method not allowed' }, 405);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
