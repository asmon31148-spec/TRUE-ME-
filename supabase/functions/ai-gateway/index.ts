// TRUE ME — Authenticated AI Gateway Edge Function (SEC-01 / AI-01 / AI-02 / AI Monitor)
// Supports: chat (with tier & provider fallback), embed (768-dim L2), rerank, transcribe,
// and provider_quotas (official provider usage, credits, models & rate-limit discovery).
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
const COOLDOWN_MS = 60_000;
const modelCooldownUntil = new Map<string, number>();

function isInCooldown(key: string): boolean {
  const until = modelCooldownUntil.get(key);
  if (!until) return false;
  if (Date.now() >= until) {
    modelCooldownUntil.delete(key);
    return false;
  }
  return true;
}

function markCooldown(key: string) {
  modelCooldownUntil.set(key, Date.now() + COOLDOWN_MS);
}

interface ProviderCallResult {
  text: string;
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  cachedTokens: number;
  totalTokens: number;
  tokenSource: 'OFFICIAL' | 'ESTIMATED';
  costUsd?: number;
  costSource?: 'OFFICIAL' | 'ESTIMATED';
  rateLimits: Record<string, string>;
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function extractRateLimitHeaders(headers: Headers): Record<string, string> {
  const out: Record<string, string> = {};
  const keys = [
    'x-ratelimit-limit-requests',
    'x-ratelimit-remaining-requests',
    'x-ratelimit-reset-requests',
    'x-ratelimit-limit-tokens',
    'x-ratelimit-remaining-tokens',
    'x-ratelimit-reset-tokens',
    'x-ratelimit-limit',
    'x-ratelimit-remaining',
    'x-ratelimit-reset',
    'x-trial-endpoint-call-remaining',
  ];
  for (const k of keys) {
    const v = headers.get(k);
    if (v !== null && v.trim() !== '') out[k] = v.trim();
  }
  return out;
}

function sanitizeModelOutput(text: string): string {
  // Strip <think>...</think> reasoning blocks so all models produce clean student-facing output
  return text.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
}

function estimateTokens(text: string): number {
  const trimmed = text.trim();
  if (!trimmed) return 0;
  return Math.max(1, Math.ceil(trimmed.length / 4));
}

async function callGroqChat(params: {
  apiKey: string;
  providerName: string;
  model: string;
  prompt: string;
  systemPrompt?: string;
  jsonMode?: boolean;
  temperature?: number;
  maxTokens?: number;
}): Promise<ProviderCallResult | null> {
  if (!params.apiKey) return null;
  const messages = [
    ...(params.systemPrompt ? [{ role: 'system', content: params.systemPrompt }] : []),
    { role: 'user', content: params.prompt },
  ];
  const resp = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    signal: AbortSignal.timeout(15_000),
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
  if (typeof text !== 'string' || !text.trim()) return null;

  const usage = data?.usage;
  const hasOfficial = typeof usage?.prompt_tokens === 'number' || typeof usage?.total_tokens === 'number';
  const inputTokens = typeof usage?.prompt_tokens === 'number'
    ? usage.prompt_tokens
    : estimateTokens(`${params.systemPrompt ?? ''} ${params.prompt}`);
  const outputTokens = typeof usage?.completion_tokens === 'number'
    ? usage.completion_tokens
    : estimateTokens(text);

  return {
    text,
    provider: params.providerName,
    model: String(data?.model || params.model),
    inputTokens,
    outputTokens,
    cachedTokens: 0,
    totalTokens: typeof usage?.total_tokens === 'number' ? usage.total_tokens : inputTokens + outputTokens,
    tokenSource: hasOfficial ? 'OFFICIAL' : 'ESTIMATED',
    rateLimits: extractRateLimitHeaders(resp.headers),
  };
}

async function callGeminiChat(params: {
  apiKey: string;
  prompt: string;
  systemPrompt?: string;
  jsonMode?: boolean;
  temperature?: number;
  maxTokens?: number;
}): Promise<ProviderCallResult | null> {
  if (!params.apiKey) return null;
  const models = [
    'gemini-2.5-flash',
    'gemini-flash-latest',
    'gemini-2.0-flash',
  ];
  for (const model of models) {
    const resp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${params.apiKey}`,
      {
        method: 'POST',
        signal: AbortSignal.timeout(16_000),
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...(params.systemPrompt
            ? { systemInstruction: { parts: [{ text: params.systemPrompt }] } }
            : {}),
          contents: [{ role: 'user', parts: [{ text: params.prompt }] }],
          generationConfig: {
            temperature: params.temperature ?? (params.systemPrompt ? 0.3 : 0.4),
            maxOutputTokens: params.maxTokens ?? 8192,
            ...(params.jsonMode ? { responseMimeType: 'application/json' } : {}),
          },
        }),
      }
    );
    if (!resp.ok) continue;
    const data = await resp.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text === 'string' && text.trim()) {
      const meta = data?.usageMetadata;
      const hasOfficial = typeof meta?.promptTokenCount === 'number' || typeof meta?.totalTokenCount === 'number';
      const inputTokens = typeof meta?.promptTokenCount === 'number'
        ? meta.promptTokenCount
        : estimateTokens(`${params.systemPrompt ?? ''} ${params.prompt}`);
      const outputTokens = typeof meta?.candidatesTokenCount === 'number'
        ? meta.candidatesTokenCount
        : estimateTokens(text);
      const cachedTokens = typeof meta?.cachedContentTokenCount === 'number' ? meta.cachedContentTokenCount : 0;
      return {
        text,
        provider: 'gemini',
        model,
        inputTokens,
        outputTokens,
        cachedTokens,
        totalTokens: typeof meta?.totalTokenCount === 'number' ? meta.totalTokenCount : inputTokens + outputTokens,
        tokenSource: hasOfficial ? 'OFFICIAL' : 'ESTIMATED',
        rateLimits: extractRateLimitHeaders(resp.headers),
      };
    }
  }
  return null;
}

async function callOpenRouterChat(params: {
  apiKey: string;
  model?: string;
  prompt: string;
  systemPrompt?: string;
  jsonMode?: boolean;
  temperature?: number;
  maxTokens?: number;
}): Promise<ProviderCallResult | null> {
  if (!params.apiKey) return null;
  const targetModel = params.model || 'nvidia/nemotron-3.5-lightning:free';
  const sysText = params.jsonMode
    ? `${params.systemPrompt ? params.systemPrompt + '\n\n' : ''}CRITICAL: Return ONLY valid JSON with no markdown fences or extra commentary.`
    : params.systemPrompt;
  const messages = [
    ...(sysText ? [{ role: 'system', content: sysText }] : []),
    { role: 'user', content: params.prompt },
  ];
  const doFetch = (withJsonFormat: boolean) =>
    fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      signal: AbortSignal.timeout(16_000),
      headers: {
        Authorization: `Bearer ${params.apiKey}`,
        'HTTP-Referer': 'https://github.com/asmon31148-spec/TRUE-ME-',
        'X-Title': 'True Me Study App',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: targetModel,
        messages,
        temperature: params.temperature ?? 0.3,
        ...(params.maxTokens ? { max_tokens: params.maxTokens } : {}),
        ...(withJsonFormat ? { response_format: { type: 'json_object' } } : {}),
      }),
    });

  let resp = await doFetch(Boolean(params.jsonMode));
  if (!resp.ok && params.jsonMode && resp.status === 400) {
    resp = await doFetch(false);
  }
  if (!resp.ok) return null;
  const data = await resp.json();
  const rawText = data?.choices?.[0]?.message?.content;
  if (typeof rawText !== 'string' || !rawText.trim()) return null;
  const text = sanitizeModelOutput(rawText);
  if (!text) return null;

  const usage = data?.usage;
  const hasOfficial = typeof usage?.prompt_tokens === 'number' || typeof usage?.total_tokens === 'number';
  const inputTokens = typeof usage?.prompt_tokens === 'number'
    ? usage.prompt_tokens
    : estimateTokens(`${params.systemPrompt ?? ''} ${params.prompt}`);
  const outputTokens = typeof usage?.completion_tokens === 'number'
    ? usage.completion_tokens
    : estimateTokens(text);

  return {
    text,
    provider: 'openrouter',
    model: String(data?.model || targetModel),
    inputTokens,
    outputTokens,
    cachedTokens: 0,
    totalTokens: typeof usage?.total_tokens === 'number' ? usage.total_tokens : inputTokens + outputTokens,
    tokenSource: hasOfficial ? 'OFFICIAL' : 'ESTIMATED',
    costUsd: typeof usage?.cost === 'number' ? usage.cost : undefined,
    costSource: typeof usage?.cost === 'number' ? 'OFFICIAL' : undefined,
    rateLimits: extractRateLimitHeaders(resp.headers),
  };
}

async function callCohereChat(params: {
  apiKey: string;
  model?: string;
  prompt: string;
  systemPrompt?: string;
  temperature?: number;
}): Promise<ProviderCallResult | null> {
  if (!params.apiKey) return null;
  const targetModel = params.model || 'command-r-plus-08-2024';
  const messages = [
    ...(params.systemPrompt ? [{ role: 'system', content: params.systemPrompt }] : []),
    { role: 'user', content: params.prompt },
  ];
  const resp = await fetch('https://api.cohere.com/v2/chat', {
    method: 'POST',
    signal: AbortSignal.timeout(15_000),
    headers: {
      Authorization: `Bearer ${params.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: targetModel,
      messages,
      temperature: params.temperature ?? 0.3,
    }),
  });
  if (!resp.ok) return null;
  const data = await resp.json();
  const text = data?.message?.content?.[0]?.text;
  if (typeof text !== 'string' || !text.trim()) return null;

  const tokens = data?.usage?.tokens ?? data?.meta?.tokens ?? data?.meta?.billed_units;
  const hasOfficial = typeof tokens?.input_tokens === 'number' || typeof tokens?.output_tokens === 'number';
  const inputTokens = typeof tokens?.input_tokens === 'number'
    ? tokens.input_tokens
    : estimateTokens(`${params.systemPrompt ?? ''} ${params.prompt}`);
  const outputTokens = typeof tokens?.output_tokens === 'number'
    ? tokens.output_tokens
    : estimateTokens(text);

  return {
    text,
    provider: 'cohere',
    model: targetModel,
    inputTokens,
    outputTokens,
    cachedTokens: 0,
    totalTokens: inputTokens + outputTokens,
    tokenSource: hasOfficial ? 'OFFICIAL' : 'ESTIMATED',
    rateLimits: extractRateLimitHeaders(resp.headers),
  };
}

async function callCloudflareSummarize(params: {
  accountId: string;
  apiToken: string;
  text: string;
  maxTokens?: number;
}): Promise<ProviderCallResult | null> {
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
  if (typeof out !== 'string' || !out.trim()) return null;

  const inputTokens = estimateTokens(params.text);
  const outputTokens = estimateTokens(out);
  return {
    text: out,
    provider: 'cloudflare',
    model: '@cf/meta/llama-3-8b-instruct',
    inputTokens,
    outputTokens,
    cachedTokens: 0,
    totalTokens: inputTokens + outputTokens,
    tokenSource: 'ESTIMATED',
    rateLimits: extractRateLimitHeaders(resp.headers),
  };
}

async function fetchOfficialProviderQuotas(secrets: {
  geminiKey: string;
  groqKey: string;
  openRouterKey: string;
  cohereKey: string;
  cfAccountId: string;
  cfApiToken: string;
}) {
  const fetchedAt = new Date().toISOString();

  const [openRouterRes, groqRes, geminiRes, cohereRes, cfRes] = await Promise.allSettled([
    // 1. OpenRouter Official Key & Credits API
    (async () => {
      if (!secrets.openRouterKey) {
        return { provider: 'openrouter', status: 'UNAVAILABLE', error: 'OPENROUTER_API_KEY not configured' };
      }
      const keyResp = await fetch('https://openrouter.ai/api/v1/key', {
        headers: { Authorization: `Bearer ${secrets.openRouterKey}` },
      });
      if (!keyResp.ok) {
        return { provider: 'openrouter', status: 'UNAVAILABLE', error: `HTTP ${keyResp.status}` };
      }
      const keyJson = await keyResp.json();
      const d = keyJson?.data ?? {};
      return {
        provider: 'openrouter',
        status: 'OFFICIAL',
        limit: d.limit ?? null,
        limitRemaining: d.limit_remaining ?? null,
        limitReset: d.limit_reset ?? null,
        usageTotal: d.usage ?? null,
        usageDaily: d.usage_daily ?? null,
        usageWeekly: d.usage_weekly ?? null,
        usageMonthly: d.usage_monthly ?? null,
        isFreeTier: d.is_free_tier ?? null,
        rateLimit: d.rate_limit ?? null,
      };
    })(),

    // 2. Groq Official Models Discovery
    (async () => {
      if (!secrets.groqKey) {
        return { provider: 'groq', status: 'UNAVAILABLE', error: 'GROQ_API_KEY not configured' };
      }
      const resp = await fetch('https://api.groq.com/openai/v1/models', {
        headers: { Authorization: `Bearer ${secrets.groqKey}` },
      });
      if (!resp.ok) {
        return { provider: 'groq', status: 'UNAVAILABLE', error: `HTTP ${resp.status}` };
      }
      const json = await resp.json();
      const models = Array.isArray(json?.data)
        ? json.data.map((m: Record<string, unknown>) => ({
            id: String(m.id ?? ''),
            active: m.active !== false,
            contextWindow: m.context_window ?? null,
          }))
        : [];
      return {
        provider: 'groq',
        status: 'OFFICIAL',
        models,
        rateLimits: extractRateLimitHeaders(resp.headers),
        note: 'Groq exposes model inventory via /models and live RPM/TPM remaining via chat response headers.',
      };
    })(),

    // 3. Google Gemini Official Models Discovery
    (async () => {
      if (!secrets.geminiKey) {
        return { provider: 'gemini', status: 'UNAVAILABLE', error: 'GEMINI_API_KEY not configured' };
      }
      const resp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models?key=${secrets.geminiKey}`
      );
      if (!resp.ok) {
        return { provider: 'gemini', status: 'UNAVAILABLE', error: `HTTP ${resp.status}` };
      }
      const json = await resp.json();
      const models = Array.isArray(json?.models)
        ? json.models.map((m: Record<string, unknown>) => ({
            id: String(m.name ?? '').replace(/^models\//, ''),
            displayName: String(m.displayName ?? ''),
            inputTokenLimit: m.inputTokenLimit ?? null,
            outputTokenLimit: m.outputTokenLimit ?? null,
          }))
        : [];
      return {
        provider: 'gemini',
        status: 'OFFICIAL',
        models,
        note: 'Google AI Studio API keys expose model limits & per-call usageMetadata; account RPD balance is not exposed by Google REST API.',
      };
    })(),

    // 4. Cohere Official Models Discovery
    (async () => {
      if (!secrets.cohereKey) {
        return { provider: 'cohere', status: 'UNAVAILABLE', error: 'COHERE_API_KEY not configured' };
      }
      const resp = await fetch('https://api.cohere.com/v1/models', {
        headers: { Authorization: `Bearer ${secrets.cohereKey}` },
      });
      if (!resp.ok) {
        return { provider: 'cohere', status: 'UNAVAILABLE', error: `HTTP ${resp.status}` };
      }
      const json = await resp.json();
      const models = Array.isArray(json?.models)
        ? json.models.map((m: Record<string, unknown>) => ({
            id: String(m.name ?? ''),
            contextLength: m.context_length ?? null,
          }))
        : [];
      return {
        provider: 'cohere',
        status: 'OFFICIAL',
        models,
        rateLimits: extractRateLimitHeaders(resp.headers),
      };
    })(),

    // 5. Cloudflare Workers AI Status
    (async () => {
      if (!secrets.cfAccountId || !secrets.cfApiToken) {
        return { provider: 'cloudflare', status: 'UNAVAILABLE', error: 'Cloudflare credentials not configured' };
      }
      return {
        provider: 'cloudflare',
        status: 'OFFICIAL',
        models: [{ id: '@cf/meta/llama-3-8b-instruct', active: true }],
        dailyNeuronsLimit: 10000,
      };
    })(),
  ]);

  const unwrap = (r: PromiseSettledResult<Record<string, unknown>>, name: string) =>
    r.status === 'fulfilled'
      ? r.value
      : { provider: name, status: 'UNAVAILABLE', error: String(r.reason ?? 'Fetch failed') };

  return {
    fetchedAt,
    providers: {
      openrouter: unwrap(openRouterRes, 'openrouter'),
      groq: unwrap(groqRes, 'groq'),
      gemini: unwrap(geminiRes, 'gemini'),
      cohere: unwrap(cohereRes, 'cohere'),
      cloudflare: unwrap(cfRes, 'cloudflare'),
    },
  };
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

    const groqKey = Deno.env.get('GROQ_API_KEY') ?? '';
    const geminiKey = Deno.env.get('GEMINI_API_KEY') ?? '';
    const openRouterKey = Deno.env.get('OPENROUTER_API_KEY') ?? '';
    const cohereKey = Deno.env.get('COHERE_API_KEY') ?? '';
    const cfAccountId = Deno.env.get('CLOUDFLARE_ACCOUNT_ID') ?? '';
    const cfApiToken = Deno.env.get('CLOUDFLARE_API_TOKEN') ?? '';

    // Official Provider Quota & Model Discovery endpoint (does not consume user AI quota)
    if (action === 'provider_quotas') {
      const snapshot = await fetchOfficialProviderQuotas({
        geminiKey,
        groqKey,
        openRouterKey,
        cohereKey,
        cfAccountId,
        cfApiToken,
      });
      return jsonResponse(snapshot);
    }

    const requestId = String(body.requestId || crypto.randomUUID());
    const taskType = String(body.taskType || action);

    // Background RAG indexing (batch_embed, embed, rerank) does NOT consume
    // the student's daily chat/study quota so uploading books never locks out AI.
    if (action === 'batch_embed') {
      const started = Date.now();
      const rawTexts: string[] = Array.isArray(body.texts)
        ? body.texts.slice(0, 50).map((t: unknown) => String(t || '').trim()).filter((t: string) => t.length > 0)
        : [];
      if (rawTexts.length === 0) {
        return jsonResponse({ error: 'Invalid batch embedding input' }, 400);
      }
      if (!geminiKey) {
        return jsonResponse({ error: 'Embedding service unavailable' }, 503);
      }
      const resp = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:batchEmbedContents?key=${geminiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            requests: rawTexts.map((text) => ({
              model: 'models/gemini-embedding-001',
              content: { parts: [{ text: text.slice(0, MAX_PROMPT_CHARS) }] },
              outputDimensionality: 768,
            })),
          }),
        }
      );
      if (!resp.ok) {
        return jsonResponse({ error: 'Batch embedding generation failed' }, 502);
      }
      const data = await resp.json();
      const rawList = Array.isArray(data?.embeddings) ? data.embeddings : [];
      const embeddings = rawList.map((item: { values?: number[] }) => {
        const vals = Array.isArray(item?.values) ? item.values.slice(0, 768) : [];
        if (vals.length !== 768) return [];
        const norm = Math.sqrt(vals.reduce((sum, v) => sum + v * v, 0));
        return norm > 0 ? vals.map((v) => v / norm) : vals;
      });
      if (embeddings.length !== rawTexts.length || embeddings.some((e: number[]) => e.length !== 768)) {
        return jsonResponse({ error: 'Unexpected batch embedding dimensions' }, 502);
      }
      const inTok = rawTexts.reduce((sum, t) => sum + estimateTokens(t), 0);
      return jsonResponse({
        embeddings,
        dimensions: 768,
        requestId,
        telemetry: {
          provider: 'gemini',
          model: 'gemini-embedding-001',
          inputTokens: inTok,
          outputTokens: 0,
          cachedTokens: 0,
          totalTokens: inTok,
          tokenSource: 'ESTIMATED',
          latencyMs: Date.now() - started,
          fallbackUsed: false,
          attemptCount: 1,
          rateLimits: extractRateLimitHeaders(resp.headers),
        },
      });
    }

    if (action === 'embed') {
      const started = Date.now();
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
      const inTok = estimateTokens(text);
      return jsonResponse({
        embedding,
        dimensions: 768,
        requestId,
        telemetry: {
          provider: 'gemini',
          model: 'gemini-embedding-001',
          inputTokens: inTok,
          outputTokens: 0,
          cachedTokens: 0,
          totalTokens: inTok,
          tokenSource: 'ESTIMATED',
          latencyMs: Date.now() - started,
          fallbackUsed: false,
          attemptCount: 1,
          rateLimits: extractRateLimitHeaders(resp.headers),
        },
      });
    }

    if (action === 'rerank') {
      const started = Date.now();
      const query = String(body.query || '').trim();
      const documents: string[] = Array.isArray(body.documents)
        ? body.documents.slice(0, MAX_RERANK_DOCS).map((d: unknown) => String(d))
        : [];
      const topN = Math.min(Math.max(Number(body.topN || 4), 1), documents.length || 1);

      if (!query || documents.length === 0) {
        return jsonResponse({ documents: [], requestId });
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
              const billed = data?.meta?.billed_units;
              const inTok = typeof billed?.search_units === 'number'
                ? billed.search_units * 100
                : estimateTokens(`${query} ${documents.join(' ')}`);
              return jsonResponse({
                documents: reranked,
                provider: 'cohere',
                requestId,
                telemetry: {
                  provider: 'cohere',
                  model: 'rerank-v3.5',
                  inputTokens: inTok,
                  outputTokens: 0,
                  cachedTokens: 0,
                  totalTokens: inTok,
                  tokenSource: billed ? 'OFFICIAL' : 'ESTIMATED',
                  latencyMs: Date.now() - started,
                  fallbackUsed: false,
                  attemptCount: 1,
                  rateLimits: extractRateLimitHeaders(resp.headers),
                },
              });
            }
          }
        } catch {
          // Graceful fallback to original vector order
        }
      }
      return jsonResponse({ documents: documents.slice(0, topN), provider: 'fallback', requestId });
    }

    // Enforce server-side daily quota atomically via Postgres RPC for chat & transcription
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

    if (action === 'transcribe') {
      const started = Date.now();
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
      const text = String(data?.text || '');
      const outTok = estimateTokens(text);
      return jsonResponse({
        text,
        provider: 'groq_whisper',
        requestId,
        quota: quotaCheck,
        telemetry: {
          provider: 'groq',
          model: 'whisper-large-v3',
          inputTokens: 0,
          outputTokens: outTok,
          cachedTokens: 0,
          totalTokens: outTok,
          tokenSource: 'ESTIMATED',
          latencyMs: Date.now() - started,
          fallbackUsed: false,
          attemptCount: 1,
          rateLimits: extractRateLimitHeaders(resp.headers),
        },
      });
    }

    // Default action: 'chat'
    const started = Date.now();
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

    let result: ProviderCallResult | null = null;
    let attemptCount = 0;

    const attempts: Array<{ name: string; run: () => Promise<ProviderCallResult | null> }> = [];

    if (preferredProvider === 'gemini') {
      attempts.push({
        name: 'gemini:2.5-flash',
        run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
      });
    } else if (preferredProvider === 'cohere' && !jsonMode) {
      attempts.push({
        name: 'cohere:command-r-plus',
        run: () => callCohereChat({ apiKey: cohereKey, model: modelHint, prompt, systemPrompt, temperature }),
      });
    } else if (preferredProvider === 'groq') {
      attempts.push({
        name: 'groq:gpt-oss-120b',
        run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'openai/gpt-oss-120b', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
      });
    } else if (preferredProvider === 'openrouter') {
      attempts.push({
        name: `openrouter:${modelHint || 'nemotron-lightning'}`,
        run: () => callOpenRouterChat({ apiKey: openRouterKey, model: modelHint, prompt, systemPrompt, jsonMode, maxTokens }),
      });
    }

    if (tier === 'realtime' || taskType === 'realtime_chat' || taskType === 'groq_speed') {
      attempts.push(
        {
          name: 'groq:llama-3.1-8b-instant',
          run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'llama-3.1-8b-instant', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter:liquid-lfm-3',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: 'liquid/lfm-3-1.7b:free', prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'groq:gpt-oss-20b',
          run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'openai/gpt-oss-20b', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter:nemotron-lightning',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: modelHint || 'nvidia/nemotron-3.5-lightning:free', prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'gemini:2.5-flash',
          run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        }
      );
    } else if (taskType === 'heavy_reasoning' || taskType === 'study_plan' || taskType === 'gemini_chat') {
      attempts.push(
        {
          name: 'gemini:2.5-flash',
          run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter:nemotron-ultra',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: 'nvidia/nemotron-3-ultra-550b-a55b:free', prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'groq:gpt-oss-120b',
          run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'openai/gpt-oss-120b', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter:nemotron-omni',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free', prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'groq:llama-3.3-70b',
          run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'llama-3.3-70b-versatile', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        }
      );
    } else if (taskType === 'mindmap') {
      attempts.push(
        {
          name: 'openrouter:nemotron-omni',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free', prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'groq:llama-3.3-70b',
          run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'llama-3.3-70b-versatile', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'gemini:2.5-flash',
          run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter:nemotron-lightning',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: 'nvidia/nemotron-3.5-lightning:free', prompt, systemPrompt, jsonMode, maxTokens }),
        }
      );
    } else if (taskType === 'cloudflare_summarize' || taskType === 'summarize' || taskType === 'url_summarize') {
      attempts.push(
        {
          name: 'openrouter:gemma-4-26b',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: 'google/gemma-4-26b-a4b-it:free', prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'groq:llama-3.1-8b-instant',
          run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'llama-3.1-8b-instant', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter:liquid-lfm-3',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: 'liquid/lfm-3-1.7b:free', prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'gemini:2.5-flash',
          run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        }
      );
    } else if (taskType === 'chat_with_notes' && !jsonMode) {
      attempts.push(
        {
          name: 'cohere:command-r-plus',
          run: () => callCohereChat({ apiKey: cohereKey, prompt, systemPrompt, temperature }),
        },
        {
          name: 'gemini:2.5-flash',
          run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter:nemotron-lightning',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: 'nvidia/nemotron-3.5-lightning:free', prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'groq:llama-3.3-70b',
          run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'llama-3.3-70b-versatile', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        }
      );
    } else {
      // Quiz, Flashcards, and general balanced chat
      attempts.push(
        {
          name: 'groq:gpt-oss-120b',
          run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'openai/gpt-oss-120b', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'openrouter:nemotron-lightning',
          run: () => callOpenRouterChat({ apiKey: openRouterKey, model: modelHint || 'nvidia/nemotron-3.5-lightning:free', prompt, systemPrompt, jsonMode, maxTokens }),
        },
        {
          name: 'gemini:2.5-flash',
          run: () => callGeminiChat({ apiKey: geminiKey, prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        },
        {
          name: 'groq:llama-3.3-70b',
          run: () => callGroqChat({ apiKey: groqKey, providerName: 'groq', model: 'llama-3.3-70b-versatile', prompt, systemPrompt, jsonMode, temperature, maxTokens }),
        }
      );
      if (!jsonMode) {
        attempts.push({
          name: 'cohere:command-r-plus',
          run: () => callCohereChat({ apiKey: cohereKey, prompt, systemPrompt, temperature }),
        });
      }
    }

    for (const attempt of attempts) {
      if (isInCooldown(attempt.name)) continue;
      attemptCount++;
      try {
        const res = await attempt.run();
        if (res) {
          result = res;
          break;
        }
        markCooldown(attempt.name);
      } catch {
        markCooldown(attempt.name);
      }
    }

    // Emergency pass: if every candidate was in cooldown, try once ignoring cooldown
    if (!result) {
      for (const attempt of attempts) {
        attemptCount++;
        try {
          const res = await attempt.run();
          if (res) {
            result = res;
            break;
          }
        } catch {
          // continue
        }
      }
    }

    if (!result) {
      return jsonResponse({ error: 'All AI providers are currently unavailable.' }, 502);
    }

    return jsonResponse({
      text: sanitizeModelOutput(result.text),
      provider: result.provider,
      model: result.model,
      requestId,
      quota: quotaCheck,
      telemetry: {
        provider: result.provider,
        model: result.model,
        inputTokens: result.inputTokens,
        outputTokens: result.outputTokens,
        cachedTokens: result.cachedTokens,
        totalTokens: result.totalTokens,
        tokenSource: result.tokenSource,
        costUsd: result.costUsd,
        costSource: result.costSource,
        rateLimits: result.rateLimits,
        latencyMs: Date.now() - started,
        fallbackUsed: attemptCount > 1,
        attemptCount,
      },
    });
  } catch {
    return jsonResponse({ error: 'AI gateway request failed' }, 500);
  }
});
