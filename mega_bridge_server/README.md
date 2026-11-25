# True Me — MEGA.nz Bridge Server

Secure, stateless-token Node.js bridge connecting the **True Me** Flutter app to each student's own **20 GB free MEGA.nz** account.

## Security & Resource Highlights
- **AES-256-GCM Credential Sealing:** User MEGA credentials are encrypted with AES-256-GCM inside the JWT payload (never stored as plaintext base64).
- **Bounded Session Cache:** Active `megajs` storage instances are capped at 100 entries with a 20-minute idle timeout to fit comfortably inside free-tier RAM (512 MB).
- **Rate Limiting & Helmet:** Built-in protection against brute-force login attempts.

## Free Deployment (Render.com — Recommended Always-Free)
1. Push this repository to GitHub (or connect `asmon31148-spec/TRUE-ME-`).
2. On [render.com](https://render.com), click **New → Web Service**.
3. Set **Root Directory** to `mega_bridge_server`.
4. **Build Command:** `npm install`
5. **Start Command:** `npm start`
6. Add Environment Variable:
   - `JWT_SECRET` = any long random 50+ character string
7. Click **Create Web Service**.
8. Copy your live URL (e.g. `https://trueme-mega-bridge.onrender.com`) and:
   - Paste it inside True Me's **MEGA Vault → Bridge Server URL**, **or**
   - Add it as `MEGA_BRIDGE_URL` in GitHub Repository Secrets so future APKs include it automatically.

## Alternative: Railway.app
```bash
cd mega_bridge_server
railway init
railway variables set JWT_SECRET="$(openssl rand -hex 32)"
railway up
```
