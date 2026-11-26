// TRUE ME — Authenticated AI Gateway Edge Function (SEC-01 / AI-01 / AI-02)
// Deploy with: supabase functions deploy ai-gateway
// Set secrets: GEMINI_API_KEY, GROQ_API_KEY, OPENROUTER_API_KEY, COHERE_API_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: authData, error: authErr } = await supabase.auth.getUser();
    if (authErr || !authData?.user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const requestId = String(body.requestId || crypto.randomUUID());
    const taskType = String(body.taskType || 'chat');
    const prompt = String(body.prompt || '');
    const systemPrompt = body.systemPrompt ? String(body.systemPrompt) : '';
    const jsonMode = Boolean(body.jsonMode);

    if (!prompt.trim()) {
      return new Response(JSON.stringify({ error: 'Prompt is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 1. Check authoritative server-side quota before calling paid/rate-limited providers
    const { data: quotaCheck, error: quotaErr } = await supabase.rpc('check_and_record_ai_usage', {
      p_request_id: requestId,
      p_provider: 'gateway',
      p_task_type: taskType,
      p_status: 'success',
    });

    if (quotaErr) {
      return new Response(JSON.stringify({ error: quotaErr.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (quotaCheck && quotaCheck.allowed === false) {
      return new Response(
        JSON.stringify({
          error: 'Daily AI quota reached',
          used_today: quotaCheck.used_today,
          daily_limit: quotaCheck.daily_limit,
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Execute against Groq -> Gemini -> OpenRouter using server-only secrets
    const groqKey = Deno.env.get('GROQ_API_KEY') ?? '';
    const geminiKey = Deno.env.get('GEMINI_API_KEY') ?? '';

    let text = '';
    let usedProvider = '';

    if (groqKey) {
      const messages = [
        ...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
        { role: 'user', content: prompt },
      ];
      const groqResp = await fetch('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${groqKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'llama-3.3-70b-versatile',
          messages,
          ...(jsonMode ? { response_format: { type: 'json_object' } } : {}),
        }),
      });
      if (groqResp.ok) {
        const j = await groqResp.json();
        text = j?.choices?.[0]?.message?.content ?? '';
        usedProvider = 'groq';
      }
    }

    if (!text && geminiKey) {
      const gemResp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            ...(systemPrompt ? { systemInstruction: { parts: [{ text: systemPrompt }] } } : {}),
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            ...(jsonMode ? { generationConfig: { responseMimeType: 'application/json' } } : {}),
          }),
        }
      );
      if (gemResp.ok) {
        const j = await gemResp.json();
        text = j?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
        usedProvider = 'gemini';
      }
    }

    if (!text) {
      return new Response(JSON.stringify({ error: 'All configured AI providers failed.' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(
      JSON.stringify({
        text,
        provider: usedProvider,
        requestId,
        quota: quotaCheck,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
