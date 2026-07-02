# Translating SaxWeather

SaxWeather is translated by the community through **Crowdin** — a free, web-based
translation tool. **You do not need a Mac, Xcode, or any coding knowledge to
help.** All strings live in one Xcode String Catalog
(`SaxWeather/SaxWeather/Localizable.xcstrings`); Crowdin syncs it to and from
this repo automatically.

---

## For translators (no setup required)

1. Go to the SaxWeather Crowdin project: **<add project URL here>**.
2. Sign in (free) and pick the language you want to work on — or request a new
   language if yours is missing.
3. Translate strings right in the browser. You'll see:
   - **Context notes** describing where each string appears.
   - **Screenshots** for many strings.
   - **Machine-translation suggestions** you can accept and fix up.
4. That's it. Approved translations are pulled into the app automatically via a
   pull request — you never touch code or JSON.

### Tips for good translations

- Keep the **tone** casual and friendly, matching the app.
- Preserve **placeholders** exactly (e.g. `%@`, `%lld`, `%1$@`) — don't translate
  or reorder them unless your language requires it (use positional `%1$@` forms).
- Leave **units, symbols, and brand names** (SaxWeather, OpenWeatherMap, Weather
  Underground, BOM) untranslated.
- Respect **plural forms** — Crowdin shows the plural categories your language
  needs.

---

## For maintainers — one-time Crowdin setup

1. **Create the project**
   - Sign up at <https://crowdin.com> and apply for the free
     [Crowdin for Open Source](https://crowdin.com/page/open-source-project-setup-request)
     plan (unlimited strings for public repos).
   - Create a project, set **source language = English**, and add your target
     languages.

2. **Add repository secrets** (Settings → Secrets and variables → Actions):
   - `CROWDIN_PROJECT_ID` — the numeric project ID (Project → Tools → API).
   - `CROWDIN_PERSONAL_TOKEN` — a personal access token with project scope
     (Account Settings → API).

3. **First upload**
   - Trigger the **Crowdin Sync** workflow manually (Actions → *Crowdin Sync* →
     *Run workflow*), or just push a change to `Localizable.xcstrings`. This
     uploads all source strings.

4. **Seed with machine translation** (recommended so nobody starts from a blank
   page). Either:
   - **In the Crowdin UI:** Content → *Pre-translation* → *via Machine
     Translation* → select all languages. (Configure an MT engine first under
     Project Settings → Machine Translation.) — or —
   - **Via CI:** run the **Crowdin Pre-translate (MT seed)** workflow (Actions →
     *Run workflow*) and pass the MT engine ID. It machine-translates every
     empty string and opens a PR. MT strings are flagged "needs review" so
     humans can polish them.

5. **Ongoing sync** is automatic:
   - `Crowdin Sync` runs on every change to the catalog, daily on a schedule,
     and on demand. It pushes new source strings up and opens a
     `chore(i18n): new Crowdin translations` PR when translations come back.
   - Review and merge those PRs like any other change.

### How the config maps

- [`crowdin.yml`](crowdin.yml) — points Crowdin at the single multilingual
  `.xcstrings` file (`multilingual: 1`).
- [`.github/workflows/crowdin-sync.yml`](.github/workflows/crowdin-sync.yml) —
  push sources / pull translations.
- [`.github/workflows/crowdin-pretranslate.yml`](.github/workflows/crowdin-pretranslate.yml)
  — one-shot machine-translation seed.

---

## Improving translation quality (optional, for maintainers)

The more context translators have, the better the results. In the String
Catalog you can:

- Add a **comment** to each string describing where/how it's used — these show
  up as context in Crowdin.
- Set **`"shouldTranslate": false`** on strings that must not be translated
  (brand names, pure symbols, debug text) to keep them out of the queue.
- Upload **screenshots** in Crowdin and tag strings to them for visual context.

---

## Adding a language without Crowdin (advanced)

If you'd rather work in Xcode directly: open `SaxWeather.xcodeproj`, select
`Localizable.xcstrings`, use the **+** at the bottom of the editor to add a
language, translate the entries, then open a pull request. This requires macOS
and Xcode, so Crowdin is the preferred path for most contributors.
