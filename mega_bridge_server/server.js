const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const { Readable } = require('stream');
const { Storage } = require('megajs');

const app = express();
const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex');

if (!process.env.JWT_SECRET) {
  console.warn('[WARN] JWT_SECRET env var not set; using ephemeral secret (tokens reset on restart).');
}

// Derive a fixed 32-byte AES-256 key from JWT_SECRET for credential sealing
const AES_KEY = crypto.createHash('sha256').update(JWT_SECRET).digest();

function encryptCredentials(payloadObj) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', AES_KEY, iv);
  const plaintext = JSON.stringify(payloadObj);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('base64')}.${tag.toString('base64')}.${encrypted.toString('base64')}`;
}

function decryptCredentials(sealed) {
  const parts = String(sealed || '').split('.');
  if (parts.length !== 3) throw new Error('Malformed credential envelope');
  const [ivB64, tagB64, dataB64] = parts;
  const decipher = crypto.createDecipheriv('aes-256-gcm', AES_KEY, Buffer.from(ivB64, 'base64'));
  decipher.setAuthTag(Buffer.from(tagB64, 'base64'));
  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(dataB64, 'base64')),
    decipher.final(),
  ]);
  return JSON.parse(decrypted.toString('utf8'));
}

// Middleware
app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '1mb' }));

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 25,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts. Please wait a few minutes.' },
});

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 100 * 1024 * 1024 }, // 100 MB per study file
});

// Bounded MEGA session cache (prevents RAM bloat on free hosting)
const MAX_SESSIONS = 100;
const SESSION_TTL_MS = 20 * 60 * 1000;
const megaSessions = new Map(); // sessionKey -> { storage, lastUsed }

function closeStorageSafely(entry) {
  try {
    if (entry && entry.storage && typeof entry.storage.close === 'function') {
      entry.storage.close();
    }
  } catch (_) {}
}

setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of megaSessions.entries()) {
    if (now - entry.lastUsed > SESSION_TTL_MS) {
      closeStorageSafely(entry);
      megaSessions.delete(key);
    }
  }
}, 5 * 60 * 1000).unref();

async function getMegaStorage(email, password) {
  const key = crypto.createHash('sha256').update(`${email}:${password}`).digest('hex');
  const existing = megaSessions.get(key);
  if (existing) {
    existing.lastUsed = Date.now();
    return existing.storage;
  }

  if (megaSessions.size >= MAX_SESSIONS) {
    // Evict oldest session
    let oldestKey = null;
    let oldestTime = Infinity;
    for (const [k, v] of megaSessions.entries()) {
      if (v.lastUsed < oldestTime) {
        oldestTime = v.lastUsed;
        oldestKey = k;
      }
    }
    if (oldestKey) {
      closeStorageSafely(megaSessions.get(oldestKey));
      megaSessions.delete(oldestKey);
    }
  }

  const storage = await new Storage({ email, password, autologin: true }).ready;
  megaSessions.set(key, { storage, lastUsed: Date.now() });
  return storage;
}

function getAccountInfo(storage) {
  return new Promise((resolve) => {
    if (typeof storage.getAccountInfo === 'function') {
      storage.getAccountInfo((err, info) => {
        if (err || !info) return resolve({ used: 0, total: 21474836480 });
        resolve({
          used: Number(info.spaceUsed || 0),
          total: Number(info.spaceTotal || 21474836480),
        });
      });
    } else {
      resolve({ used: 0, total: 21474836480 });
    }
  });
}

function verifyToken(req, res, next) {
  const auth = req.headers.authorization || '';
  if (!auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization token' });
  }
  const token = auth.slice(7).trim();
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const creds = decryptCredentials(decoded.cred);
    req.megaCreds = creds;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Session expired or invalid. Please reconnect MEGA.' });
  }
}

async function ensureFolder(parentDir, folderName) {
  const clean = String(folderName || '').trim().replace(/[\\/:*?"<>|]/g, '_');
  if (!clean) return parentDir;
  const children = Array.isArray(parentDir.children) ? parentDir.children : [];
  const existing = children.find((c) => c.directory && c.name === clean);
  if (existing) return existing;
  return await parentDir.mkdir(clean);
}

async function resolveVaultFolder(storage, subject, section) {
  let folder = await ensureFolder(storage.root, 'True Me');
  if (subject && String(subject).trim()) {
    folder = await ensureFolder(folder, subject);
  }
  if (section && String(section).trim()) {
    folder = await ensureFolder(folder, section);
  }
  return folder;
}

function collectFilesRecursively(dirNode, subjectHint = '', sectionHint = '', depth = 0) {
  const out = [];
  const children = Array.isArray(dirNode.children) ? dirNode.children : [];
  for (const child of children) {
    if (child.directory) {
      const nextSub = depth === 0 ? child.name : subjectHint;
      const nextSec = depth === 1 ? child.name : sectionHint;
      out.push(...collectFilesRecursively(child, nextSub, nextSec, depth + 1));
    } else {
      out.push({
        id: child.nodeId,
        name: child.name,
        size: child.size || 0,
        subject: subjectHint || 'General',
        folder: sectionHint || subjectHint || 'True Me',
        createdAt: child.timestamp ? new Date(child.timestamp * 1000).toISOString() : null,
      });
    }
  }
  return out;
}

// ─── ROUTES ──────────────────────────────────────────────────────────────────

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'trueme-mega-bridge', version: '1.0.0' });
});

app.post('/mega/login', loginLimiter, async (req, res) => {
  const email = String(req.body?.email || '').trim();
  const password = String(req.body?.password || '');

  if (!email || !password) {
    return res.status(400).json({ error: 'MEGA email and password are required.' });
  }

  let storage;
  try {
    storage = await getMegaStorage(email, password);
  } catch (err) {
    const msg = String(err?.message || err || 'Unknown error');
    console.error('MEGA login failed:', msg);

    if (/ENOENT|EACCESS|invalid.*password|bad.*password|incorrect/i.test(msg)) {
      return res.status(401).json({ error: 'Invalid MEGA email or password.' });
    }
    if (/2fa|mfa|second.?factor|EMFA/i.test(msg)) {
      return res.status(403).json({
        error:
          '2FA is enabled on this MEGA account. Disable 2FA in MEGA settings or use a MEGA account without 2FA.',
      });
    }
    if (/EBLOCKED|confirm|verify|suspended/i.test(msg)) {
      return res.status(403).json({
        error:
          'MEGA account is not verified yet or is temporarily blocked. Check your email inbox to verify MEGA first.',
      });
    }
    if (/EAGAIN|ETIMEDOUT|ECONNRESET|ENOTFOUND|network/i.test(msg)) {
      return res.status(503).json({
        error: 'MEGA servers are temporarily busy. Wait a few seconds and try again.',
      });
    }
    return res.status(400).json({ error: `MEGA login error: ${msg}` });
  }

  try {
    await ensureFolder(storage.root, 'True Me');
  } catch (folderErr) {
    console.warn('Could not pre-create True Me folder:', folderErr?.message);
  }

  try {
    const quota = await getAccountInfo(storage);
    const sealed = encryptCredentials({ email, password });
    const token = jwt.sign(
      { sub: email, cred: sealed },
      JWT_SECRET,
      { expiresIn: '60d' }
    );

    res.json({
      success: true,
      token,
      email,
      user: storage.name || email,
      storageUsed: quota.used,
      storageTotal: quota.total,
    });
  } catch (err) {
    console.error('MEGA post-login setup failed:', err?.message || err);
    res.status(500).json({ error: 'Logged into MEGA, but failed to initialize session.' });
  }
});

app.post('/mega/upload', verifyToken, upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded.' });
  }

  const { email, password } = req.megaCreds;
  const subject = req.body?.subject || '';
  const section = req.body?.section || req.body?.folder || '';
  const customName = (req.body?.customName || req.file.originalname || 'study_file').trim();

  try {
    const storage = await getMegaStorage(email, password);
    const targetFolder = await resolveVaultFolder(storage, subject, section);

    const readable = Readable.from(req.file.buffer);
    const uploadTask = targetFolder.upload(
      { name: customName, size: req.file.buffer.length },
      readable
    );
    const megaFile = await uploadTask.complete;

    res.json({
      success: true,
      fileId: megaFile.nodeId,
      fileName: megaFile.name,
      size: megaFile.size || req.file.buffer.length,
      folder: [subject, section].filter(Boolean).join('/') || 'True Me',
    });
  } catch (err) {
    console.error('MEGA upload error:', err.message);
    res.status(500).json({ error: `MEGA upload failed: ${err.message}` });
  }
});

app.get('/mega/files', verifyToken, async (req, res) => {
  const { email, password } = req.megaCreds;
  const filterSubject = String(req.query?.subject || '').trim().toLowerCase();

  try {
    const storage = await getMegaStorage(email, password);
    const vaultRoot = await ensureFolder(storage.root, 'True Me');
    let files = collectFilesRecursively(vaultRoot);

    if (filterSubject) {
      files = files.filter((f) => f.subject.toLowerCase() === filterSubject);
    }

    files.sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
    res.json({ success: true, files, count: files.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/mega/download/:fileId', verifyToken, async (req, res) => {
  const { email, password } = req.megaCreds;
  const { fileId } = req.params;

  try {
    const storage = await getMegaStorage(email, password);
    const file = storage.files[fileId];
    if (!file || file.directory) {
      return res.status(404).json({ error: 'File not found in MEGA vault.' });
    }

    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(file.name)}"`);
    if (file.size) res.setHeader('Content-Length', String(file.size));

    const stream = file.download();
    stream.on('error', (err) => {
      console.error('Download stream error:', err.message);
      if (!res.headersSent) res.status(500).json({ error: err.message });
      else res.end();
    });
    stream.pipe(res);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/mega/file/:fileId', verifyToken, async (req, res) => {
  const { email, password } = req.megaCreds;
  const { fileId } = req.params;

  try {
    const storage = await getMegaStorage(email, password);
    const file = storage.files[fileId];
    if (!file) return res.status(404).json({ error: 'File not found.' });
    await file.delete(true);
    res.json({ success: true, deleted: fileId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/mega/vault', verifyToken, async (req, res) => {
  const { email, password } = req.megaCreds;
  try {
    const storage = await getMegaStorage(email, password);
    const children = Array.isArray(storage.root.children) ? storage.root.children : [];
    const vault = children.find((c) => c.directory && c.name === 'True Me');
    if (vault) {
      await vault.delete(true);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/mega/stats', verifyToken, async (req, res) => {
  const { email, password } = req.megaCreds;
  try {
    const storage = await getMegaStorage(email, password);
    const quota = await getAccountInfo(storage);
    res.json({
      success: true,
      used: quota.used,
      total: quota.total,
      usedGB: (quota.used / 1073741824).toFixed(2),
      totalGB: (quota.total / 1073741824).toFixed(2),
      freeGB: (Math.max(0, quota.total - quota.used) / 1073741824).toFixed(2),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`True Me MEGA Bridge running on port ${PORT}`);
});
