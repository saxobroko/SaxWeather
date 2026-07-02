# SaxWeather Share Worker

Stateless Cloudflare Worker that serves rich **HTTPS** share links for SaxWeather. iMessage and other apps fetch Open Graph metadata from these URLs instead of failing on custom `saxweather://` schemes.

**Cost:** $0 on Cloudflare Workers free tier (100,000 requests/day, no KV/D1/R2).

## What it does

| Route | Purpose |
|-------|---------|
| `GET /share?lat=&lon=&name=&temp=&unit=&condition=...` | Rich preview page + "Open in SaxWeather" deep link |
| `GET /apple-app-site-association` | Universal Links (optional) |
| `GET /assets/*` | Static Lottie animations and background images (served from `./public`) |
| `GET /` | Product landing page (`weather.saxobroko.com`) — hero, features, live accent theming, animated Lottie icons, and background gallery |

## Example URL

```
https://weather.saxobroko.com/share?lat=-33.868820&lon=151.209296&name=Sydney&temp=24.0&unit=°C&condition=Partly%20Cloudy&feels=22.0&high=26&low=18
```

## Deploy

### 1. Install dependencies

```bash
cd cloudflare/weather-share
npm install
```

### 2. Log in to Cloudflare

```bash
npx wrangler login
```

### 3. Set secrets / vars (optional, for Universal Links)

```bash
npx wrangler secret put APPLE_TEAM_ID
npx wrangler secret put IOS_BUNDLE_ID   # default: com.saxobroko.SaxWeather
```

Until `APPLE_TEAM_ID` is set, `apple-app-site-association` uses `REPLACE_WITH_TEAM_ID` — Universal Links will not work until you update this.

### 4. Deploy

```bash
npm run deploy
```

### 5. Attach custom domain

In the Cloudflare dashboard:

1. **Workers & Pages** → `weather-share` → **Settings** → **Domains & Routes**
2. Add route: `weather.saxobroko.com/*`
3. Ensure DNS has a proxied record for `weather.saxobroko.com` (CNAME to your worker or A/AAAA as appropriate)

Or uncomment the `routes` block in `wrangler.toml` once the zone is on your account.

## iOS app setup (Universal Links)

1. Enable **Associated Domains** capability in Xcode.
2. Add `applinks:weather.saxobroko.com` to `SaxWeather.entitlements`.
3. Deploy this worker with your real `APPLE_TEAM_ID`.
4. Verify AASA: `curl https://weather.saxobroko.com/apple-app-site-association`

Without Universal Links, users can still tap **Open in SaxWeather** on the share page (custom URL scheme).

## Free tier limits

- **Workers:** 100,000 requests/day
- **No** KV, D1, R2, Queues, or paid add-ons required
- HTML is generated at the edge per request (tiny CPU per hit)

Typical share-link traffic is well within free limits.

## Local dev

```bash
npm run dev
# open http://localhost:8787/share?lat=-33.87&lon=151.21&name=Sydney&temp=24&unit=°C&condition=Clear
```
