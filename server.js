// ─────────────────────────────────────────────────────────────
//  Volaris X — Alert Server
//  Receives HTTP POST from MT5 EA → Firebase push notifications
// ─────────────────────────────────────────────────────────────
const express = require('express');
const path    = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getMessaging }        = require('firebase-admin/messaging');

// ── Firebase init
initializeApp({
  credential: cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT))
});

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ── In-memory stores
const fcmTokens   = new Map(); // token → { platform, preferences }
const activeSignals = new Map(); // "SYMBOL_TF" → signal object

// ── Keep-alive ping
app.get('/ping', (_req, res) => res.send('ok'));

// ── Active signals for frontend
app.get('/active-signals', (_req, res) => {
  res.json({ signals: Array.from(activeSignals.values()) });
});

// ── Subscribe — stores FCM token + user's per-symbol preferences
app.post('/subscribe', (req, res) => {
  const { token, platform, preferences } = req.body;
  if (!token) return res.status(400).json({ error: 'missing token' });

  fcmTokens.set(token, {
    platform:    platform    || 'android',
    preferences: preferences || {} // { "VOL75": true, "VOL10": false, ... }
  });

  console.log(`[fcm] +1 device (total: ${fcmTokens.size})`);
  res.json({ ok: true });
});

// ── Update preferences only (called when user toggles a symbol in the app)
app.post('/preferences', (req, res) => {
  const { token, preferences } = req.body;
  if (!token || !preferences) return res.status(400).json({ error: 'missing fields' });

  const existing = fcmTokens.get(token);
  if (existing) {
    existing.preferences = preferences;
    fcmTokens.set(token, existing);
    console.log(`[prefs] updated for token ...${token.slice(-6)}`);
  }
  res.json({ ok: true });
});

// ── Push to all devices that have this symbol enabled
async function pushToAll(symbol, payloadStr) {
  let payload;
  try { payload = JSON.parse(payloadStr); } catch { payload = {}; }

  const deadTokens = [];

  for (const [token, data] of fcmTokens) {
    // Check if this user has this symbol enabled (default: enabled if not set)
    const prefs     = data.preferences || {};
    const isEnabled = prefs[symbol] !== false; // default true
    if (!isEnabled) continue;

    try {
      await getMessaging().send({
        token,
        notification: {
          title: payload.title || 'Volaris X Signal',
          body:  payload.body  || ''
        },
        data: {
          symbol:    String(payload.symbol    || ''),
          level:     String(payload.level     || ''),
          timeframe: String(payload.timeframe || ''),
          timestamp: String(payload.timestamp || '')
        },
        android: {
          priority: 'high',
          notification: { channelId: 'volarix_signals', priority: 'high' }
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: { aps: { sound: 'alert_tone.caf', 'content-available': 1 } }
        }
      });
    } catch (err) {
      if (
        err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token'
      ) {
        deadTokens.push(token);
      } else {
        console.error('[fcm error]', err.message);
      }
    }
  }

  deadTokens.forEach(t => fcmTokens.delete(t));
  if (deadTokens.length) console.log(`[fcm] removed ${deadTokens.length} stale tokens`);
}

// ── Main EA endpoint
app.post('/', async (req, res) => {
  res.json({ ok: true });

  const data = req.body;
  if (!data || !data.type) return;

  if (data.type === 'heartbeat') {
    console.log(`[heartbeat] ${data.active_signals || 0} active signals`);
    return;
  }

  if (data.type === 'signal') {
    const sym  = data.symbol     || '';
    const tf   = data.timeframe  || '';
    const dir  = (data.trade_type || '').toUpperCase();
    const key  = `${sym}_${tf}`;

    const emoji = dir === 'BUY' ? '🟢' : '🔴';
    const title = `${emoji} ${dir} — ${sym}`;
    const body  = `${tf} signal detected`;
    const timestamp = Date.now();

    activeSignals.set(key, { title, body, level: dir, symbol: sym, timeframe: tf, timestamp });
    await pushToAll(sym, JSON.stringify({ title, body, level: dir, symbol: sym, timeframe: tf, timestamp }));
    console.log(`[signal] ${sym} ${tf} ${dir} (active: ${activeSignals.size})`);
  }

  if (data.type === 'remove_signal') {
    const sym = data.symbol    || '';
    const tf  = data.timeframe || '';
    const key = `${sym}_${tf}`;

    activeSignals.delete(key);
    console.log(`[removed] ${sym} ${tf} (active: ${activeSignals.size})`);
    // No push on removal — keeps it clean, only signals on new entries
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Volaris X alert server running on port ${PORT}`));
