/**
 * SaxWeather share-link Worker — stateless, free-tier friendly.
 * Serves rich Open Graph previews for iMessage and redirects to the app.
 */

const APP_SCHEME = "saxweather";
const APP_HOST = "weather";
const SITE_ORIGIN = "https://weather.saxobroko.com";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === "/apple-app-site-association") {
      return aasaResponse(env);
    }

    if (url.pathname === "/.well-known/apple-app-site-association") {
      return aasaResponse(env);
    }

    if (url.pathname === "/share" || url.pathname.startsWith("/share/")) {
      return sharePage(url);
    }

    if (url.pathname === "/" || url.pathname === "") {
      return landingPage();
    }

    return new Response("Not found", { status: 404 });
  },
};

function aasaResponse(env) {
  const teamId = env.APPLE_TEAM_ID || "REPLACE_WITH_TEAM_ID";
  const bundleId = env.IOS_BUNDLE_ID || "com.saxobroko.SaxWeather";

  const body = JSON.stringify({
    applinks: {
      apps: [],
      details: [
        {
          appID: `${teamId}.${bundleId}`,
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

function parseShareParams(url) {
  const q = url.searchParams;
  const lat = parseFloat(q.get("lat") || "");
  const lon = parseFloat(q.get("lon") || "");

  if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
    return null;
  }

  return {
    lat,
    lon,
    name: sanitize(q.get("name") || "this location"),
    temp: q.get("temp"),
    unit: sanitize(formatUnit(q.get("unit") || "°C")),
    condition: sanitize(q.get("condition") || "Weather"),
    feels: q.get("feels"),
    high: q.get("high"),
    low: q.get("low"),
    station: q.get("station"),
  };
}

function sanitize(value) {
  return String(value)
    .replace(/[<>&"']/g, "")
    .slice(0, 120);
}

function formatUnit(raw) {
  const value = String(raw).toUpperCase();
  if (value === "C" || value === "CELSIUS") return "°C";
  if (value === "F" || value === "FAHRENHEIT") return "°F";
  return sanitize(raw);
}

function deepLink(params) {
  const items = [
    `lat=${encodeURIComponent(params.lat.toFixed(6))}`,
    `lon=${encodeURIComponent(params.lon.toFixed(6))}`,
    `name=${encodeURIComponent(params.name)}`,
  ];
  if (params.station) {
    items.push(`station=${encodeURIComponent(params.station)}`);
  }
  return `${APP_SCHEME}://${APP_HOST}?${items.join("&")}`;
}

function sharePage(url) {
  const params = parseShareParams(url);
  if (!params) {
    return new Response("Missing or invalid lat/lon query parameters.", {
      status: 400,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }

  const canonical = `${SITE_ORIGIN}/share?${url.searchParams.toString()}`;
  const appURL = deepLink(params);

  const tempLabel =
    params.temp != null && params.temp !== ""
      ? `${params.temp}${params.unit}`
      : null;

  const ogTitle = tempLabel
    ? `${tempLabel} in ${params.name}`
    : `Weather in ${params.name}`;

  const descParts = [params.condition];
  if (params.feels) descParts.push(`Feels like ${params.feels}${params.unit}`);
  if (params.high && params.low) {
    descParts.push(`H ${params.high}${params.unit} · L ${params.low}${params.unit}`);
  }
  const ogDescription = descParts.join(" · ");

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(ogTitle)} — SaxWeather</title>
  <meta name="description" content="${escapeHtml(ogDescription)}" />
  <link rel="canonical" href="${escapeHtml(canonical)}" />
  <meta property="og:type" content="website" />
  <meta property="og:site_name" content="SaxWeather" />
  <meta property="og:url" content="${escapeHtml(canonical)}" />
  <meta property="og:title" content="${escapeHtml(ogTitle)}" />
  <meta property="og:description" content="${escapeHtml(ogDescription)}" />
  <meta name="twitter:card" content="summary" />
  <meta name="twitter:title" content="${escapeHtml(ogTitle)}" />
  <meta name="twitter:description" content="${escapeHtml(ogDescription)}" />
  <style>
    :root {
      color-scheme: light dark;
      --bg: #0b1220;
      --card: rgba(255,255,255,0.08);
      --text: #f5f7fb;
      --muted: #9aa4b2;
      --accent: #5eb3ff;
      --accent-2: #7c5cff;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at top, rgba(94,179,255,0.18), transparent 45%),
        radial-gradient(circle at bottom right, rgba(124,92,255,0.16), transparent 40%),
        var(--bg);
      color: var(--text);
      display: grid;
      place-items: center;
      padding: 24px;
    }
    .card {
      width: min(420px, 100%);
      background: var(--card);
      border: 1px solid rgba(255,255,255,0.12);
      border-radius: 24px;
      padding: 28px;
      backdrop-filter: blur(16px);
      box-shadow: 0 24px 60px rgba(0,0,0,0.35);
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
      color: var(--muted);
      font-size: 13px;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      margin-bottom: 18px;
    }
    .location { font-size: 15px; color: var(--muted); margin-bottom: 8px; }
    .temp {
      font-size: 56px;
      font-weight: 700;
      line-height: 1;
      margin: 0 0 8px;
    }
    .condition { font-size: 22px; font-weight: 600; margin-bottom: 6px; }
    .meta { color: var(--muted); font-size: 15px; line-height: 1.5; }
    .station {
      margin-top: 14px;
      font-size: 13px;
      color: var(--muted);
    }
    .actions { margin-top: 28px; display: grid; gap: 12px; }
    .btn {
      display: inline-flex;
      justify-content: center;
      align-items: center;
      gap: 8px;
      padding: 14px 18px;
      border-radius: 14px;
      text-decoration: none;
      font-weight: 600;
      font-size: 16px;
    }
    .btn-primary {
      background: linear-gradient(135deg, var(--accent), var(--accent-2));
      color: white;
    }
    .btn-secondary {
      color: var(--muted);
      border: 1px solid rgba(255,255,255,0.12);
    }
    .footer {
      margin-top: 18px;
      font-size: 12px;
      color: var(--muted);
      text-align: center;
    }
  </style>
</head>
<body>
  <main class="card">
    <div class="brand">☁️ SaxWeather</div>
    <div class="location">${escapeHtml(params.name)}</div>
    ${tempLabel ? `<h1 class="temp">${escapeHtml(tempLabel)}</h1>` : ""}
    <div class="condition">${escapeHtml(params.condition)}</div>
    <div class="meta">${escapeHtml(ogDescription)}</div>
    ${params.station ? `<div class="station">Personal weather station: ${escapeHtml(params.station)}</div>` : ""}
    <div class="actions">
      <a class="btn btn-primary" href="${escapeHtml(appURL)}" id="open-app">Open in SaxWeather</a>
      <a class="btn btn-secondary" href="https://apps.apple.com/search?term=SaxWeather">Get SaxWeather on the App Store</a>
    </div>
    <p class="footer">Tap Open in SaxWeather to view live conditions in the app.</p>
  </main>
  <script>
    (function () {
      var appURL = ${JSON.stringify(appURL)};
      var isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
      if (isIOS) {
        document.getElementById("open-app").addEventListener("click", function (e) {
          e.preventDefault();
          window.location.href = appURL;
          setTimeout(function () {
            window.location.href = "https://apps.apple.com/search?term=SaxWeather";
          }, 1500);
        });
      }
    })();
  </script>
</body>
</html>`;

  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
}

function landingPage() {
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>SaxWeather Share Links</title>
  <meta name="description" content="Rich weather share previews for SaxWeather." />
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      background: #0b1220;
      color: #f5f7fb;
      padding: 24px;
      text-align: center;
    }
    p { color: #9aa4b2; max-width: 420px; line-height: 1.6; }
    a { color: #5eb3ff; }
  </style>
</head>
<body>
  <div>
    <h1>SaxWeather</h1>
    <p>Share links from the SaxWeather app open here with a live preview, then deep-link into the app.</p>
    <p><a href="https://apps.apple.com/search?term=SaxWeather">Get SaxWeather</a></p>
  </div>
</body>
</html>`;

  return new Response(html, {
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
