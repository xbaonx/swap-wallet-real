/*
  Minimal backend for Wert session creation, suitable for Render.com deployment.
  - POST /api/wert/create-session -> forwards to Wert Partner API and returns { sessionId }
  - GET  /healthz -> health check

  Environment variables (Render):
  - PORT (provided by Render)
  - DB_PATH (e.g. /var/data/app.db)
  - CORS_ORIGINS (comma-separated, optional)
  - WERT_ENV (sandbox|production)
  - WERT_PARTNER_ID (required if not sent by client)
  - WERT_API_KEY (required)
  - WERT_AUTH_SCHEME (bearer|x-api-key, default: bearer)
  - WERT_CREATE_SESSION_URL (full URL to Wert Partner create-session endpoint; required)
  - WERT_REDIRECT_URL (optional, used by client but available here for consistency)
*/

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const axios = require('axios');
const Database = require('better-sqlite3');
const { v4: uuidv4 } = require('uuid');
const pino = require('pino');
const pinoHttp = require('pino-http');
const promClient = require('prom-client');
const jwt = require('jsonwebtoken');
const basicAuth = require('express-basic-auth');
const Sentry = require('@sentry/node');

// ----- Config -----
const PORT = process.env.PORT || 3000;
const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'data', 'app.db');
const CORS_ORIGINS = (process.env.CORS_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
const WERT_ENV = (process.env.WERT_ENV || 'sandbox').toLowerCase();
const WERT_PARTNER_ID = process.env.WERT_PARTNER_ID || '';
const WERT_API_KEY = process.env.WERT_API_KEY || '';
const WERT_AUTH_SCHEME = (process.env.WERT_AUTH_SCHEME || 'bearer').toLowerCase();
const WERT_CREATE_SESSION_URL = process.env.WERT_CREATE_SESSION_URL || '';
const ONEINCH_API_KEY = process.env.ONEINCH_API_KEY || '';
const MORALIS_API_KEY = process.env.MORALIS_API_KEY || '';
const ONEINCH_UPSTREAM_BASE = process.env.ONEINCH_UPSTREAM_BASE || 'https://api.1inch.dev';
const MORALIS_UPSTREAM_BASE = process.env.MORALIS_UPSTREAM_BASE || 'https://deep-index.moralis.io/api/v2.2';
// Observability / Security / Admin
const SENTRY_DSN = process.env.SENTRY_DSN || '';
const JWT_SECRET = process.env.JWT_SECRET || '';
const HMAC_SECRET = process.env.HMAC_SECRET || '';
const BASIC_AUTH_USER = process.env.BASIC_AUTH_USER || '';
const BASIC_AUTH_PASS = process.env.BASIC_AUTH_PASS || '';
const DENY_IPS = (process.env.DENY_IPS || '').split(',').map(s => s.trim()).filter(Boolean);
const DENY_COUNTRIES = (process.env.DENY_COUNTRIES || '').split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
const RETENTION_DAYS = parseInt(process.env.RETENTION_DAYS || '60', 10);
// Tokens / Prices
const TOKEN_REGISTRY_URL = process.env.TOKEN_REGISTRY_URL || '';
const TOKEN_REGISTRY_CACHE_TTL_MS = parseInt(process.env.TOKEN_REGISTRY_CACHE_TTL_MS || '3600000', 10); // 1h
const ALLOW_TOKENS = (process.env.ALLOW_TOKENS || '').toLowerCase().split(',').map(s => s.trim()).filter(Boolean);
const DENY_TOKENS = (process.env.DENY_TOKENS || '').toLowerCase().split(',').map(s => s.trim()).filter(Boolean);
// RPC relay
const PRIVATE_RPC_URLS = (process.env.PRIVATE_RPC_URLS || '').split(',').map(s => s.trim()).filter(Boolean);
const PENDING_EXPIRY_HOURS = parseInt(process.env.PENDING_EXPIRY_HOURS || '24', 10);
// Notifications (OneSignal)
const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID || '';
const ONESIGNAL_API_KEY = process.env.ONESIGNAL_API_KEY || '';
// Webhook verify
const WERT_WEBHOOK_SECRET = process.env.WERT_WEBHOOK_SECRET || '';

if (!WERT_CREATE_SESSION_URL) {
  // We don't throw here to allow healthz, but route will reject without it.
  console.warn('[config] Missing WERT_CREATE_SESSION_URL');
}
if (!WERT_API_KEY) {
  console.warn('[config] Missing WERT_API_KEY');
}
if (!ONEINCH_API_KEY) {
  console.warn('[config] Missing ONEINCH_API_KEY (needed for /api/oneinch proxy)');
}
if (!MORALIS_API_KEY) {
  console.warn('[config] Missing MORALIS_API_KEY (needed for /api/moralis proxy)');
}

// ----- App & Middlewares -----
const app = express();
// Sentry
if (SENTRY_DSN) {
  Sentry.init({ dsn: SENTRY_DSN, tracesSampleRate: 0.05 });
  app.use(Sentry.Handlers.requestHandler());
}

// ---- Tokens and Config ----
app.get('/api/tokens', async (req, res) => {
  try {
    const data = await getTokenRegistry();
    return res.json(data);
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

app.get('/api/config', (req, res) => {
  try {
    return res.json({
      env: WERT_ENV,
      features: {
        sse_prices: true,
        rpc_private_gateway: PRIVATE_RPC_URLS.length > 0,
        analytics: true,
        notifications: !!(ONESIGNAL_APP_ID && ONESIGNAL_API_KEY),
      },
    });
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ---- Analytics ----
app.post('/api/analytics/track', appAuth(), (req, res) => {
  try {
    const { event_name, session_id, wallet_address, props } = req.body || {};
    if (!event_name || typeof event_name !== 'string') {
      return res.status(400).json({ error: 'invalid_event_name' });
    }
    const stmt = db.prepare(`
      INSERT INTO analytics_events (event_name, session_id, wallet_address, props, created_at)
      VALUES (?, ?, ?, ?, ?)
    `);
    stmt.run(
      event_name,
      session_id || null,
      wallet_address || null,
      props ? JSON.stringify(props) : null,
      nowMs()
    );
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ---- Notifications device register ----
app.post('/api/notify/register', appAuth(), (req, res) => {
  try {
    const { wallet_address, external_user_id, platform } = req.body || {};
    if (!wallet_address || typeof wallet_address !== 'string' || !wallet_address.startsWith('0x') || wallet_address.length !== 42) {
      return res.status(400).json({ error: 'invalid_wallet_address' });
    }
    if (!external_user_id) {
      return res.status(400).json({ error: 'invalid_external_user_id' });
    }
    const stmt = db.prepare(`
      INSERT INTO devices (wallet_address, external_user_id, platform, created_at)
      VALUES (?, ?, ?, ?)
    `);
    stmt.run(wallet_address, String(external_user_id), platform || null, nowMs());
    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ---- SSE Prices stream ----
app.get('/api/prices/stream', async (req, res) => {
  try {
    if (!MORALIS_API_KEY) return res.status(500).json({ error: 'server_misconfigured', message: 'Missing MORALIS_API_KEY' });
    const chain = (req.query.chain || 'eth').toString();
    const addresses = ((req.query.addresses || '') + '').split(',').map(s => s.trim()).filter(Boolean);
    if (addresses.length === 0) return res.status(400).json({ error: 'no_addresses' });
    if (addresses.length > 20) return res.status(400).json({ error: 'too_many_addresses' });

    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    });

    const writeEvent = (event, data) => {
      res.write(`event: ${event}\n`);
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    };
    writeEvent('ready', { ok: true, addresses });

    let closed = false;
    req.on('close', () => { closed = true; clearInterval(timer); });

    async function fetchAndSend() {
      for (const addr of addresses) {
        if (closed) return;
        try {
          const url = `${MORALIS_UPSTREAM_BASE}/erc20/${addr}/price`;
          const resp = await axios.get(url, {
            headers: { 'X-API-Key': MORALIS_API_KEY, 'Accept': 'application/json' },
            params: { chain },
            timeout: 12000,
            validateStatus: () => true,
          });
          if (resp.status >= 200 && resp.status < 300) {
            writeEvent('price', { address: addr, data: resp.data });
          }
        } catch (e) {}
      }
      // heartbeat
      writeEvent('heartbeat', { t: Date.now() });
    }

    await fetchAndSend();
    const timer = setInterval(fetchAndSend, 10_000);
    timer.unref?.();
  } catch (e) {
    try { res.end(); } catch {}
  }
});

// ---- RPC relay via private gateway ----
app.post('/api/rpc', appAuth(), async (req, res) => {
  try {
    const { method, params, id } = req.body || {};
    const allowed = new Set([
      'eth_call',
      'eth_estimateGas',
      'eth_getBalance',
      'eth_getTransactionCount',
      'eth_gasPrice',
      'eth_feeHistory',
      'eth_chainId',
      'eth_blockNumber',
      'eth_getBlockByNumber',
      'eth_sendRawTransaction',
    ]);
    if (!method || !allowed.has(String(method))) {
      return res.status(400).json({ error: 'method_not_allowed' });
    }
    const rpcUrl = getRandomPrivateRpcUrl();
    if (!rpcUrl) return res.status(500).json({ error: 'no_private_rpc' });
    const upstream = await axios.post(rpcUrl, {
      jsonrpc: '2.0',
      id: id ?? 1,
      method,
      params: Array.isArray(params) ? params : [],
    }, {
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      timeout: 15000,
      validateStatus: () => true,
    });
    res.status(upstream.status === 200 ? 200 : 502);
    return res.json(upstream.data);
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ---- Admin: analytics summary ----
app.get('/admin/analytics/summary', adminAuth, (req, res) => {
  try {
    const rows = db.prepare(`
      SELECT event_name, COUNT(*) as cnt
      FROM analytics_events
      GROUP BY event_name
      ORDER BY cnt DESC
      LIMIT 100
    `).all();
    return res.json({ events: rows });
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ---- Admin: cron run (cleanup) ----
app.post('/admin/cron/run', adminAuth, (req, res) => {
  try {
    const now = nowMs();
    const cutoff = now - (RETENTION_DAYS * 24 * 60 * 60 * 1000);
    const pendingCutoff = now - (PENDING_EXPIRY_HOURS * 60 * 60 * 1000);

    const del1 = db.prepare(`DELETE FROM analytics_events WHERE created_at < ?`).run(cutoff).changes;
    const del2 = db.prepare(`DELETE FROM wert_webhooks WHERE created_at < ?`).run(cutoff).changes;
    const upd = db.prepare(`UPDATE wert_sessions SET status = 'expired', updated_at = ? WHERE status = 'created' AND created_at < ?`).run(now, pendingCutoff).changes;

    return res.json({ ok: true, deleted_analytics: del1, deleted_webhooks: del2, expired_sessions: upd });
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ---- OpenAPI spec ----
app.get('/openapi.json', (req, res) => {
  const spec = {
    openapi: '3.0.0',
    info: { title: 'Swap Wallet Backend', version: '0.1.0' },
    paths: {
      '/api/wert/create-session': { post: { summary: 'Create Wert session' } },
      '/api/wert/sessions': { get: { summary: 'List Wert sessions' } },
      '/api/wert/sessions/{sessionId}': { get: { summary: 'Wert session detail' } },
      '/api/wert/webhook': { post: { summary: 'Wert webhook' } },
      '/api/tokens': { get: { summary: 'Token registry' } },
      '/api/config': { get: { summary: 'Feature config' } },
      '/api/analytics/track': { post: { summary: 'Track analytics event' } },
      '/api/notify/register': { post: { summary: 'Register device for notifications' } },
      '/api/prices/stream': { get: { summary: 'SSE token prices' } },
      '/api/rpc': { post: { summary: 'RPC relay via private gateway' } },
      '/admin/analytics/summary': { get: { summary: 'Admin analytics summary' } },
      '/admin/cron/run': { post: { summary: 'Admin run cleanup job' } },
    },
  };
  res.json(spec);
});
app.disable('x-powered-by');
app.use(helmet());
// capture raw body for HMAC verify
app.use(express.json({ limit: '1mb', verify: (req, res, buf) => { req.rawBody = buf?.toString('utf8') || ''; } }));
// structured logging
const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
app.use(pinoHttp({ logger }));
app.use(morgan('tiny'));

// CORS
if (CORS_ORIGINS.length > 0) {
  app.use(cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true); // mobile apps / curl
      if (CORS_ORIGINS.includes(origin)) return cb(null, true);
      return cb(new Error('Not allowed by CORS'));
    },
    credentials: false,
  }));
} else {
  app.use(cors()); // permissive; recommend setting CORS_ORIGINS in production
}

// Rate limit: 60 req/min/IP default
const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });
const httpRequestCounter = new promClient.Counter({
  name: 'http_requests_total', help: 'Total HTTP requests', labelNames: ['method', 'route', 'status']
});
register.registerMetric(httpRequestCounter);
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    try { httpRequestCounter.inc({ method: req.method, route: req.route?.path || req.path, status: String(res.statusCode) }); } catch {}
    logger.debug({ path: req.path, ms: Date.now() - start }, 'request');
  });
  next();
});

// ----- DB init -----
(function ensureDb() {
  const dir = path.dirname(DB_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
})();
const db = new Database(DB_PATH);

db.pragma('journal_mode = WAL');
db.exec(`
  CREATE TABLE IF NOT EXISTS wert_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE,
    wallet_address TEXT,
    env TEXT,
    commodity TEXT,
    currency TEXT,
    currency_amount REAL,
    network TEXT,
    status TEXT DEFAULT 'created',
    meta TEXT,
    idempotency_key TEXT,
    created_at INTEGER,
    updated_at INTEGER
  );
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS analytics_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_name TEXT,
    session_id TEXT,
    wallet_address TEXT,
    props TEXT,
    created_at INTEGER
  );
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    wallet_address TEXT,
    external_user_id TEXT,
    platform TEXT,
    created_at INTEGER
  );
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS wert_webhooks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT,
    event_type TEXT,
    payload TEXT,
    created_at INTEGER
  );
`);

// Migrations
function columnExists(table, column) {
  try {
    const rows = db.prepare(`PRAGMA table_info(${table})`).all();
    return Array.isArray(rows) && rows.some(r => r.name === column);
  } catch {
    return false;
  }
}
if (!columnExists('wert_sessions', 'idempotency_key')) {
  try {
    db.exec(`ALTER TABLE wert_sessions ADD COLUMN idempotency_key TEXT`);
  } catch (e) {
    console.warn('Migration: add idempotency_key failed (might already exist):', e.message);
  }
}
db.exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_wert_sessions_idempo ON wert_sessions(idempotency_key)`);

function nowMs() { return Date.now(); }

// ----- Simple in-memory cache for proxy GETs -----
const PROXY_CACHE_TTL_MS = 30_000; // 30s TTL
const proxyCache = new Map();

function makeCacheKey(baseUrl, pathSuffix, queryObj) {
  const params = new URLSearchParams();
  const keys = Object.keys(queryObj || {}).sort();
  for (const k of keys) {
    const v = queryObj[k];
    if (Array.isArray(v)) {
      for (const vi of v) params.append(k, String(vi));
    } else if (v !== undefined && v !== null) {
      params.append(k, String(v));
    }
  }
  return `${baseUrl}${pathSuffix}?${params.toString()}`;
}

function cacheGet(key) {
  const hit = proxyCache.get(key);
  if (!hit) return null;
  if (hit.expiresAt < nowMs()) {
    proxyCache.delete(key);
    return null;
  }
  return hit.value;
}

function cacheSet(key, value, ttlMs = PROXY_CACHE_TTL_MS) {
  proxyCache.set(key, { value, expiresAt: nowMs() + ttlMs });
}

// Periodic cleanup
setInterval(() => {
  const t = nowMs();
  for (const [k, v] of proxyCache.entries()) {
    if (v.expiresAt < t) proxyCache.delete(k);
  }
}, 60_000).unref?.();

// ----- Token registry cache -----
let tokenRegistryCache = { data: null, expiresAt: 0 };

async function getTokenRegistry() {
  const now = nowMs();
  if (tokenRegistryCache.data && tokenRegistryCache.expiresAt > now) return tokenRegistryCache.data;
  if (!TOKEN_REGISTRY_URL) return { tokens: [] };
  try {
    const resp = await axios.get(TOKEN_REGISTRY_URL, { timeout: 10000, validateStatus: () => true });
    if (resp.status >= 200 && resp.status < 300) {
      tokenRegistryCache = { data: resp.data, expiresAt: now + TOKEN_REGISTRY_CACHE_TTL_MS };
      return resp.data;
    }
  } catch (e) {}
  return tokenRegistryCache.data || { tokens: [] };
}

// ----- Geo/IP gating -----
app.use((req, res, next) => {
  try {
    const ip = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '')
      .toString()
      .split(',')[0]
      .trim();
    if (ip && DENY_IPS.includes(ip)) return res.status(451).json({ error: 'ip_blocked' });
    if (DENY_COUNTRIES.length > 0) {
      const country = (req.headers['cf-ipcountry'] || req.headers['x-country'] || '')
        .toString()
        .toUpperCase();
      if (country && DENY_COUNTRIES.includes(country)) return res.status(451).json({ error: 'geo_blocked' });
    }
  } catch {}
  next();
});

// ----- Optional App Auth (JWT or HMAC) -----
function verifyJwtToken(req) {
  const auth = req.get('authorization') || '';
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  try { return jwt.verify(m[1], JWT_SECRET); } catch { return null; }
}
function verifyHmacSignature(req) {
  try {
    const ts = req.get('x-timestamp');
    const sig = req.get('x-signature');
    if (!ts || !sig) return false;
    const skew = Math.abs((Date.now() - Number(ts)) / 1000);
    if (!Number.isFinite(skew) || skew > 300) return false; // 5 minutes
    const base = `${req.rawBody || ''}.${ts}`;
    const expected = crypto.createHmac('sha256', HMAC_SECRET).update(base).digest('hex');
    return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(sig));
  } catch { return false; }
}
function appAuth(requiredForWriteOnly = true) {
  return (req, res, next) => {
    if (!JWT_SECRET && !HMAC_SECRET) return next();
    if (requiredForWriteOnly && req.method === 'GET') return next();
    let ok = false;
    if (JWT_SECRET) ok = !!verifyJwtToken(req);
    if (!ok && HMAC_SECRET) ok = verifyHmacSignature(req);
    if (ok) return next();
    return res.status(401).json({ error: 'unauthorized' });
  };
}

// ----- Admin auth -----
const adminAuth = (BASIC_AUTH_USER && BASIC_AUTH_PASS)
  ? basicAuth({ users: { [BASIC_AUTH_USER]: BASIC_AUTH_PASS }, challenge: true })
  : (req, res, next) => res.status(401).json({ error: 'admin_auth_not_configured' });

// ----- Routes -----
app.get('/healthz', (req, res) => {
  try {
    db.prepare('SELECT 1').get();
    return res.json({ ok: true, env: WERT_ENV, version: '0.1.0' });
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'db_unavailable' });
  }
});

// Prometheus metrics
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (e) {
    res.status(500).end();
  }
});

app.post('/api/wert/create-session', async (req, res) => {
  try {
    if (!WERT_CREATE_SESSION_URL) {
      return res.status(500).json({ error: 'server_misconfigured', message: 'Missing WERT_CREATE_SESSION_URL' });
    }
    if (!WERT_API_KEY) {
      return res.status(500).json({ error: 'server_misconfigured', message: 'Missing WERT_API_KEY' });
    }

    const {
      flow_type,
      wallet_address,
      currency,
      commodity,
      network,
      currency_amount,
      // anything else from client is passed through
    } = req.body || {};

    // Optional idempotency key from body or header
    const idempotencyKey = req.body?.idempotencyKey || req.get('x-idempotency-key') || null;

    // Minimal validation
    if (!wallet_address || typeof wallet_address !== 'string' || !wallet_address.startsWith('0x') || wallet_address.length !== 42) {
      return res.status(400).json({ error: 'invalid_wallet_address' });
    }
    if (!currency || !commodity || !network) {
      return res.status(400).json({ error: 'missing_required_fields' });
    }

    // If idempotency key provided, return existing session
    if (idempotencyKey) {
      const existing = db.prepare('SELECT session_id FROM wert_sessions WHERE idempotency_key = ?').get(idempotencyKey);
      if (existing?.session_id) {
        return res.json({ sessionId: existing.session_id });
      }
    }

    // Build payload to Wert. Start with client data and ensure partner_id present.
    const payload = { ...req.body };
    if (!payload.partner_id && WERT_PARTNER_ID) {
      payload.partner_id = WERT_PARTNER_ID;
    }

    // Auth header scheme
    const headers = { 'Content-Type': 'application/json', Accept: 'application/json' };
    if (WERT_AUTH_SCHEME === 'bearer') {
      headers['Authorization'] = `Bearer ${WERT_API_KEY}`;
    } else if (WERT_AUTH_SCHEME === 'x-api-key') {
      headers['X-API-KEY'] = WERT_API_KEY;
    } else {
      headers['Authorization'] = `Bearer ${WERT_API_KEY}`; // default
    }

    // Call Wert Partner API
    const wertResp = await axios.post(WERT_CREATE_SESSION_URL, payload, {
      headers,
      timeout: 15000,
      validateStatus: () => true,
    });

    if (wertResp.status < 200 || wertResp.status >= 300) {
      return res.status(502).json({ error: 'wert_upstream_error', status: wertResp.status, body: wertResp.data });
    }

    const data = wertResp.data || {};
    const sessionId = data.sessionId || data.session_id || data.id; // try common keys
    if (!sessionId) {
      return res.status(502).json({ error: 'invalid_wert_response', data });
    }

    // Persist session
    const stmt = db.prepare(`
      INSERT OR IGNORE INTO wert_sessions (session_id, wallet_address, env, commodity, currency, currency_amount, network, status, meta, idempotency_key, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'created', ?, ?, ?, ?)
    `);
    const meta = JSON.stringify({ flow_type });
    const ts = nowMs();
    stmt.run(sessionId, wallet_address, WERT_ENV, commodity, currency, currency_amount ?? null, network, meta, idempotencyKey, ts, ts);

    return res.json({ sessionId });
  } catch (e) {
    console.error('create-session error', e);
    return res.status(500).json({ error: 'internal_error' });
  }
});

// List Wert sessions by wallet
app.get('/api/wert/sessions', (req, res) => {
  try {
    const wallet = req.query.wallet;
    if (!wallet || typeof wallet !== 'string' || !wallet.startsWith('0x') || wallet.length !== 42) {
      return res.status(400).json({ error: 'invalid_wallet_address' });
    }
    // pagination: limit (1..100), cursor (created_at ms, return < cursor)
    let limit = parseInt(String(req.query.limit || '50'), 10);
    if (!Number.isFinite(limit)) limit = 50;
    limit = Math.max(1, Math.min(100, limit));
    const cursor = req.query.cursor ? parseInt(String(req.query.cursor), 10) : null;

    let stmt, params;
    if (cursor && Number.isFinite(cursor)) {
      stmt = db.prepare(`
        SELECT session_id, env, commodity, currency, currency_amount, network, status, meta, created_at, updated_at
        FROM wert_sessions
        WHERE wallet_address = ? AND created_at < ?
        ORDER BY created_at DESC
        LIMIT ?
      `);
      params = [wallet, cursor, limit];
    } else {
      stmt = db.prepare(`
        SELECT session_id, env, commodity, currency, currency_amount, network, status, meta, created_at, updated_at
        FROM wert_sessions
        WHERE wallet_address = ?
        ORDER BY created_at DESC
        LIMIT ?
      `);
      params = [wallet, limit];
    }
    const rows = stmt.all(...params);
    const nextCursor = rows.length > 0 ? rows[rows.length - 1].created_at : null;
    return res.json({ sessions: rows, nextCursor });
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ---- Token allow/deny helpers ----
function isTokenAllowed(address) {
  if (!address) return true;
  const a = String(address).toLowerCase();
  if (DENY_TOKENS.length > 0 && DENY_TOKENS.includes(a)) return false;
  if (ALLOW_TOKENS.length > 0 && !ALLOW_TOKENS.includes(a)) return false;
  return true;
}

// OneSignal push helper
async function sendPushToExternalUser(externalUserId, title, message) {
  if (!ONESIGNAL_APP_ID || !ONESIGNAL_API_KEY) return false;
  try {
    const url = 'https://api.onesignal.com/notifications';
    const payload = {
      app_id: ONESIGNAL_APP_ID,
      include_aliases: { external_id: [String(externalUserId)] },
      headings: { en: String(title) },
      contents: { en: String(message) },
    };
    const resp = await axios.post(url, payload, {
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': `Basic ${ONESIGNAL_API_KEY}`,
      },
      timeout: 10000,
      validateStatus: () => true,
    });
    return resp.status >= 200 && resp.status < 300;
  } catch (e) {
    return false;
  }
}

function getRandomPrivateRpcUrl() {
  if (!Array.isArray(PRIVATE_RPC_URLS) || PRIVATE_RPC_URLS.length === 0) return null;
  const i = Math.floor(Math.random() * PRIVATE_RPC_URLS.length);
  return PRIVATE_RPC_URLS[i];
}

// Get Wert session details (with latest webhooks)
app.get('/api/wert/sessions/:sessionId', (req, res) => {
  try {
    const sessionId = req.params.sessionId;
    if (!sessionId || typeof sessionId !== 'string') {
      return res.status(400).json({ error: 'invalid_session_id' });
    }
    const row = db.prepare(`
      SELECT session_id, env, commodity, currency, currency_amount, network, status, meta, created_at, updated_at, wallet_address
      FROM wert_sessions WHERE session_id = ?
    `).get(sessionId);
    if (!row) return res.status(404).json({ error: 'not_found' });
    const hooks = db.prepare(`
      SELECT event_type, payload, created_at
      FROM wert_webhooks WHERE session_id = ?
      ORDER BY created_at DESC
      LIMIT 20
    `).all(sessionId);
    return res.json({ session: row, webhooks: hooks });
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

// Wert webhook receiver
app.post('/api/wert/webhook', async (req, res) => {
  try {
    if (WERT_WEBHOOK_SECRET) {
      const sig = req.get('x-signature') || req.get('x-wert-signature') || '';
      const expected = crypto.createHmac('sha256', WERT_WEBHOOK_SECRET).update(req.rawBody || '').digest('hex');
      if (!sig || !crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(sig))) {
        return res.status(401).json({ error: 'invalid_signature' });
      }
    }
    const body = req.body || {};
    const sessionId = body.sessionId || body.session_id || body.session?.id || null;
    const eventType = body.type || body.event || 'unknown';
    const status = body.status || body.session?.status || null;

    const insertWh = db.prepare(`
      INSERT INTO wert_webhooks (session_id, event_type, payload, created_at)
      VALUES (?, ?, ?, ?)
    `);
    insertWh.run(sessionId, eventType, JSON.stringify(body), nowMs());

    if (sessionId && status) {
      db.prepare(`UPDATE wert_sessions SET status = ?, updated_at = ? WHERE session_id = ?`).run(status, nowMs(), sessionId);
      if (status.toLowerCase() === 'success' || status.toLowerCase() === 'completed') {
        try {
          const row = db.prepare(`SELECT wallet_address FROM wert_sessions WHERE session_id = ?`).get(sessionId);
          if (row?.wallet_address) {
            const dev = db.prepare(`SELECT external_user_id FROM devices WHERE wallet_address = ? ORDER BY id DESC LIMIT 1`).get(row.wallet_address);
            if (dev?.external_user_id) {
              await sendPushToExternalUser(dev.external_user_id, 'Nạp thành công', `Session ${sessionId} hoàn tất`);
            }
          }
        } catch {}
      }
    }

    return res.json({ ok: true });
  } catch (e) {
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ---- 1inch proxy (GET) ----
app.get('/api/oneinch/*', async (req, res) => {
  try {
    if (!ONEINCH_API_KEY) {
      return res.status(500).json({ error: 'server_misconfigured', message: 'Missing ONEINCH_API_KEY' });
    }
    const pathSuffix = req.path.replace(/^\/api\/oneinch/, '');
    const upstreamUrl = `${ONEINCH_UPSTREAM_BASE}${pathSuffix}`;
    const cacheKey = makeCacheKey(ONEINCH_UPSTREAM_BASE, pathSuffix, req.query);
    const cached = cacheGet(cacheKey);
    if (cached) {
      res.status(200);
      return res.send(cached);
    }
    // Basic token gating for swap endpoints if params present
    const fromAddr = (req.query.fromTokenAddress || req.query.src || '').toString();
    const toAddr = (req.query.toTokenAddress || req.query.dst || '').toString();
    if ((fromAddr && !isTokenAllowed(fromAddr)) || (toAddr && !isTokenAllowed(toAddr))) {
      return res.status(400).json({ error: 'token_not_allowed' });
    }
    const upstream = await axios.get(upstreamUrl, {
      headers: { 'Authorization': `Bearer ${ONEINCH_API_KEY}`, 'Accept': 'application/json' },
      params: req.query,
      timeout: 15000,
      validateStatus: () => true,
    });
    res.status(upstream.status);
    if (upstream.status >= 200 && upstream.status < 300) {
      cacheSet(cacheKey, upstream.data);
    }
    return res.send(upstream.data);
  } catch (e) {
    console.error('oneinch proxy error', e);
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ---- Moralis proxy (GET) ----
app.get('/api/moralis/*', async (req, res) => {
  try {
    if (!MORALIS_API_KEY) {
      return res.status(500).json({ error: 'server_misconfigured', message: 'Missing MORALIS_API_KEY' });
    }
    const pathSuffix = req.path.replace(/^\/api\/moralis/, '');
    const upstreamUrl = `${MORALIS_UPSTREAM_BASE}${pathSuffix}`;
    const cacheKey = makeCacheKey(MORALIS_UPSTREAM_BASE, pathSuffix, req.query);
    const cached = cacheGet(cacheKey);
    if (cached) {
      res.status(200);
      return res.send(cached);
    }
    const upstream = await axios.get(upstreamUrl, {
      headers: { 'X-API-Key': MORALIS_API_KEY, 'Accept': 'application/json' },
      params: req.query,
      timeout: 15000,
      validateStatus: () => true,
    });
    res.status(upstream.status);
    if (upstream.status >= 200 && upstream.status < 300) {
      cacheSet(cacheKey, upstream.data, 20_000); // slightly shorter
    }
    return res.send(upstream.data);
  } catch (e) {
    console.error('moralis proxy error', e);
    return res.status(500).json({ error: 'internal_error' });
  }
});

// ----- Start -----
app.listen(PORT, () => {
  console.log(`[server] listening on :${PORT}`);
});
