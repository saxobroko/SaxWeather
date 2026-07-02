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

    if (url.pathname.startsWith("/assets/")) {
      return serveStaticAsset(request, env);
    }

    if (url.pathname === "/" || url.pathname === "") {
      return landingPage();
    }

    return new Response("Not found", { status: 404 });
  },
};

async function serveStaticAsset(request, env) {
  if (env.ASSETS) {
    const response = await env.ASSETS.fetch(request);
    if (response.status !== 404) {
      return response;
    }
  }
  return new Response("Not found", { status: 404 });
}

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
  const appStore = "https://apps.apple.com/search?term=SaxWeather";
  const github = "https://github.com/saxobroko/SaxWeather";
  const dev = "https://saxobroko.com";
  const ogImage = `${SITE_ORIGIN}/assets/aurora/default.jpg`;

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <title>SaxWeather — the weather app you make your own</title>
  <meta name="description" content="SaxWeather blends Apple WeatherKit, Open-Meteo, Weather Underground, OpenWeatherMap and your own weather station into one endlessly customisable iOS app, with living backgrounds, smart alerts and on-device AI summaries." />
  <meta name="theme-color" content="#0b1220" />
  <link rel="canonical" href="${SITE_ORIGIN}/" />
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'%3E%3Ctext y='.9em' font-size='90'%3E%E2%9B%85%3C/text%3E%3C/svg%3E" />
  <meta property="og:type" content="website" />
  <meta property="og:site_name" content="SaxWeather" />
  <meta property="og:url" content="${SITE_ORIGIN}/" />
  <meta property="og:title" content="SaxWeather — the weather app you make your own" />
  <meta property="og:description" content="One app for every weather source. Endlessly customisable, with living backgrounds, smart alerts and on-device AI summaries." />
  <meta property="og:image" content="${ogImage}" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="SaxWeather" />
  <meta name="twitter:description" content="The weather app you make your own." />
  <meta name="twitter:image" content="${ogImage}" />
  <style>
    :root {
      color-scheme: dark;
      --bg: #0b1220;
      --bg-2: #0d1530;
      --card: rgba(255,255,255,0.055);
      --card-strong: rgba(255,255,255,0.10);
      --border: rgba(255,255,255,0.12);
      --border-strong: rgba(255,255,255,0.22);
      --text: #f5f7fb;
      --muted: #9aa4b2;
      --accent: #5eb3ff;
      --accent-2: #7c5cff;
      --radius: 22px;
      --maxw: 1120px;
      --ease: cubic-bezier(0.22, 1, 0.36, 1);
    }
    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Inter, sans-serif;
      color: var(--text);
      background: var(--bg);
      overflow-x: hidden;
      -webkit-font-smoothing: antialiased;
      line-height: 1.5;
    }
    a { color: inherit; }
    h1, h2, h3 { line-height: 1.08; letter-spacing: -0.02em; margin: 0; }
    p { margin: 0; }
    .wrap { width: min(var(--maxw), 100% - 40px); margin-inline: auto; }

    /* ---------- Animated aurora backdrop ---------- */
    .aurora {
      position: fixed;
      inset: 0;
      z-index: -2;
      overflow: hidden;
      background:
        radial-gradient(1200px 700px at 15% -10%, rgba(94,179,255,0.18), transparent 60%),
        radial-gradient(1000px 800px at 100% 0%, rgba(124,92,255,0.16), transparent 55%),
        linear-gradient(180deg, var(--bg-2), var(--bg) 60%);
    }
    .blob {
      position: absolute;
      width: 46vmax; height: 46vmax;
      border-radius: 50%;
      filter: blur(70px);
      opacity: 0.5;
      background: radial-gradient(circle at 30% 30%, var(--accent), transparent 60%);
      animation: drift 26s var(--ease) infinite alternate;
      transition: background 0.6s ease;
    }
    .b1 { top: -18vmax; left: -10vmax; }
    .b2 { top: 20vmax; right: -16vmax; background: radial-gradient(circle at 30% 30%, var(--accent-2), transparent 60%); animation-duration: 32s; }
    .b3 { bottom: -22vmax; left: 25vmax; background: radial-gradient(circle at 30% 30%, #22d3ee, transparent 60%); opacity: 0.32; animation-duration: 38s; }
    @keyframes drift {
      0%   { transform: translate3d(0,0,0) scale(1); }
      50%  { transform: translate3d(6vmax, 4vmax, 0) scale(1.12); }
      100% { transform: translate3d(-4vmax, -3vmax, 0) scale(0.96); }
    }
    .grain {
      position: fixed; inset: 0; z-index: -1; pointer-events: none;
      opacity: 0.04;
      background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
    }

    /* ---------- Nav ---------- */
    .nav {
      position: sticky; top: 0; z-index: 50;
      transition: background 0.3s ease, border-color 0.3s ease, backdrop-filter 0.3s ease;
      border-bottom: 1px solid transparent;
    }
    .nav.scrolled {
      background: rgba(11,18,32,0.72);
      backdrop-filter: saturate(160%) blur(14px);
      -webkit-backdrop-filter: saturate(160%) blur(14px);
      border-bottom: 1px solid var(--border);
    }
    .nav-inner { display: flex; align-items: center; gap: 20px; height: 64px; }
    .brand { display: flex; align-items: center; gap: 10px; font-weight: 700; text-decoration: none; letter-spacing: -0.01em; }
    .brand .logo {
      width: 30px; height: 30px; border-radius: 9px; display: grid; place-items: center;
      background: linear-gradient(135deg, var(--accent), var(--accent-2));
      box-shadow: 0 6px 18px rgba(94,179,255,0.35);
      transition: background 0.5s ease;
    }
    .nav-links { display: flex; gap: 4px; margin-left: auto; }
    .nav-links a {
      text-decoration: none; color: var(--muted); font-size: 14px; font-weight: 500;
      padding: 8px 12px; border-radius: 10px; transition: color 0.2s, background 0.2s;
    }
    .nav-links a:hover { color: var(--text); background: var(--card); }
    .nav-cta { margin-left: 6px; }
    @media (max-width: 760px) { .nav-links { display: none; } .nav-cta { margin-left: auto; } }

    /* ---------- Buttons ---------- */
    .btn {
      display: inline-flex; justify-content: center; align-items: center; gap: 9px;
      padding: 13px 20px; border-radius: 14px; text-decoration: none;
      font-weight: 600; font-size: 15px; cursor: pointer; border: 1px solid transparent;
      transition: transform 0.2s var(--ease), box-shadow 0.2s ease, background 0.3s ease, border-color 0.2s;
      white-space: nowrap;
    }
    .btn:active { transform: translateY(1px) scale(0.99); }
    .btn-primary {
      background: linear-gradient(135deg, var(--accent), var(--accent-2));
      color: #fff; box-shadow: 0 10px 30px rgba(94,179,255,0.30);
    }
    .btn-primary:hover { transform: translateY(-2px); box-shadow: 0 16px 40px rgba(124,92,255,0.42); }
    .btn-ghost { color: var(--text); border-color: var(--border-strong); background: var(--card); }
    .btn-ghost:hover { border-color: var(--accent); background: var(--card-strong); transform: translateY(-2px); }

    /* ---------- Hero ---------- */
    .hero {
      display: grid; grid-template-columns: 1.05fr 0.95fr; gap: 48px; align-items: center;
      padding: clamp(48px, 9vw, 110px) 0 64px;
    }
    .eyebrow {
      display: inline-flex; align-items: center; gap: 8px;
      font-size: 12.5px; font-weight: 600; letter-spacing: 0.06em; text-transform: uppercase;
      color: var(--accent); padding: 6px 12px; border-radius: 999px;
      border: 1px solid var(--border); background: var(--card); margin-bottom: 22px;
    }
    .eyebrow .dot { width: 7px; height: 7px; border-radius: 50%; background: var(--accent); box-shadow: 0 0 0 4px rgba(94,179,255,0.18); }
    .hero h1 { font-size: clamp(38px, 6vw, 66px); font-weight: 800; }
    .grad {
      background: linear-gradient(120deg, var(--accent), var(--accent-2) 60%, #22d3ee);
      -webkit-background-clip: text; background-clip: text; color: transparent;
    }
    .lede { color: var(--muted); font-size: clamp(16px, 2vw, 19px); margin: 20px 0 30px; max-width: 34em; }
    .cta-row { display: flex; flex-wrap: wrap; gap: 12px; }
    .hero-points { list-style: none; padding: 0; margin: 30px 0 0; display: flex; flex-wrap: wrap; gap: 10px 22px; }
    .hero-points li { display: flex; align-items: center; gap: 8px; color: var(--muted); font-size: 14px; }
    .hero-points svg { color: var(--accent); flex: none; }
    @media (max-width: 900px) { .hero { grid-template-columns: 1fr; gap: 40px; text-align: center; } .hero-points, .cta-row { justify-content: center; } .eyebrow { }}

    /* ---------- Phone mock ---------- */
    .hero-visual { display: grid; place-items: center; perspective: 1400px; }
    .phone {
      width: min(310px, 82vw); aspect-ratio: 9 / 19.2;
      border-radius: 44px; padding: 12px;
      background: linear-gradient(160deg, rgba(255,255,255,0.16), rgba(255,255,255,0.03));
      border: 1px solid var(--border-strong);
      box-shadow: 0 40px 90px rgba(0,0,0,0.55), inset 0 1px 0 rgba(255,255,255,0.25);
      transform: rotateY(-16deg) rotateX(6deg);
      transition: transform 0.4s var(--ease);
      animation: floaty 7s ease-in-out infinite;
      will-change: transform;
    }
    @keyframes floaty { 0%,100% { translate: 0 -6px; } 50% { translate: 0 8px; } }
    .screen {
      position: relative; height: 100%; border-radius: 34px; overflow: hidden;
      background: #0a1020 center/cover no-repeat;
      display: flex; flex-direction: column; color: #fff;
    }
    .screen .sky { position: absolute; inset: 0; z-index: 0; }
    .screen .sky img { width: 100%; height: 100%; object-fit: cover; opacity: 0.9; }
    .screen .scrim { position: absolute; inset: 0; z-index: 1; background: linear-gradient(180deg, rgba(6,10,22,0.15), rgba(6,10,22,0.72)); }
    .screen .content { position: relative; z-index: 2; padding: 22px 20px; display: flex; flex-direction: column; height: 100%; }
    .s-loc { font-size: 15px; font-weight: 600; opacity: 0.92; }
    .s-sub { font-size: 12px; color: rgba(255,255,255,0.7); margin-top: 2px; }
    .s-main { display: flex; align-items: flex-start; justify-content: space-between; margin-top: 6px; }
    .s-temp { font-size: 68px; font-weight: 300; line-height: 1; letter-spacing: -0.04em; }
    .s-icon { width: 78px; height: 78px; margin-top: 6px; display: grid; place-items: center; font-size: 46px; }
    .s-cond { font-size: 15px; font-weight: 600; margin-top: -6px; }
    .s-hi { font-size: 12.5px; color: rgba(255,255,255,0.72); margin-top: 3px; }
    .s-hours { margin-top: auto; display: grid; grid-template-columns: repeat(5, 1fr); gap: 6px; }
    .s-hour {
      background: rgba(255,255,255,0.12); border: 1px solid rgba(255,255,255,0.14);
      border-radius: 13px; padding: 9px 4px; text-align: center; backdrop-filter: blur(6px);
    }
    .s-hour .h { font-size: 10px; color: rgba(255,255,255,0.7); }
    .s-hour .i { font-size: 16px; margin: 3px 0; }
    .s-hour .t { font-size: 12px; font-weight: 600; }
    .s-tiles { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 8px; }
    .s-tile { background: rgba(255,255,255,0.10); border: 1px solid rgba(255,255,255,0.14); border-radius: 13px; padding: 9px 11px; backdrop-filter: blur(6px); }
    .s-tile .k { font-size: 9.5px; text-transform: uppercase; letter-spacing: 0.05em; color: rgba(255,255,255,0.7); }
    .s-tile .v { font-size: 16px; font-weight: 600; margin-top: 2px; }

    /* ---------- Sections ---------- */
    .section { padding: clamp(56px, 9vw, 100px) 0; }
    .sec-head { max-width: 640px; margin-bottom: 44px; }
    .sec-head.center { margin-inline: auto; text-align: center; }
    .kicker { color: var(--accent); font-weight: 700; font-size: 13px; letter-spacing: 0.09em; text-transform: uppercase; }
    .sec-head h2 { font-size: clamp(28px, 4.4vw, 44px); font-weight: 800; margin-top: 10px; }
    .sec-head p { color: var(--muted); font-size: 17px; margin-top: 14px; }

    /* ---------- Sources marquee ---------- */
    .sources { padding: 8px 0 12px; }
    .sources-label { text-align: center; color: var(--muted); font-size: 13px; letter-spacing: 0.05em; text-transform: uppercase; margin-bottom: 18px; }
    .marquee { position: relative; overflow: hidden; -webkit-mask-image: linear-gradient(90deg, transparent, #000 12%, #000 88%, transparent); mask-image: linear-gradient(90deg, transparent, #000 12%, #000 88%, transparent); }
    .marquee-track { display: flex; gap: 46px; width: max-content; animation: scroll 26s linear infinite; }
    .marquee:hover .marquee-track { animation-play-state: paused; }
    .marquee-track span { color: var(--muted); font-weight: 700; font-size: clamp(16px, 2vw, 22px); opacity: 0.85; white-space: nowrap; }
    @keyframes scroll { to { transform: translateX(-50%); } }

    /* ---------- Cards / grid ---------- */
    .grid { display: grid; gap: 18px; }
    .features-grid { grid-template-columns: repeat(3, 1fr); }
    @media (max-width: 900px) { .features-grid { grid-template-columns: repeat(2, 1fr); } }
    @media (max-width: 600px) { .features-grid { grid-template-columns: 1fr; } }
    .card {
      position: relative; border: 1px solid var(--border); border-radius: var(--radius);
      background: var(--card); padding: 24px; overflow: hidden;
      transition: transform 0.3s var(--ease), border-color 0.3s, background 0.3s;
    }
    .card::before {
      content: ""; position: absolute; inset: 0; border-radius: inherit; padding: 1px;
      background: linear-gradient(135deg, rgba(94,179,255,0.5), transparent 40%);
      -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
      -webkit-mask-composite: xor; mask-composite: exclude;
      opacity: 0; transition: opacity 0.3s;
    }
    .card:hover { transform: translateY(-4px); border-color: var(--border-strong); background: var(--card-strong); }
    .card:hover::before { opacity: 1; }
    .card .ic {
      width: 46px; height: 46px; border-radius: 13px; display: grid; place-items: center;
      background: linear-gradient(135deg, rgba(94,179,255,0.22), rgba(124,92,255,0.22));
      border: 1px solid var(--border); color: var(--accent); margin-bottom: 16px;
      transition: color 0.4s ease;
    }
    .card h3 { font-size: 18px; font-weight: 700; }
    .card p { color: var(--muted); font-size: 14.5px; margin-top: 8px; }
    .card.span-2 { grid-column: span 2; }
    @media (max-width: 600px) { .card.span-2 { grid-column: span 1; } }

    /* ---------- Customise ---------- */
    .customise { display: grid; grid-template-columns: 1fr 1fr; gap: 40px; align-items: center; }
    @media (max-width: 860px) { .customise { grid-template-columns: 1fr; } }
    .swatches { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 22px; }
    .swatch {
      width: 42px; height: 42px; border-radius: 12px; border: 2px solid transparent; cursor: pointer;
      transition: transform 0.2s var(--ease), border-color 0.2s; padding: 0;
      box-shadow: 0 6px 16px rgba(0,0,0,0.3);
    }
    .swatch:hover { transform: translateY(-3px) scale(1.06); }
    .swatch[aria-pressed="true"] { border-color: #fff; }
    .hint { color: var(--muted); font-size: 13.5px; margin-top: 16px; }
    .icons-strip { display: flex; gap: 14px; flex-wrap: wrap; }
    .icon-card {
      flex: 1 1 120px; border: 1px solid var(--border); border-radius: 18px; background: var(--card);
      padding: 14px; text-align: center;
    }
    .icon-card .anim { width: 100%; aspect-ratio: 1; display: grid; place-items: center; font-size: 44px; }
    .icon-card .lbl { font-size: 12px; color: var(--muted); margin-top: 6px; }

    /* ---------- Alerts ---------- */
    .alert-card {
      border: 1px solid var(--border); border-radius: var(--radius); background: var(--card);
      padding: 20px; display: flex; gap: 14px; align-items: flex-start;
    }
    .alert-card + .alert-card { margin-top: 14px; }
    .alert-card .badge { flex: none; width: 42px; height: 42px; border-radius: 12px; display: grid; place-items: center; font-size: 20px; }
    .badge.warn { background: rgba(255,159,69,0.16); border: 1px solid rgba(255,159,69,0.4); }
    .badge.ai { background: linear-gradient(135deg, rgba(94,179,255,0.22), rgba(124,92,255,0.22)); border: 1px solid var(--border); }
    .badge.rain { background: rgba(94,179,255,0.16); border: 1px solid rgba(94,179,255,0.4); }
    .alert-card h4 { margin: 0; font-size: 15px; }
    .alert-card p { color: var(--muted); font-size: 13.5px; margin-top: 4px; }

    /* ---------- Gallery ---------- */
    .gallery { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
    @media (max-width: 860px) { .gallery { grid-template-columns: repeat(2, 1fr); } }
    .shot {
      position: relative; border-radius: 18px; overflow: hidden; aspect-ratio: 3/4;
      border: 1px solid var(--border);
    }
    .shot img { width: 100%; height: 100%; object-fit: cover; transition: transform 0.6s var(--ease); }
    .shot:hover img { transform: scale(1.07); }
    .shot figcaption {
      position: absolute; left: 0; right: 0; bottom: 0; padding: 12px;
      font-size: 12.5px; font-weight: 600;
      background: linear-gradient(180deg, transparent, rgba(6,10,22,0.8));
    }
    .shot .tag { font-size: 10px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--accent); display: block; }

    /* ---------- Final CTA ---------- */
    .cta-final .panel {
      border: 1px solid var(--border-strong); border-radius: 28px; padding: clamp(36px, 6vw, 66px);
      text-align: center; position: relative; overflow: hidden;
      background:
        radial-gradient(700px 400px at 50% -30%, rgba(94,179,255,0.22), transparent 60%),
        var(--card-strong);
    }
    .cta-final h2 { font-size: clamp(28px, 4.4vw, 46px); font-weight: 800; }
    .cta-final p { color: var(--muted); font-size: 17px; margin: 14px auto 26px; max-width: 32em; }

    /* ---------- Footer ---------- */
    footer { border-top: 1px solid var(--border); padding: 34px 0; margin-top: 20px; }
    .foot-inner { display: flex; flex-wrap: wrap; gap: 16px; align-items: center; justify-content: space-between; }
    .foot-links { display: flex; gap: 18px; flex-wrap: wrap; }
    .foot-links a { color: var(--muted); text-decoration: none; font-size: 14px; }
    .foot-links a:hover { color: var(--text); }
    .foot-copy { color: var(--muted); font-size: 13px; }

    /* ---------- Reveal ---------- */
    .reveal { opacity: 0; transform: translateY(22px); transition: opacity 0.7s var(--ease), transform 0.7s var(--ease); }
    .reveal.in { opacity: 1; transform: none; }
    .skip { position: absolute; left: -999px; top: 0; background: var(--accent); color: #001; padding: 10px 16px; border-radius: 10px; z-index: 100; }
    .skip:focus { left: 12px; top: 12px; }

    @media (prefers-reduced-motion: reduce) {
      * { animation: none !important; scroll-behavior: auto !important; }
      .reveal { opacity: 1; transform: none; }
      .phone { transform: none; }
    }
  </style>
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>
  <div class="aurora" aria-hidden="true">
    <span class="blob b1"></span><span class="blob b2"></span><span class="blob b3"></span>
  </div>
  <div class="grain" aria-hidden="true"></div>

  <header class="nav" id="nav">
    <div class="wrap nav-inner">
      <a class="brand" href="/">
        <span class="logo">☁️</span>
        SaxWeather
      </a>
      <nav class="nav-links" aria-label="Primary">
        <a href="#features">Features</a>
        <a href="#customise">Customise</a>
        <a href="#alerts">Alerts</a>
        <a href="#gallery">Backgrounds</a>
      </nav>
      <a class="btn btn-primary nav-cta" href="${appStore}">Get the app</a>
    </div>
  </header>

  <main id="main">
    <!-- HERO -->
    <section class="wrap hero">
      <div class="hero-copy reveal">
        <span class="eyebrow"><span class="dot"></span> One app · every source</span>
        <h1>The weather app you <span class="grad">make your own</span>.</h1>
        <p class="lede">SaxWeather blends Apple WeatherKit, Open-Meteo, Weather Underground, OpenWeatherMap and your own personal weather station into one beautifully customisable iOS experience — with living backgrounds, smart local alerts and on-device AI summaries.</p>
        <div class="cta-row">
          <a class="btn btn-primary" href="${appStore}">
            <svg width="17" height="17" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.3 12.7c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.9-1.5-.1-2.8.8-3.5.8s-1.9-.8-3.1-.8c-1.6 0-3 .9-3.9 2.4-1.6 2.9-.4 7.1 1.2 9.4.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7 2-1.1 2.8-2.2c.9-1.3 1.2-2.5 1.3-2.6-.1 0-2.4-1-2.4-3.6zM14 5.6c.6-.8 1.1-1.9 1-3-.9 0-2 .6-2.7 1.4-.6.7-1.1 1.8-1 2.9 1 .1 2-.5 2.7-1.3z"/></svg>
            Download on iOS
          </a>
          <a class="btn btn-ghost" href="#features">Explore features</a>
        </div>
        <ul class="hero-points">
          <li>${check()} 5 data sources</li>
          <li>${check()} Private &amp; on-device</li>
          <li>${check()} Home-screen widgets</li>
          <li>${check()} iCloud theme sync</li>
        </ul>
      </div>
      <div class="hero-visual reveal">
        <div class="phone" id="phone">
          <div class="screen">
            <div class="sky"><img src="/assets/aurora/default.jpg" alt="" loading="eager" /></div>
            <div class="scrim"></div>
            <div class="content">
              <div class="s-loc">Sydney</div>
              <div class="s-sub">Personal station · updated now</div>
              <div class="s-main">
                <div class="s-temp">24°</div>
                <div class="s-icon" data-lottie data-src="/assets/lottie/clear-day.json"><span class="fb">☀️</span></div>
              </div>
              <div class="s-cond">Clear</div>
              <div class="s-hi">H 26°  ·  L 18°  ·  Feels 22°</div>
              <div class="s-tiles">
                <div class="s-tile"><div class="k">Wind</div><div class="v">11 km/h</div></div>
                <div class="s-tile"><div class="k">Humidity</div><div class="v">54%</div></div>
              </div>
              <div class="s-hours">
                <div class="s-hour"><div class="h">now</div><div class="i">☀️</div><div class="t">24°</div></div>
                <div class="s-hour"><div class="h">1PM</div><div class="i">🌤️</div><div class="t">25°</div></div>
                <div class="s-hour"><div class="h">2PM</div><div class="i">⛅️</div><div class="t">24°</div></div>
                <div class="s-hour"><div class="h">3PM</div><div class="i">🌦️</div><div class="t">22°</div></div>
                <div class="s-hour"><div class="h">4PM</div><div class="i">🌧️</div><div class="t">20°</div></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- SOURCES -->
    <section class="wrap sources reveal">
      <p class="sources-label">Powered by the sources you trust</p>
      <div class="marquee">
        <div class="marquee-track">
          <span>Apple WeatherKit</span><span>Open-Meteo</span><span>Weather Underground</span><span>OpenWeatherMap</span><span>Bureau of Meteorology</span><span>Personal Weather Stations</span>
          <span>Apple WeatherKit</span><span>Open-Meteo</span><span>Weather Underground</span><span>OpenWeatherMap</span><span>Bureau of Meteorology</span><span>Personal Weather Stations</span>
        </div>
      </div>
    </section>

    <!-- FEATURES -->
    <section class="wrap section" id="features">
      <div class="sec-head center reveal">
        <span class="kicker">Features</span>
        <h2>Everything you want, beautifully done</h2>
        <p>A full-featured forecast with the flexibility to look and behave exactly how you like.</p>
      </div>
      <div class="grid features-grid">
        ${feature("cloud", "Every source, one app", "Pull from Apple WeatherKit, Open-Meteo, Weather Underground, OpenWeatherMap — or your own backyard weather station. Pick a favourite or let SaxWeather choose.")}
        ${feature("wand", "Endlessly customisable", "Accent colours, card styles, corner radius, typography, layouts and more. Save whole looks as themes and switch in a tap.")}
        ${feature("bolt", "Smart local alerts", "Location-aware severe-weather and BOM warnings, rain alerts, quiet hours and spoken announcements — tuned to where you actually are.")}
        ${feature("sparkle", "On-device AI summaries", "Turn dense warnings into plain-language summaries with Apple Intelligence, processed privately on your device.")}
        ${feature("widget", "Home-screen widgets", "Small, medium and large widgets that match your theme and stay up to date in the background.")}
        ${feature("a11y", "Built for everyone", "Dynamic Type, reduce motion, high-contrast outlines, bold text and rich VoiceOver labels throughout.")}
      </div>
    </section>

    <!-- CUSTOMISE -->
    <section class="wrap section" id="customise">
      <div class="customise">
        <div class="reveal">
          <span class="kicker">Make it yours</span>
          <h2 class="sec-head" style="margin-bottom:0;font-size:clamp(26px,4vw,40px);">Your accent. Your vibe.</h2>
          <p class="hint" style="font-size:16px;margin-top:14px;">Tap a colour to recolour this whole page — a tiny taste of the control you get inside the app, where every surface bends to your taste.</p>
          <div class="swatches" id="swatches" role="group" aria-label="Accent colour">
            ${swatch("blue","Blue")}
            ${swatch("purple","Purple")}
            ${swatch("pink","Pink")}
            ${swatch("red","Red")}
            ${swatch("orange","Orange")}
            ${swatch("yellow","Yellow")}
            ${swatch("green","Green")}
            ${swatch("teal","Teal")}
            ${swatch("cyan","Cyan")}
            ${swatch("indigo","Indigo")}
          </div>
          <p class="hint">Ten accent colours, light &amp; dark themes, and full card styling all live in Settings.</p>
        </div>
        <div class="reveal">
          <span class="kicker">Living icons</span>
          <h3 style="font-size:22px;margin:10px 0 16px;">Animated, never static</h3>
          <div class="icons-strip">
            ${animIcon("clear-day","Clear","☀️")}
            ${animIcon("rainy","Rain","🌧️")}
            ${animIcon("snowy","Snow","❄️")}
            ${animIcon("thunderstorm","Storm","⛈️")}
          </div>
          <p class="hint">Real Lottie animations from the app, streamed straight from this site.</p>
        </div>
      </div>
    </section>

    <!-- ALERTS -->
    <section class="wrap section" id="alerts">
      <div class="sec-head reveal">
        <span class="kicker">Alerts that matter</span>
        <h2>Warnings for your street, not just your state</h2>
        <p>SaxWeather filters official warnings by how close they actually are, then makes them easy to understand.</p>
      </div>
      <div class="grid" style="grid-template-columns:1fr 1fr;gap:14px;" >
        <div class="reveal">
          <div class="alert-card"><div class="badge warn">⚠️</div><div><h4>Proximity-filtered warnings</h4><p>State-wide BOM alerts are ranked by distance so you only get the ones near you.</p></div></div>
          <div class="alert-card"><div class="badge rain">🌧️</div><div><h4>Rain &amp; severe alerts</h4><p>Open-Meteo rain nowcasts plus WeatherKit / BOM severe warnings, with quiet hours.</p></div></div>
        </div>
        <div class="reveal">
          <div class="alert-card"><div class="badge ai">✨</div><div><h4>Plain-language AI summaries</h4><p>Apple Intelligence rewrites jargon-filled warnings into a sentence you can act on — summarise one alert or all of them.</p></div></div>
          <div class="alert-card"><div class="badge ai">🔒</div><div><h4>Completely private</h4><p>Summaries run on-device. No accounts, no servers, no tracking.</p></div></div>
        </div>
      </div>
    </section>

    <!-- GALLERY -->
    <section class="wrap section" id="gallery">
      <div class="sec-head center reveal">
        <span class="kicker">Living backgrounds</span>
        <h2>Backdrops that match the sky</h2>
        <p>Dynamic photo backgrounds shift with the current conditions and time of day. Unlock the Aurora set in the cosmetics store.</p>
      </div>
      <div class="gallery reveal">
        ${shot("aurora/sunny.jpg","Aurora","Clear")}
        ${shot("aurora/rainy.jpg","Aurora","Rain")}
        ${shot("aurora/snowy.jpg","Aurora","Snow")}
        ${shot("aurora/thunder.jpg","Aurora","Storm")}
        ${shot("backgrounds/cloudy.jpg","Preset","Cloudy")}
        ${shot("backgrounds/foggy.jpg","Preset","Fog")}
        ${shot("aurora/foggy.jpg","Aurora","Fog")}
        ${shot("backgrounds/windy.jpg","Preset","Wind")}
      </div>
    </section>

    <!-- FINAL CTA -->
    <section class="wrap section cta-final">
      <div class="panel reveal">
        <h2>Make the weather yours.</h2>
        <p>Download SaxWeather and build the forecast you have always wanted — free to start, endlessly tweakable.</p>
        <div class="cta-row" style="justify-content:center;">
          <a class="btn btn-primary" href="${appStore}">Download on the App Store</a>
          <a class="btn btn-ghost" href="${github}">View source on GitHub</a>
        </div>
      </div>
    </section>
  </main>

  <footer>
    <div class="wrap foot-inner">
      <a class="brand" href="/"><span class="logo">☁️</span> SaxWeather</a>
      <nav class="foot-links" aria-label="Footer">
        <a href="${appStore}">App Store</a>
        <a href="${github}">GitHub</a>
        <a href="${dev}">Developer</a>
        <a href="#features">Features</a>
      </nav>
      <div class="foot-copy">© ${new Date().getFullYear()} Saxon Brooker · Made with ☁️</div>
    </div>
  </footer>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js" defer></script>
  <script>
    (function () {
      var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

      // Scroll-reveal
      var reveals = document.querySelectorAll(".reveal");
      if ("IntersectionObserver" in window && !reduce) {
        var io = new IntersectionObserver(function (entries) {
          entries.forEach(function (en) {
            if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); }
          });
        }, { threshold: 0.12 });
        reveals.forEach(function (el) { io.observe(el); });
      } else {
        reveals.forEach(function (el) { el.classList.add("in"); });
      }

      // Nav shadow on scroll
      var nav = document.getElementById("nav");
      var onScroll = function () { nav.classList.toggle("scrolled", window.scrollY > 10); };
      onScroll();
      window.addEventListener("scroll", onScroll, { passive: true });

      // Accent picker
      var pairs = {
        blue: ["#5eb3ff", "#7c5cff"], purple: ["#7c5cff", "#b06cff"], pink: ["#ff6fae", "#ff9a5a"],
        red: ["#ff5a5f", "#ff9f45"], orange: ["#ff9f45", "#ffd23f"], yellow: ["#ffd23f", "#34d399"],
        green: ["#34d399", "#22d3ee"], teal: ["#2dd4bf", "#5eb3ff"], cyan: ["#22d3ee", "#6366f1"],
        indigo: ["#6366f1", "#7c5cff"]
      };
      var swatches = document.querySelectorAll(".swatch");
      swatches.forEach(function (sw) {
        sw.addEventListener("click", function () {
          var p = pairs[sw.getAttribute("data-accent")];
          if (!p) return;
          document.documentElement.style.setProperty("--accent", p[0]);
          document.documentElement.style.setProperty("--accent-2", p[1]);
          swatches.forEach(function (o) { o.setAttribute("aria-pressed", "false"); });
          sw.setAttribute("aria-pressed", "true");
        });
      });

      // Subtle phone tilt (pointer)
      var phone = document.getElementById("phone");
      if (phone && !reduce && window.matchMedia("(pointer:fine)").matches) {
        var hero = phone.closest(".hero");
        hero.addEventListener("pointermove", function (e) {
          var r = hero.getBoundingClientRect();
          var dx = (e.clientX - r.left) / r.width - 0.5;
          var dy = (e.clientY - r.top) / r.height - 0.5;
          phone.style.transform = "rotateY(" + (-16 + dx * 14) + "deg) rotateX(" + (6 - dy * 12) + "deg)";
        });
        hero.addEventListener("pointerleave", function () {
          phone.style.transform = "rotateY(-16deg) rotateX(6deg)";
        });
      }

      // Lottie animations (progressive enhancement)
      window.addEventListener("load", function () {
        if (!window.lottie) return;
        document.querySelectorAll("[data-lottie]").forEach(function (el) {
          try {
            var anim = lottie.loadAnimation({
              container: el, renderer: "svg", loop: true, autoplay: !reduce,
              path: el.getAttribute("data-src")
            });
            anim.addEventListener("DOMLoaded", function () {
              var fb = el.querySelector(".fb");
              if (fb) fb.style.display = "none";
            });
          } catch (err) { /* keep emoji fallback */ }
        });
      });
    })();
  </script>
</body>
</html>`;

  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=600",
    },
  });
}

function check() {
  return '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>';
}

function feature(icon, title, body) {
  return `<article class="card">
      <div class="ic">${featureIcon(icon)}</div>
      <h3>${escapeHtml(title)}</h3>
      <p>${escapeHtml(body)}</p>
    </article>`;
}

function swatch(name, label) {
  const map = {
    blue: ["#5eb3ff", "#7c5cff"], purple: ["#7c5cff", "#b06cff"], pink: ["#ff6fae", "#ff9a5a"],
    red: ["#ff5a5f", "#ff9f45"], orange: ["#ff9f45", "#ffd23f"], yellow: ["#ffd23f", "#34d399"],
    green: ["#34d399", "#22d3ee"], teal: ["#2dd4bf", "#5eb3ff"], cyan: ["#22d3ee", "#6366f1"],
    indigo: ["#6366f1", "#7c5cff"],
  };
  const p = map[name] || map.blue;
  const pressed = name === "blue" ? "true" : "false";
  return `<button class="swatch" data-accent="${name}" aria-pressed="${pressed}" aria-label="${escapeHtml(label)} accent" style="background:linear-gradient(135deg, ${p[0]}, ${p[1]});"></button>`;
}

function animIcon(file, label, fallback) {
  return `<div class="icon-card">
      <div class="anim" data-lottie data-src="/assets/lottie/${file}.json"><span class="fb">${fallback}</span></div>
      <div class="lbl">${escapeHtml(label)}</div>
    </div>`;
}

function shot(path, tag, label) {
  return `<figure class="shot">
      <img src="/assets/${path}" alt="${escapeHtml(label)} background" loading="lazy" />
      <figcaption><span class="tag">${escapeHtml(tag)}</span>${escapeHtml(label)}</figcaption>
    </figure>`;
}

function featureIcon(name) {
  const s = 'width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"';
  switch (name) {
    case "cloud":
      return `<svg ${s}><path d="M17.5 19a4.5 4.5 0 0 0 0-9 6 6 0 0 0-11.6 1.5A3.5 3.5 0 0 0 6.5 19z"/></svg>`;
    case "wand":
      return `<svg ${s}><path d="m3 21 12-12"/><path d="M15 5l1.5-1.5M18 8l2-1M12 3l.6 2M20 12l-2 .6"/><circle cx="17.5" cy="6.5" r="1.5"/></svg>`;
    case "bolt":
      return `<svg ${s}><path d="M13 2 3 14h7l-1 8 10-12h-7z"/></svg>`;
    case "sparkle":
      return `<svg ${s}><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2 2M16 16l2 2M18 6l-2 2M8 16l-2 2"/><circle cx="12" cy="12" r="2.4"/></svg>`;
    case "widget":
      return `<svg ${s}><rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="3" width="8" height="8" rx="2"/><rect x="3" y="13" width="8" height="8" rx="2"/><rect x="13" y="13" width="8" height="8" rx="2"/></svg>`;
    case "a11y":
      return `<svg ${s}><circle cx="12" cy="4.5" r="1.6"/><path d="M4 8h16M12 8v7M8.5 21 12 15l3.5 6"/></svg>`;
    default:
      return `<svg ${s}><circle cx="12" cy="12" r="9"/></svg>`;
  }
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
