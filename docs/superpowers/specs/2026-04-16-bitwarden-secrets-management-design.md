# Bitwarden Secrets Management — Design Spec

**Date:** 2026-04-16
**Scope:** Centralize all API keys, credentials, and secrets across all projects into Bitwarden with CLI-driven .env generation, direct management links, and cleanup of all plaintext files.

---

## Problem

30+ secrets scattered across plaintext files in OneDrive — CSV files, .env files, .txt files, .pem files, Word docs, JSON configs, and git-tracked repos. Keys get rotated and not updated everywhere. Duplicates drift. Progress files contain printed keys. No encryption anywhere. A compromised OneDrive account exposes live trading keys, production database access, and email credentials.

## Solution

Bitwarden free tier as single source of truth. CLI (`bw`) pulls secrets into .env files and configs via a refresh script. All plaintext files deleted. All git repos .gitignored. Every entry includes a direct URI to the service's key management page.

---

## Vault Folder Structure

```
Bitwarden Vault/
├── MTM - AllTec Pro/
│   ├── ERPNext - Admin API Key (christoph3reverding@gmail.com)
│   ├── ERPNext - Tech Key: Chris (wit@manytalentsmore.com)
│   ├── ERPNext - Tech Key: Glen (glen@manytalentsmore.com)
│   ├── ERPNext - Tech Key: Adam (adam@manytalentsmore.com)
│   ├── ERPNext - Tech Key: Warren (warren@manytalentsmore.com)
│   ├── ERPNext - Tech Key: Tim (tim@manytalentsmore.com)
│   ├── ERPNext - Tech Key: Matt (matt@manytalentsmore.com)
│   ├── ERPNext - Tech Key: Dereck (dereck@manytalentsmore.com)
│   ├── ERPNext - Tech Key: Taylor (taylor@manytalentsmore.com)
│   ├── HCP - API Key Full Access
│   ├── Google Vision - Service Account JSON (alltec-receipt-ocr)
│   ├── Gmail - ManyTalents Notifications SMTP
│   ├── Frappe Cloud - Login
│   └── Vercel - ManyTalentsMore Env Vars
│
├── Crypto Bot - LIVE/
│   ├── Coinbase - Trading API Key (LIVE)
│   ├── Coinbase - EC Private Key (LIVE)
│   ├── BTC Wallet Address
│   ├── Gmail - Bot Notifications (christoph3reverding)
│   └── X API - Client Credentials
│
├── VEOE Trading - LIVE/
│   ├── Tradier - Live API Key (6YB73149)
│   ├── Kraken - API Key + Private Key
│   └── Gmail - SMTP (wit@manytalentsmore.com)
│
├── VEOE Trading - Paper/
│   ├── Tradier - Paper API Key (VA90113942)
│   └── Polygon - API Key
│
├── Shared Services/
│   ├── Google Cloud - OAuth Client Secret (alltec-receipt-ocr)
│   ├── Google Drive - OAuth Token + Refresh Token
│   ├── Google Gemini - API Key
│   ├── Anthropic - API Key
│   ├── X AI - API Key
│   ├── Digital Ocean - Droplet Access (104.131.176.130)
│   └── Dashboard - VEOE/Crypto Token
│
├── ManyTalents App/
│   └── Android Keystore - manytalents.jks
│
└── Archive - Rotated/
    └── (old keys moved here with date suffix on rotation)
```

## Entry Format

Every entry is a Bitwarden **Secure Note** (not Login type) with:

| Field | Purpose | Example |
|-------|---------|---------|
| **Name** | `{Service} - {Purpose} ({Account})` | `ERPNext - Admin API Key (christoph3reverding)` |
| **URI 1** | Direct link to key management page | `https://manytalentsmore.v.frappe.cloud/app/user/christoph3reverding@gmail.com` |
| **Notes** | The actual secret value (key, JSON, PEM) | `3ac4c8f5530ec6b:e3de34d861e0cb3` |
| **Custom: `env_var_name`** | .env variable name | `ERPNEXT_API_KEY` |
| **Custom: `project`** | Which project consumes this | `hcp_replacement` |
| **Custom: `rotated_on`** | Last rotation date | `2026-04-16` |
| **Custom: `used_in`** | Files that read this secret | `.mcp.json, frappe.ts` |

For multi-line secrets (PEM keys, JSON service accounts): full content in Notes field.

## Direct Management URIs

Every entry links straight to where you rotate/manage that key:

| Service | Direct URL |
|---------|-----------|
| ERPNext User API Keys | `https://manytalentsmore.v.frappe.cloud/app/user/{email}` |
| ERPNext Email Account | `https://manytalentsmore.v.frappe.cloud/app/email-account/ManyTalents Notifications` |
| HCP Integrations | `https://pro.housecallpro.com/pro/settings/integrations` |
| Frappe Cloud Dashboard | `https://frappecloud.com/dashboard/sites/manytalentsmore.v.frappe.cloud` |
| Coinbase API Portal | `https://portal.cdp.coinbase.com/access/api` |
| Tradier API Settings | `https://dash.tradier.com/settings/api` |
| Google Cloud SA | `https://console.cloud.google.com/iam-admin/serviceaccounts?project=alltec-receipt-ocr` |
| Google App Passwords | `https://myaccount.google.com/apppasswords` |
| Vercel Env Vars | `https://vercel.com/manytalents/manytalents-more/settings/environment-variables` |
| Polygon.io Keys | `https://polygon.io/dashboard/keys` |
| Anthropic Console | `https://console.anthropic.com/settings/keys` |
| Google AI Studio | `https://aistudio.google.com/app/apikey` |

## CLI Workflow

### Install
```bash
winget install Bitwarden.CLI
# OR
npm install -g @bitwarden/cli
```

### Daily Usage
```bash
# Login (first time only)
bw login christoph3reverding@gmail.com

# Unlock vault (once per terminal session)
export BW_SESSION=$(bw unlock --raw)

# Pull a single secret
bw get notes "ERPNext - Admin API Key (christoph3reverding)"

# Use in a command
export ERPNEXT_API_KEY=$(bw get notes "ERPNext - Admin API Key (christoph3reverding)")
```

### Refresh Script: `secrets-refresh.sh`

Location: `C:/Users/chris/OneDrive/Documentos/PKA/.10T/tools/secrets-refresh.sh`

One script that rebuilds ALL .env files and config files from Bitwarden:

```bash
#!/bin/bash
set -euo pipefail

# Ensure vault is unlocked
if [ -z "${BW_SESSION:-}" ]; then
  echo "Vault locked. Run: export BW_SESSION=\$(bw unlock --raw)"
  exit 1
fi

bw sync  # Pull latest from server

echo "=== Refreshing secrets ==="

# ── Crypto Bot ──
CRYPTO="$HOME/crypto_bot"
cat > "$CRYPTO/.env" << EOF
MODE=live
COINBASE_API_KEY=$(bw get notes "Coinbase - Trading API Key (LIVE)")
COINBASE_API_SECRET=$(bw get notes "Coinbase - EC Private Key (LIVE)")
BTC_WALLET_ADDRESS=$(bw get notes "BTC Wallet Address")
EMAIL_USER=$(bw get notes "Gmail - Bot Notifications (christoph3reverding)" | head -1)
EMAIL_PASS=$(bw get notes "Gmail - Bot Notifications (christoph3reverding)" | tail -1)
X_CLIENT_ID=$(bw get notes "X API - Client Credentials" | sed -n '1p')
X_CLIENT_SECRET=$(bw get notes "X API - Client Credentials" | sed -n '2p')
EOF
echo "  [OK] crypto_bot/.env"

# ── VEOE Trading Bot ──
VEOE="$HOME/OneDrive/Documentos/clawdbottrade"
cat > "$VEOE/.env" << EOF
TRADIER_ENV=paper
TRADIER_PAPER_API_KEY=$(bw get notes "Tradier - Paper API Key (VA90113942)" | sed -n '1p')
TRADIER_PAPER_ACCOUNT_ID=$(bw get notes "Tradier - Paper API Key (VA90113942)" | sed -n '2p')
TRADIER_LIVE_API_KEY=$(bw get notes "Tradier - Live API Key (6YB73149)" | sed -n '1p')
TRADIER_LIVE_ACCOUNT_ID=$(bw get notes "Tradier - Live API Key (6YB73149)" | sed -n '2p')
POLYGON_API_KEY=$(bw get notes "Polygon - API Key")
GOOGLE_API_KEY=$(bw get notes "Google Gemini - API Key")
SMTP_EMAIL=wit@manytalentsmore.com
SMTP_PASSWORD=$(bw get notes "Gmail - SMTP (wit@manytalentsmore.com)")
DASHBOARD_TOKEN=$(bw get notes "Dashboard - VEOE/Crypto Token")
TZ=America/Chicago
EOF
echo "  [OK] clawdbottrade/.env"

# ── PKA MCP Config ──
MCP="$HOME/OneDrive/Documentos/PKA/.mcp.json"
API_KEY=$(bw get notes "ERPNext - Admin API Key (christoph3reverding)" | sed -n '1p')
API_SECRET=$(bw get notes "ERPNext - Admin API Key (christoph3reverding)" | sed -n '2p')
cat > "$MCP" << EOF
{
  "mcpServers": {
    "erpnext": {
      "command": "node",
      "args": ["$(echo $HOME)/OneDrive/Documentos/PKA/.10T/tools/erpnext-mcp-server/build/index.js"],
      "env": {
        "ERPNEXT_URL": "https://manytalentsmore.v.frappe.cloud",
        "ERPNEXT_API_KEY": "${API_KEY}",
        "ERPNEXT_API_SECRET": "${API_SECRET}"
      }
    }
  }
}
EOF
echo "  [OK] PKA/.mcp.json"

# ── Google Vision Service Account ──
GV_PATH="$HOME/OneDrive/Documentos/AllTecPro/alltec-receipt-ocr-dd99ac930a48.json"
bw get notes "Google Vision - Service Account JSON (alltec-receipt-ocr)" > "$GV_PATH"
echo "  [OK] Google Vision service account"

echo ""
echo "=== All secrets refreshed ==="
echo "Files written: crypto_bot/.env, clawdbottrade/.env, PKA/.mcp.json, Google Vision SA"
```

## Key Rotation Protocol

When any key is rotated:

1. **Click the URI** in the Bitwarden entry → goes to the service's key management page
2. **Generate new key** in the service
3. **Update Bitwarden entry** — paste new key into Notes, update `rotated_on` date
4. **Move old entry** to `Archive - Rotated/` folder (rename with date suffix: `ERPNext - Admin API Key (ROTATED 2026-04-16)`)
5. **Run `secrets-refresh.sh`** — all .env files and configs update in one command
6. **Restart affected services** (Frappe Cloud bench restart, crypto bot restart, etc.)

No more KEY_ROTATION.md. No more hunting through file paths. One Bitwarden entry, one refresh script, done.

## Cleanup — Files to Delete After Migration

### Plaintext Credential Files (DELETE)
- `AllTecPro/frappe_api_keys.csv`
- `AllTecPro/frappe_api_keys (1).csv`
- `AllTecPro/frappe_api_keys (2).csv`
- `AllTecPro/frappe_api_keys (2)(AutoRecovered).csv`
- `crypto trading/Traiding programs/ecdsa secret.txt`
- `crypto trading/Traiding programs/ecdsa API key ID.txt`
- `crypto trading/trading programs first attempt/api keys.txt`
- `crypto trading/msc/trade bot API key ID.txt`
- `crypto trading/msc/bot-key-2025.docx`
- `crypto trading/msc/bot2-key-2025.docx`
- `AI prompts/Ai files/private_namedcurve.pem`
- `clawdbottrade/secrets/anthropic_api.txt`

### Duplicate PEM Files (DELETE — keep value in Bitwarden only)
- `crypto trading/modual_versions/private_key.pem`
- `crypto trading/Traiding programs/private_key.pem`
- `crypto trading/trading programs first attempt/ec_private_key.pem`
- `crypto trading/trading programs first attempt/private_clean.pem`
- `crypto trading/trading programs first attempt/private_original.pem`

### Git History Cleanup
- `clawdbottrade/secrets/` — `git rm --cached -r secrets/` then add to .gitignore
- `clawdbottrade/.env` — `git rm --cached .env` then add to .gitignore

### Scrub from Progress Files
- Remove HCP API key printed in `progress.txt` line 308 and 348

### .gitignore Additions (all repos)
```
.env
.env.*
*.pem
*.key
*secret*
*credential*
secrets/
```

## What This Solves

| Problem | Before | After |
|---------|--------|-------|
| Key rotated, not updated everywhere | Manual hunt through 5+ files | `secrets-refresh.sh` |
| "Where do I rotate this key?" | Google it, dig through settings | Click URI in Bitwarden entry |
| Plaintext keys in OneDrive | 30+ discoverable files | Zero plaintext files |
| Keys in git repos | .env and secrets/ committed | .gitignore blocks, history cleaned |
| Duplicate keys | Coinbase key in 5 .pem files | One Bitwarden entry |
| "Where is the key for X?" | grep through file system | `bw get notes "X"` |
| Key expires, nobody knows when | No tracking | `rotated_on` field |
| New session, stale .env | Hope it's current | `secrets-refresh.sh` guarantees fresh |
