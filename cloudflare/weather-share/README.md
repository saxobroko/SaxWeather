# SaxWeather Share Worker

Stateless Cloudflare Worker that serves HTTPS share links with Open Graph metadata so iMessage and other apps show rich weather previews. Tapping the link opens SaxWeather via Universal Links or the custom URL scheme.

**Cost: $0** — uses only Workers (no KV, D1, R2, Queues, or paid add-ons).

## Routes

| Route | Description |
|-------|-------------|
| `GET /share` | Weather preview page + Open Graph / Twitter Card meta |
| `GET /apple-app-site-association` | Universal Links JSON for iOS |
| `GET /.well-known/apple-app-site-association` | Same AASA file (Apple alternate path) |
| `GET /` | Simple landing page |

### Share query parameters

| Param | Required | Description |
|-------|----------|-------------|
| `lat` | yes | Latitude |
| `lon` | yes | Longitude |
| `name` | no | Location name |
| `temp` | no | Current temperature |
| `unit` | no | `C` or `F` (default `C`) |
| `condition` | no | Weather condition text |
| `feels` | no | Feels-like temperature |
| `high` | no | Today's high |
| `low` | no | Today's low |
| `station` | no | PWS station ID |

### Example

```
https://weather.saxobroko.com/share?lat=-33.868820&lon=151.209290&name=Sydney&temp=24&unit=C&condition=Partly%20Cloudy&feels=22&high=26&low=18
```

## Deploy

### Prerequisites

- [Cloudflare account](https://dash.cloudflare.com/sign-up) (free)
- `saxobroko.com` zone on Cloudflare
- [Node.js](https://nodejs.org/) 18+

### 1. Install dependencies

```bash
cd cloudflare/weather-share
npm install
```

### 2. Log in to Cloudflare

```bash
npx wrangler login
```

### 3. Deploy the Worker

```bash
npx wrangler deploy
```

### 4. Attach the custom domain route

In the [Cloudflare dashboard](https://dash.cloudflare.com/) → **Workers & Pages** → **weather-share** → **Settings** → **Triggers** → **Add route**:

- **Route:** `weather.saxobroko.com/*`
- **Zone:** `saxobroko.com`

Or uncomment the `routes` block in `wrangler.toml` and redeploy.

### 5. DNS (CNAME)

In **DNS** for `saxobroko.com`, add:

| Type | Name | Target | Proxy |
|------|------|--------|-------|
| CNAME | `weather` | `weather-share.<your-subdomain>.workers.dev` or route via Workers | Proxied (orange cloud) |

When using a Workers route on `weather.saxobroko.com/*`, Cloudflare routes traffic to the Worker automatically; the CNAME/AAAA record must exist and be proxied.

### 6. iOS Universal Links (app side)

1. In Apple Developer → App ID → enable **Associated Domains**
2. Add `applinks:weather.saxobroko.com` to `SaxWeather.entitlements`
3. Rebuild and install the app
4. Apple fetches `https://weather.saxobroko.com/apple-app-site-association` automatically

## Local development

```bash
npm run dev
# open http://localhost:8787/share?lat=-33.87&lon=151.21&name=Sydney&temp=24&unit=C&condition=Sunny
```

## Free tier limits

Cloudflare Workers free plan (as of 2025):

| Limit | Value |
|-------|-------|
| Requests | 100,000 / day |
| CPU time | 10 ms per request |
| Workers | 100 per account |

This Worker only generates HTML — no storage bindings — so it stays entirely on the free tier for typical personal-app share traffic.

## Files

```
cloudflare/weather-share/
├── package.json
├── wrangler.toml
├── README.md
└── src/
    └── index.js
```
