# SlimSocial 2026 Roadmap: PRO, Remote Rules, Self-Fix Loop, ASO — Design

**Date:** 2026-07-03
**Status:** Approved design, pending implementation
**Baseline:** `feature/yuka-style-donate` (422b214), which sits on top of the completed Kotlin/Compose rewrite (`kotlin-rewrite-2026`)

## 1. Goals

The product requirements this design addresses:

1. Run well on low-performance Android devices as well as modern ones.
2. Be robust to errors and to Facebook page/DOM changes in the wild.
3. Achieve high store ranking (Play Store), with refreshed ASO.
4. Offer a Yuka-style pay-what-you-want subscription that unlocks PRO.
5. PRO unlocks extra Facebook page themes, and (later) an AI mode that generates JS injection snippets.
6. Establish a self-fixing loop: Sentry issues trigger Claude to draft fix PRs.
7. Keep a clear, well-documented open-source codebase.
8. Keep automated builds on GitHub (already done).
9. Keep a Google-free build published on F-Droid (already done).

Requirements 1, 7, 8, 9 are substantially met by the existing rewrite (render-gone recovery, R8 minification, APK ≤ 6.5 MB full / 1.6 MB fdroid, 213 unit tests, CI build/release workflows, published F-Droid metadata). This design covers the gaps, decomposed into five workstreams.

## 2. Decisions already made

| Decision | Choice |
|---|---|
| PRO model | Convert the existing four `support_yearly_*` annual subscriptions into PRO unlocks. Any active tier ⇒ PRO (true Yuka model). Existing subscribers become PRO automatically. |
| F-Droid | PRO features are compiled out of the `fdroid` flavor (no Play Billing there). |
| Themes scope | Facebook page themes via CSS injection (AMOLED, accent colors, compact mode) — not app-chrome theming. |
| Self-fix loop | Scheduled GitHub Action pulls Sentry issues and runs Claude Code to open **draft** PRs. Human reviews and merges; never auto-merge. |
| AI snippet mode | Deferred. Backend/API-key architecture intentionally undecided; spec reserves the feature slot only. |

## 3. Workstream 1 — PRO entitlement + Facebook page themes

### 3.1 Entitlement

New interface in `platform/` (flavor-split like `CrashReporter` and `DonationLauncher`):

```kotlin
interface ProEntitlement {
    /** Reactive PRO state; emits on billing connection changes. */
    val isPro: StateFlow<Boolean>
    suspend fun refresh()
}
```

- **`full` flavor** (`PlayBillingProEntitlement`): queries Play Billing for active subscriptions; any active `support_yearly_1..4` purchase ⇒ PRO. Purchases are already acknowledged by the existing donation flow.
- **`fdroid` flavor**: object returning constant `false`. PRO-gated UI is not shown; theme rules and picker are excluded from the fdroid source set so no dead paywall appears.
- **Offline grace:** last known entitlement cached in DataStore (`proCachedAt`, `proActive`). On startup the cached value is used immediately; billing re-verifies in the background. Cache expires after 30 days without successful re-verification (subscription period is annual; 30 days tolerates offline stretches without enabling indefinite freeloading).
- **No server-side receipt validation.** Play Billing client-side verification is accepted; the app is open source and a determined user can patch the APK regardless. Not worth a backend.

### 3.2 Donate screen → PRO screen

- The existing Yuka-style pay-what-you-want screen (slider, four tiers, mascot moods) is reframed: title and copy change from "support the project" to "Get PRO — support the project and unlock extras".
- Tier list unchanged (`support_yearly_1..4`, annual). No new Play Console products needed.
- After purchase, entitlement refreshes and gated features unlock immediately.
- A small "PRO" badge appears in Settings when active.

### 3.3 Facebook page themes

- New `ThemeRule` implementations on the existing `InjectionRule` pipeline (`rules/` package), composed by `InjectionComposer` like current rules:
  - **AMOLED black** (true-black variant of the existing dark CSS)
  - **Accent themes:** 3–4 color variants (e.g. green, purple, orange) re-tinting FB chrome
  - **Compact mode:** reduced paddings/font-size for density
- Theme selection stored in DataStore (`selectedTheme: String?`); only one theme active at a time; themes compose with existing free dark mode toggle rules (theme wins on conflicting selectors).
- **Free tier keeps:** current dark mode + all existing CSS toggles. **PRO gates:** the new theme picker only.
- UI: "Themes" entry in Settings (full flavor only). Non-PRO users see the picker with previews and a lock + "Get PRO" CTA deep-linking to the PRO screen.
- Testing: each `ThemeRule` is pure (`cssFor(url)`), unit-tested like existing rules; entitlement gating tested with a fake `ProEntitlement`.

## 4. Workstream 2 — Remote injection rules (robustness to Facebook changes)

Problem: injection rules (ad-hiding selectors, dark CSS, etc.) are hardcoded in the binary. When Facebook changes its DOM, a fix requires a full release train (Play review, F-Droid build cycle).

Design:

- Selector/CSS payloads for volatile rules move to a versioned JSON document, e.g. `rules/remote-rules.json`, **hosted in this same GitHub repo** and fetched at runtime from `raw.githubusercontent.com`. The repo is the config server; no infrastructure.
- The APK bundles a snapshot of the same JSON as the fallback. Runtime resolution: fetched version (if newer and valid) → bundled version.
- Fetch policy: at most once per 24 h, on app start, Wi-Fi not required (file is ~KBs), fail-silent to bundled rules.
- Validation before applying a fetched document: JSON schema check, `schemaVersion` compatibility, size cap, and a plain-text sanity rule — **remote documents may only supply CSS and selector strings, never JavaScript**. JS injection rules stay compiled-in; this keeps the remote channel low-risk (worst case: wrong styling), avoiding a remote-code-execution channel through a compromised repo.
- Fdroid-compatible: plain OkHttp/HttpsURLConnection fetch, no Google services. A settings toggle ("Update filter rules automatically", default on) satisfies F-Droid expectations about network calls; documented in the F-Droid description.
- Cached fetched document stored in app files dir with its ETag; `InjectionComposer` reads rules through a `RuleSource` abstraction so existing unit tests keep working against bundled rules.

## 5. Workstream 3 — Sentry → Claude self-fix loop

- New GitHub Action workflow `sentry-autofix.yml`, scheduled (e.g. every 6 h) + manual dispatch.
- Steps:
  1. Query Sentry API for new or regressed issues since last run (state stored via issue labels or a repo variable).
  2. For each qualifying issue (crash with stacktrace mapping to app code, above a small event threshold), invoke `anthropics/claude-code-action` with the stacktrace, Sentry issue context, and repo checkout.
  3. Claude produces a **draft PR**: fix + regression test + link to the Sentry issue, labeled `auto-fix`.
  4. Existing `build.yml` CI runs on the PR. Human (Leo) reviews and merges; **auto-merge is never enabled**.
- Guardrails: max N draft PRs open at a time (skip run if exceeded); one PR per Sentry issue (dedupe by issue ID in PR title); secrets needed: `SENTRY_AUTH_TOKEN`, `ANTHROPIC_API_KEY`.
- Out of scope: automatic Sentry issue resolution (the merged fix's release tag lets Sentry auto-resolve by version).

## 6. Workstream 4 — ASO refresh

- Adopt **fastlane supply metadata structure** in-repo: `fastlane/metadata/android/<locale>/` with `title.txt`, `short_description.txt`, `full_description.txt`, `changelogs/`, and `images/phoneScreenshots/`. Both Play (via fastlane/CI) and F-Droid (native support for this layout) read it — one source of truth, versioned.
- Rewrite listing copy around the differentiators: lightweight (≤7 MB), works on old devices, privacy-first, ad-hiding, open source, PRO themes. Keyword research and competitor gap analysis via appeeky ASO tooling as a separate execution task; copy lands in the fastlane files.
- Refresh screenshots from the current Kotlin UI (existing `img/store/` Pixel shots are from the Flutter era).
- **Rating prompt:** smart trigger for the already-integrated Play In-App Review — ask after signals of satisfied use (e.g. ≥5 sessions and ≥3 days since install, never after a crash session, never more than once per version). Fdroid flavor: no-op (already shimmed).
- Optional CI step: `release.yml` gains a fastlane `supply` upload of metadata alongside the existing AAB upload.

## 7. Workstream 5 — AI snippet mode (reserved, not designed)

PRO will eventually include an AI mode that generates custom JS injection snippets from natural-language prompts. The API access model (hosted proxy vs. bring-your-own-key) is deliberately undecided. No implementation work in this cycle. The PRO entitlement from WS1 is the only prerequisite this design guarantees.

## 8. Build order and dependencies

```
WS1 (PRO + themes)  →  WS2 (remote rules)   [independent after WS1]
                    →  WS3 (self-fix loop)  [independent, no app code]
                    →  WS4 (ASO refresh)    [independent; screenshots benefit from WS1 themes]
```

WS1 first (it defines the entitlement everything else references in copy/screenshots). WS2–WS4 can proceed in parallel afterwards. Each workstream gets its own implementation plan and PR(s).

## 9. Testing strategy

- WS1: unit tests for entitlement mapping (fake BillingClient), theme rules (pure CSS functions), gating logic; manual matrix addition in TESTING.md for purchase/restore flows.
- WS2: unit tests for JSON parsing/validation/version comparison and `RuleSource` fallback; a malformed-document corpus test.
- WS3: workflow validated by manual `workflow_dispatch` against a synthetic Sentry issue.
- WS4: fastlane metadata linted in CI (`fastlane supply --validate_only` when secret present); screenshot dimensions checked.

## 10. Non-goals

- No backend/server of any kind (entitlement, remote rules, AI all avoid it in this cycle).
- No app-chrome theming / Material You.
- No auto-merge of AI-generated fixes.
- No change to the free feature set — nothing currently free becomes paid.
