// TRUE ME — Authenticated AI Gateway Edge Function (SEC-01 / AI-01 / AI-02)
// Supports: chat (with tier & provider fallback), embed (768-dim L2), rerank, transcribe.
// Secrets live exclusively in Supabase Edge Function Secrets:
//   GEMINI_API_KEY, GROQ_API_KEY, OPENROUTER_API_KEY, COHERE_API_KEY,
//   CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const MAX_PROMPT_CHARS = 80000;
const MAX_RERANK_DOCS = 50;
const MAX_AUDIO_BASE64_CHARS = 35 * 1024 * 1024; // ~25 MB binary

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function callGroqChat(params: {
  apiKey: string;
  model: string;
  prompt: string;
  systemPrompt?: string;
  jsonMode?: boolean;
  temperature?: number;
  maxTokens?: number;
}): Promise<string | null> {
  if (!params.apiKey) return null;
  const messages = [
    ...(params.systemPrompt ? [{ role: 'system', content: params.systemPrompt }] : []),
    { role: 'user', content: params.prompt },
  ];
  const resp = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${params.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: params.model,
      messages,
      temperature: params.temperature ?? 0.3,
      ...(params.maxTokens ? { max_tokens: params.maxTokens } : {}),
      ...(params.jsonMode ? { response_format: { type: 'json_object' } } : {}),
    }),
  });
  if (!resp.ok) return null;
  const data = await resp.json();
  const text = data?.choices?.[0]?.message?.content;
  return typeof text === 'string' && text.trim() ? text : null;
}

async function callGeminiChat(params: {
  apiKey: string;
  prompt: string;
  systemPrompt?: string;
  jsonMode?: boolean;
  temperature?: number;
  maxTokens?: number;
}): Promise<string | null> {
  if (!params.apiKey) return null;
  const models = ['gemini-2.5-flash', 'gemini-2.0-flash'];
  for (const model of models) {
    const resp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${params.apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...(params.systemPrompt
            ? { systemInstruction: { parts: [{ text: params.systemPrompt }] } }
            : {}),
          contents: [{ role: 'user', parts: [{ text: params.prompt }] }],
          generationConfig: {
            temperature: params.temperature ?? (params.systemPrompt ? 0.3 : 0.4),
            maxOutputTokens: params.maxTokens ?? (params.jsonMode ? 2048 : 4096),
            ...(params.jsonMode ? { responseMimeType: 'application/json' } : {}),
          },
        }),
      }
    );
    if (!resp.ok) continue;
    const data = await resp.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text === 'string' && text.trim()) return text;
  }
  return null;
}

async function callOpenRouterChat(params: {
  apiKey: string;
  model?: string;
  prompt: string;
  systemPrompt?: string;
  jsonMode?: boolean;
  maxTokens?: number;
}): Promise<string | null> {
  if (!params.apiKey) return null;
  const messages = [
    ...(params.systemPrompt ? [{ role: 'system', content: params.systemPrompt }] : []),
    { role: 'user', content: params.prompt },
  ];
  const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${params.apiKey}`,
      'HTTP-Referer': 'https://github.com/asmon31148-spec/TRUE-ME-',
      'X-Title': 'True Me Study App',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: params.model || 'nvidia/nemotron-3.5-lightning:free',
      messages,
      ...(params.maxTokens ? { max_tokens: params.maxTokens } : {}),
      ...(params.jsonMode ? { response_format: { type: 'json_object' } } : {}),
    }),
  });
  if (!resp.ok) return null;
  const data = await resp.json();
  const text = data?.choices?.[0]?.message?.content;
  return typeof text === 'string' && text.trim() ? text : null;
}

async function callCohereChat(params: {
  apiKey: string;
  model?: string;
  prompt: string;
  systemPrompt?: string;
  temperature?: number;
}): Promise<string | null> {
  if (!params.apiKey) return null;
  const messages = [
    ...(params.systemPrompt ? [{ role: 'system', content: params.systemPrompt }] : []),
    { role: 'user', content: params.prompt },
  ];
  const resp = await fetch('https://api.cohere.com/v2/chat', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${params.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: params.model || 'command-r-plus-08-2024',
      messages,
      temperature: params.temperature ?? 0.3,
    }),
  });
  if (!resp.ok) return null;
  const data = await resp.json();
  const text = data?.message?.content?.[0]?.text;
  return typeof text === 'string' && text.trim() ? text : null;
}

async function callCloudflareSummarize(params: {
  accountId: string;
  apiToken: string;
  text: string;
  maxTokens?: number;
}): Promise<string | null> {
  if (!params.accountId || !params.apiToken) return null;
  const resp = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${params.accountId}/ai/run/@cf/meta/llama-3-8b-instruct`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${params.apiToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messages: [
          {
            role: 'system',
            content:
              'You are an expert academic summarizer. Provide concise, clear, bullet-point summaries of the core concepts, definitions, and takeaways.',
          },
          {
            role: 'user',
            content: `Summarize the following study material thoroughly:\n\n${params.text}`,
          },
        ],
        max_tokens: params.maxTokens ?? 300,
      }),
    }
  );
  if (!resp.ok) return null;
  const data = await resp.json();
  const out = data?.result?.response;
  return typeof out === 'string' && out.trim() ? out : null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      return jsonResponse({ error: 'Authentication required' }, 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: authData, error: authErr } = await supabase.auth.getUser();
    if (authErr || !authData?.user) {
      return jsonResponse({ error: 'Invalid or expired session' }, 401);
    }

    const body = await req.json();
    const action = String(body.action || 'chat');
    const requestId = String(body.requestId || crypto.randomUUID());
    const taskType = String(body.taskType || action);

    // Enforce server-side daily quota atomically via Postgres RPC
    const { data: quotaCheck, error: quotaErr } = await supabase.rpc('check_and_record_ai_usage', {
      p_request_id: requestId,
      p_provider: String(body.preferredProvider || 'gateway'),
      p_task_type: taskType,
      p_status: 'success',
    });

    if (quotaErr) {
      return jsonResponse({ error: 'Unable to verify AI quota' }, 500);
    }
    if (quotaCheck && quotaCheck.allowed === false) {
      return jsonResponse(
        {
          error: 'Daily AI quota reached',
          used_today: quotaCheck.used_today,
          daily_limit: quotaCheck.daily_limit,
        },
        429
      );
    }

    const groqKey = Deno.env.get('GROQ_API_KEY') ?? '';
    const geminiKey = Deno.env.get('GEMINI_API_KEY') ?? '';
    const openRouterKey = Deno.env.get('OPENROUTER_API_KEY') ?? '';
    const cohereKey = Deno.env.get('COHERE_API_KEY') ?? '';
    const cfAccountId = Deno.env.get('CLOUDFLARE_ACCOUNT_ID') ?? '';
    const cfApiToken = Deno.env.get('CLOUDFLARE_API_TOKEN') ?? '';

    if (action === 'embed') {
      const text = String(body.text || '').trim();
      if (!text || text.length > MAX_PROMPT_CHARS) {
        return jsonResponse({ error: 'Invalid embedding input' }, 400);
      }
      if (!geminiKey) {
        return jsonResponse({ error: 'Embedding service unavailable' }, 503);
      }
      const resp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${geminiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            content: { parts: [{ text }] },
            outputDimensionality: 768,
          }),
        }
      );
      if (!resp.ok) {
        return jsonResponse({ error: 'Embedding generation failed' }, 502);
      }
      const data = await resp.json();
      const raw: number[] = Array.isArray(data?.embedding?.values) ? data.embedding.values : [];
      const sliced = raw.slice(0, 768);
      if (sliced.length !== 768) {
        return jsonResponse({ error: 'Unexpected embedding dimensions' }, 502);
      }
      const norm = Math.sqrt(sliced.reduce((sum, v) => sum + v * v, 0));
      const embedding = norm > 0 ? sliced.map((v) => v / norm) : sliced;
      return jsonResponse({ embedding, dimensions: 768, requestId, quota: quotaCheck });
    }

    if (action === 'rerank') {
      const query = String(body.query || '').trim();
      const documents: string[] = Array.isArray(body.documents)
        ? body.documents.slice(0, MAX_RERANK_DOCS).map((d: unknown) => String(d))
        : [];
      const topN = Math.min(Math.max(Number(body.topN || 4), 1), documents.length || 1);

      if (!query || documents.length === 0) {
        return jsonResponse({ documents: [], requestId, quota: quotaCheck });
      }

      if (cohereKey) {
        try {
          const resp = await fetch('https://api.cohere.com/v2/rerank', {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${cohereKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              model: 'rerank-v3.5',
              query,
              documents,
              top_n: topN,
            }),
          });
          if (resp.ok) {
            const data = await resp.json();
            const results = Array.isArray(data?.results) ? data.results : [];
            const reranked = results
              .map((r: { index: number }) => documents[r.index])
              .filter((d: string | undefined) => typeof d === 'string');
            if (reranked.length > 0) {
              return jsonResponse({ documents: reranked, provider: 'cohere', requestId, quota: quotaCheck });
            }
          }
        } catch {
          // Graceful fallback to original vector order
        }
      }
      return jsonResponse({ documents: documents.slice(0, topN), provider: 'fallback', requestId, quota: quotaCheck });
    }

    if (action === 'transcribe') {
      const audioBase64 = String(body.audioBase64 || '');
      const filename = String(body.filename || 'audio.m4a').replace(/[^a-zA-Z0-9._-]/g, '_');
      if (!audioBase64 || audioBase64.length > MAX_AUDIO_BASE64_CHARS) {
        return jsonResponse({ error: 'Invalid or oversized audio payload' }, 400);
      }
      if (!groqKey) {
        return jsonResponse({ error: 'Transcription service unavailable' }, 503);
      }
      const binary = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0));
      const form = new FormData();
      form.append('file', new Blob([binary]), filename);
      form.append('model', 'whisper-large-v3');
      form.append('response_format', 'json');
      form.append('language', 'en');

      const resp = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${groqKey}` },
        body: form,
      });
      if (!resp.ok) {
        return jsonResponse({ error: 'Audio transcription failed' }, 502);
      }
      const data = await resp.json();
      return jsonResponse({ text: String(data?.text || ''), provider: 'groq_whisper', requestId, quota: quotaCheck });
    }

    // Default action: 'chat'
    const prompt = String(body.prompt || '');
    const systemPrompt = body.systemPrompt ? String(body.systemPrompt) : undefined;
    const jsonMode = Boolean(body.jsonMode);
    const tier = String(body.tier || 'balanced');
    const preferredProvider = body.preferredProvider ? String(body.preferredProvider) : '';
    const temperature = typeof body.temperature === 'number' ? body.temperature : undefined;
    const maxTokens = typeof body.maxTokens === 'number' ? body.maxTokens : undefined;
    const modelHint = body.modelHint ? String(body.modelHint) : undefined;

    if (!prompt.trim() || prompt.length > MAX_PROMPT_CHARS) {
      return jsonResponse({ error: 'Prompt must be between 1 and 80000 characters' }, 400);
    }

    let text: string | null = null;
    let usedProvider = '';

    // Build ordered fallback chain preserving existing routing behavior
    const attempts: Array<{ name: string; run: () => Promise<string | null> }> = [];

    if (preferredProvider === 'cloudflare') {
      attempts.push({
        name: 'cloudflare',
        run: () => callCloudflareSummarize({ accountId: cfAccountId, apiToken: cfApiToken, text: prompt, maxTokens }),
      });
    } else if (preferredProvider === 'gemini') {
      attempts.push({
        name: 'gemini',
        run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
      });
    } else if (preferredProvider === 'cohere' && !jsonMode) {
      attempts.push({
        name: 'cohere',
        run: () => callCohereChat({ apiKey: cohereKey, model: modelHint, prompt, systemPrompt, temperature }),
      });
    } else if (preferredProvider === 'openrouter') {
      attempts.push({
        name: 'openrouter',
        run: () => callOpenRouterChat({ apiKey: openRouterKey, model: modelHint, prompt, systemPrompt, jsonMode, maxTokens }),
      });
    }

    if (tier === 'realtime') {
      attempts.push(
        {
          name: 'groq_speed',
          run: () => callGroqChat({ apiKey: groqKey, model: 'llama-3.1-8b-instant', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: modelHint, prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'gemini',
          run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        }
      );
    } else {
      attempts.push(
        {
          name: 'groq_heavy',
          run: () => callGroqChat({ apiKey: groqKey, model: 'llama-3.3-70b-versatile', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'gemini',
          run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: modelHint, prompt, systemPrompt, jsonMode, maxTokens }),
        }
      );
      if (!jsonMode) {
        attempts.push({
          name: 'cohere',
          run: () => callCohereChat({ apiKey: cohereKey, prompt, systemPrompt, temperature }),
        });
      }
    }

    for (const attempt of attempts) {
      try {
        const res = await attempt.run();
        if (res) {
          text = res;
          usedProvider = attempt.name;
          break;
        }
      } catch {
        // Try next provider in fallback chain
      }
    }

    if (!text) {
      return jsonResponse({ error: 'All AI providers are currently unavailable.' }, 502);
    }

    return jsonResponse({ text, provider: usedProvider, requestId, quota: quotaCheck });
  } catch {
    return jsonResponse({ error: 'AI gateway request failed' }, 500);
  }
});
