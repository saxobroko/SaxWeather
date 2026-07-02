/**
 * SaxWeather share-link Worker — stateless HTML + Open Graph previews.
 * FREE tier only: no KV, D1, R2, or Queues.
 */

const APP_SCHEME = "saxweather";
const APP_HOST = "weather";
const SITE_ORIGIN = "https://weather.saxobroko.com";

/** @param {Request} request */
export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const path = url.pathname.replace(/\/+$/, "") || "/";

    if (path === "/apple-app-site-association" || path === "/.well-known/apple-app-site-association") {
      return appleAppSiteAssociation();
    }

    if (path === "/share") {
      return sharePage(url, request);
    }

    if (path === "/") {
      return landingPage();
    }

    return new Response("Not Found", { status: 404 });
  },
};

function appleAppSiteAssociation() {
  const body = JSON.stringify({
    applinks: {
      apps: [],
      details: [
        {
          appID: "F2AHYWP9BX.com.saxobroko.SaxWeather",
          paths: ["/share", "/share/*"],
        },
      ],
    },
  });

  return new Response(body, {
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=3600",
    },
  });
}

/** @param {URL} url @param {Request} request */
function sharePage(url, request) {
  const params = parseShareParams(url.searchParams);

  if (!params) {
    return htmlResponse(
      errorPage("Missing coordinates", "Share links need latitude and longitude."),
      400
    );
  }

  const deepLink = buildDeepLink(params);
  const pageUrl = buildCanonicalShareURL(params);
  const ogTitle = buildOGTitle(params);
  const ogDescription = buildOGDescription(params);
  const isIOS = isIOSUserAgent(request.headers.get("User-Agent") ?? "");

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>${escapeHtml(ogTitle)}</title>
  <meta name="description" content="${escapeAttr(ogDescription)}">

  <meta property="og:type" content="website">
  <meta property="og:site_name" content="SaxWeather">
  <meta property="og:title" content="${escapeAttr(ogTitle)}">
  <meta property="og:description" content="${escapeAttr(ogDescription)}">
  <meta property="og:url" content="${escapeAttr(pageUrl)}">

  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="${escapeAttr(ogTitle)}">
  <meta name="twitter:description" content="${escapeAttr(ogDescription)}">

  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="theme-color" content="#0b1220">

  <style>
    :root {
      color-scheme: dark;
      --bg: #0b1220;
      --card: rgba(255, 255, 255, 0.06);
      --border: rgba(255, 255, 255, 0.12);
      --text: #f4f7fb;
      --muted: rgba(244, 247, 251, 0.72);
      --accent: #4da3ff;
      --accent-pressed: #2f8ef0;
      --glow: rgba(77, 163, 255, 0.22);
    }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      min-height: 100%;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
      background:
        radial-gradient(1200px 600px at 50% -10%, rgba(77, 163, 255, 0.18), transparent 60%),
        linear-gradient(180deg, #0d1528 0%, var(--bg) 55%, #070b14 100%);
      color: var(--text);
    }
    .wrap {
      min-height: 100dvh;
      display: grid;
      place-items: center;
      padding: 24px 16px 32px;
    }
    .card {
      width: min(420px, 100%);
      border: 1px solid var(--border);
      background: var(--card);
      backdrop-filter: blur(18px);
      -webkit-backdrop-filter: blur(18px);
      border-radius: 24px;
      padding: 28px 24px 22px;
      box-shadow: 0 24px 80px rgba(0, 0, 0, 0.35), inset 0 1px 0 rgba(255, 255, 255, 0.06);
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 18px;
      color: var(--muted);
      font-size: 13px;
      letter-spacing: 0.02em;
      text-transform: uppercase;
    }
    .brand-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: linear-gradient(135deg, #7cc4ff, #4da3ff);
      box-shadow: 0 0 18px var(--glow);
    }
    .location {
      font-size: 15px;
      color: var(--muted);
      margin: 0 0 6px;
    }
    .temp-row {
      display: flex;
      align-items: baseline;
      gap: 12px;
      flex-wrap: wrap;
      margin-bottom: 8px;
    }
    .temp {
      font-size: clamp(48px, 12vw, 64px);
      line-height: 1;
      font-weight: 700;
      letter-spacing: -0.03em;
    }
    .condition {
      font-size: 20px;
      font-weight: 600;
      color: var(--text);
      margin: 0 0 14px;
    }
    .meta {
      display: grid;
      gap: 8px;
      margin: 0 0 22px;
      color: var(--muted);
      font-size: 15px;
      line-height: 1.45;
    }
    .meta strong { color: var(--text); font-weight: 600; }
    .cta {
      display: block;
      width: 100%;
      text-align: center;
      text-decoration: none;
      color: #fff;
      background: linear-gradient(180deg, var(--accent), var(--accent-pressed));
      border: 0;
      border-radius: 14px;
      padding: 14px 18px;
      font-size: 17px;
      font-weight: 600;
      box-shadow: 0 10px 30px var(--glow);
      transition: transform 0.15s ease, box-shadow 0.15s ease;
    }
    .cta:active { transform: scale(0.98); }
    .footnote {
      margin-top: 14px;
      text-align: center;
      font-size: 12px;
      color: rgba(244, 247, 251, 0.45);
    }
    .error h1 {
      margin: 0 0 8px;
      font-size: 22px;
    }
    .error p {
      margin: 0;
      color: var(--muted);
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <main class="wrap">
    <article class="card">
      <div class="brand"><span class="brand-dot" aria-hidden="true"></span> SaxWeather</div>
      <p class="location">${escapeHtml(params.name || "Shared location")}</p>
      <div class="temp-row">
        <div class="temp">${escapeHtml(formatTemperature(params))}</div>
      </div>
      ${params.condition ? `<p class="condition">${escapeHtml(params.condition)}</p>` : ""}
      <div class="meta">
        ${params.feels != null ? `<div>Feels like <strong>${escapeHtml(formatFeels(params))}</strong></div>` : ""}
        ${params.high != null && params.low != null ? `<div>Today <strong>${escapeHtml(formatHighLow(params))}</strong></div>` : ""}
        ${params.station ? `<div>Station <strong>${escapeHtml(params.station)}</strong></div>` : ""}
      </div>
      <a class="cta" id="open-app" href="${escapeAttr(deepLink)}">Open in SaxWeather</a>
      <p class="footnote">Tap the button to view live weather in the app.</p>
    </article>
  </main>
  <script>
    (function () {
      var deepLink = ${JSON.stringify(deepLink)};
      var isIOS = ${JSON.stringify(isIOS)};
      var openBtn = document.getElementById("open-app");

      if (openBtn) {
        openBtn.addEventListener("click", function (event) {
          if (!isIOS) return;
          event.preventDefault();
          window.location.href = deepLink;
        });
      }
    })();
  </script>
</body>
</html>`;

  return htmlResponse(html);
}

function landingPage() {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SaxWeather Share Links</title>
  <meta name="description" content="Rich weather share previews for SaxWeather.">
  <style>
    body {
      margin: 0;
      min-height: 100dvh;
      display: grid;
      place-items: center;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
      background: #0b1220;
      color: #f4f7fb;
      padding: 24px;
    }
    .box {
      max-width: 520px;
      border: 1px solid rgba(255,255,255,0.12);
      border-radius: 20px;
      padding: 28px;
      background: rgba(255,255,255,0.05);
    }
    h1 { margin: 0 0 10px; font-size: 28px; }
    p { margin: 0; line-height: 1.6; color: rgba(244,247,251,0.75); }
    code {
      display: inline-block;
      margin-top: 14px;
      padding: 8px 10px;
      border-radius: 8px;
      background: rgba(0,0,0,0.25);
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="box">
    <h1>SaxWeather</h1>
    <p>Share links open a weather preview page with Open Graph metadata for Messages and other apps.</p>
    <code>GET /share?lat=…&amp;lon=…</code>
  </div>
</body>
</html>`;

  return htmlResponse(html);
}

/** @param {string} title @param {string} message */
function errorPage(title, message) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(title)}</title>
</head>
<body style="margin:0;min-height:100dvh;display:grid;place-items:center;background:#0b1220;color:#f4f7fb;font-family:-apple-system,sans-serif;padding:24px;">
  <div class="error" style="max-width:420px;text-align:center;">
    <h1>${escapeHtml(title)}</h1>
    <p>${escapeHtml(message)}</p>
  </div>
</body>
</html>`;
}

/** @param {URLSearchParams} searchParams */
function parseShareParams(searchParams) {
  const lat = parseFloat(searchParams.get("lat") ?? "");
  const lon = parseFloat(searchParams.get("lon") ?? "");

  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return null;
  }

  const temp = parseOptionalFloat(searchParams.get("temp"));
  const feels = parseOptionalFloat(searchParams.get("feels"));
  const high = parseOptionalFloat(searchParams.get("high"));
  const low = parseOptionalFloat(searchParams.get("low"));

  return {
    lat,
    lon,
    name: trimOrNull(searchParams.get("name")),
    temp,
    unit: trimOrNull(searchParams.get("unit")) ?? "C",
    condition: trimOrNull(searchParams.get("condition")),
    feels,
    high,
    low,
    station: trimOrNull(searchParams.get("station")),
  };
}

/** @param {string | null} value */
function parseOptionalFloat(value) {
  if (value == null || value === "") return null;
  const parsed = parseFloat(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/** @param {string | null} value */
function trimOrNull(value) {
  if (value == null) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/** @param {ReturnType<typeof parseShareParams>} params */
function buildDeepLink(params) {
  const query = new URLSearchParams();
  query.set("lat", params.lat.toFixed(6));
  query.set("lon", params.lon.toFixed(6));
  if (params.name) query.set("name", params.name);
  if (params.station) query.set("station", params.station);
  return `${APP_SCHEME}://${APP_HOST}?${query.toString()}`;
}

/** @param {ReturnType<typeof parseShareParams>} params */
function buildCanonicalShareURL(params) {
  const query = new URLSearchParams();
  query.set("lat", params.lat.toFixed(6));
  query.set("lon", params.lon.toFixed(6));
  if (params.name) query.set("name", params.name);
  if (params.temp != null) query.set("temp", String(params.temp));
  if (params.unit) query.set("unit", params.unit);
  if (params.condition) query.set("condition", params.condition);
  if (params.feels != null) query.set("feels", String(params.feels));
  if (params.high != null) query.set("high", String(params.high));
  if (params.low != null) query.set("low", String(params.low));
  if (params.station) query.set("station", params.station);
  return `${SITE_ORIGIN}/share?${query.toString()}`;
}

/** @param {ReturnType<typeof parseShareParams>} params */
function buildOGTitle(params) {
  const location = params.name || "Shared location";
  if (params.temp != null) {
    return `${formatTemperature(params)} in ${location}`;
  }
  return `Weather in ${location}`;
}

/** @param {ReturnType<typeof parseShareParams>} params */
function buildOGDescription(params) {
  const parts = [];
  if (params.condition) parts.push(params.condition);
  if (params.feels != null) {
    parts.push(`Feels like ${formatFeels(params)}`);
  }
  if (params.high != null && params.low != null) {
    parts.push(`H ${formatTempValue(params.high, params.unit)} · L ${formatTempValue(params.low, params.unit)}`);
  }
  if (parts.length === 0) {
    return "Open this location in SaxWeather.";
  }
  return parts.join(" · ");
}

/** @param {ReturnType<typeof parseShareParams>} params */
function formatTemperature(params) {
  if (params.temp == null) return "—";
  return formatTempValue(params.temp, params.unit);
}

/** @param {ReturnType<typeof parseShareParams>} params */
function formatFeels(params) {
  if (params.feels == null) return "—";
  return formatTempValue(params.feels, params.unit);
}

/** @param {ReturnType<typeof parseShareParams>} params */
function formatHighLow(params) {
  return `H ${formatTempValue(params.high, params.unit)} · L ${formatTempValue(params.low, params.unit)}`;
}

/** @param {number} value @param {string} unit */
function formatTempValue(value, unit) {
  const rounded = Math.round(value);
  const symbol = unitSymbol(unit);
  return `${rounded}${symbol}`;
}

/** @param {string} unit */
function unitSymbol(unit) {
  const normalized = unit.toUpperCase();
  if (normalized === "F" || normalized === "FAHRENHEIT") return "°F";
  return "°C";
}

/** @param {string} ua */
function isIOSUserAgent(ua) {
  return /iPhone|iPad|iPod/i.test(ua);
}

/** @param {string} html @param {number} [status] */
function htmlResponse(html, status = 200) {
  return new Response(html, {
    status,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
}

/** @param {string} value */
function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** @param {string} value */
function escapeAttr(value) {
  return escapeHtml(value);
}
