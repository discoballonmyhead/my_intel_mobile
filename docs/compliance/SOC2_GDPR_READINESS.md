# SOC 2 & GDPR Readiness Survey — MINT mobile client

**Date:** 2026-11-12
**Scope:** this repository only (`my_intel_mobile`, Flutter client, commit `6e47671`).
**Method:** static review of source, config, CI and platform manifests. No running system, backend, cloud console or company policies were examined.

> **Important scope limit.** Most SOC 2 and GDPR obligations are met by the
> backend (Supabase Postgres + RLS, storage policies, edge functions such as
> `anthropic-proxy`), the admin app, the web app, and company processes
> (policies, HR, vendor management). None of those are in this repo. This
> survey says what the *mobile client* shows, flags where it creates risk,
> and lists what must be verified elsewhere. It is a readiness survey, not an
> audit opinion or legal advice.

---

## 1. Executive summary

| Area | Readiness | One-line verdict |
|---|---|---|
| Secrets & config hygiene | 🟢 Good | No secrets committed; build refuses service-role keys. |
| Encryption (messaging) | 🟡 Mixed | Strong E2EE design, but DM **attachments are uploaded unencrypted to a public bucket**. |
| Access control (client side) | 🟢 Good | Per-user RPCs, storage writes limited to the user's own folder, live sanction/role updates. Server RLS not verifiable here. |
| Change management / CI | 🔴 Gap | CI workflow exists but is **not enabled** (`ci/flutter_ci.yml` not in `.github/workflows/`). No code-owner or branch-protection evidence. |
| Logging & monitoring | 🔴 Gap | No crash reporting, no audit/security event logging in the client; debug logs include user IDs and search queries. |
| GDPR transparency | 🔴 Gap | Sign-up says "you agree to the Terms and Privacy Policy" but **neither document exists or is linked** (`auth_page.dart:188` TODO). |
| GDPR data-subject rights | 🟡 Partial | In-app account deletion ✅; no data export/access, no consent management beyond the compass. |
| Special-category data (Art. 9) | 🟡 Partial | Political-leaning "compass" has consent timestamp and delete-on-disable ✅, but needs explicit-consent wording, DPIA and documented legal basis. |
| Lawful access / escrow disclosure | 🟡 Partial | "Governance" escrow lets a threshold of key-holders decrypt DMs. Technically well guarded; must be disclosed in the privacy policy and governed. |
| Sub-processors / transfers | 🟡 Unknown | Supabase, Anthropic (AI), Vercel, Google Fonts identified — DPAs/SCCs/RoPA not evidenced. |

**Top 5 actions (do these first):**
1. Encrypt DM attachments client-side before upload, or move them to a private bucket with short-lived signed URLs (§4.1).
2. Publish a Privacy Policy and Terms, link them at sign-up and in Settings, and record acceptance (version + timestamp) server-side (§5.1).
3. Turn on CI (move `ci/flutter_ci.yml` to `.github/workflows/`), add branch protection with required review + passing checks (§3.3).
4. Add a "Download my data" (Art. 15/20) flow and document deletion completeness, including storage objects and backups (§5.3).
5. Complete a DPIA covering the political compass, governance escrow and the OSINT/moderation features (§5.5).

---

## 2. System overview (as seen from the client)

- **App:** Flutter (Android, iOS, macOS, Windows, Linux, Web), package `app.statelesslabs.mintelspace`, display name "Mint".
- **Backend:** Supabase (Auth, PostgREST across `content`, `identity`, `media`, `admin` schemas, Realtime, Storage buckets `mint-media` and `videos`, Edge Functions).
- **Third parties called directly or indirectly:**
  - Supabase — auth, database, storage, realtime (processor).
  - Anthropic — via `anthropic-proxy` edge function for story headline/summary drafting (`story_ai_remote_data_source.dart`).
  - Vercel — hosts the web app used for share links (`env.dart:23`, `signit-app.vercel.app`).
  - Google Fonts — `google_fonts` package fetches fonts at runtime by default (sends IP address to Google).
- **Personal data handled:** email, password (via Supabase Auth), username/profile, avatar, follows, posts, comments, reactions, polls, saved posts, feed impressions, direct messages and attachments, E2EE key material, reports/moderation records, sanctions, OSINT analyst applications (channel, handle, portfolio, motivation), reporter-badge requests (notes, links), post region with latitude/longitude, and an inferred **political-leaning position** with history ("compass").

---

## 3. SOC 2 readiness (Trust Services Criteria)

Status key: ✅ evidence in repo · ⚠️ partial / risk found · ❌ gap · ❓ cannot assess from this repo.

### 3.1 CC6 — Logical & physical access

| Control | Status | Evidence / notes |
|---|---|---|
| No secrets in source | ✅ | No keys found in tree or history. `env.json`, `env/*.json`, `.env*`, `key.properties` are git-ignored. Config is injected with `--dart-define-from-file` (`.vscode/launch.json`). |
| Client refuses privileged keys | ✅ | `Env.usesServerKey` rejects `sb_secret_` and `service_role` JWTs (`lib/core/config/env.dart:36`). |
| Least-privilege data access | ✅ / ❓ | Most reads/writes go through RPCs that take no user id (e.g. `LeanRepository`, `account_delete_self`). Real enforcement depends on RLS and `SECURITY DEFINER` functions — **verify server-side**. |
| Storage write isolation | ✅ / ❓ | Uploads go to `{user_id}/…` paths; comment says storage only accepts writes to the sender's folder. Verify bucket policies. |
| Read isolation of private media | ❌ | DM attachments use `getPublicUrl` on `mint-media` (`messaging_remote_data_source.dart:101`). See §4.1. |
| Authentication strength | ⚠️ | Min. 8-char password enforced client-side with strength meter. **No MFA** found. No evidence of leaked-password checks or lockout (Supabase settings — verify). |
| Session revocation / role changes | ✅ | Realtime watch on `admin.sanctions` and `admin.user_roles` updates access live (`account_remote_data_source.dart`). |
| Privileged roles | ❓ | Roles `public/reporter/osint/moderator/admin` exist. Need evidence of admin provisioning, quarterly access reviews and joiner/mover/leaver process. |
| Local data at rest | ✅ | E2EE store is SQLite with every value sealed by AES-256-GCM; key in Keychain (`first_unlock_this_device`, not backed up) / Android Keystore (`e2ee_store_sqflite.dart`). |
| Release signing | ⚠️ | Android signing reads `key.properties` (ignored ✅). Release build silently gets a null signing config if the file is missing — fine for local, but document where the keystore lives, who can access it, and back-up. |

### 3.2 CC7 — System operations (monitoring, incident response)

| Control | Status | Notes |
|---|---|---|
| Crash / error reporting | ❌ | No Sentry/Crashlytics or equivalent. You can't detect or evidence production incidents from the client. If added, configure PII scrubbing. |
| Security event logging | ❓ | Sign-ins, password/email changes, deletions, role changes should be logged server-side (Supabase Auth audit log + DB audit triggers). Verify retention. |
| Logs free of personal data | ⚠️ | `dev.log` calls print user IDs, usernames and **raw search queries** (`profile_remote_data_source.dart:45–220`). `dart:developer` logs are stripped from release builds on most targets, but treat as hygiene debt; remove or redact. |
| Incident response plan | ❓ | No `SECURITY.md`, no vulnerability-disclosure contact. Add one. |
| Abuse / moderation operations | ✅ | Report flow, my-reports, community notes, sanctions exist — good evidence for operational processes. |

### 3.3 CC8 — Change management

| Control | Status | Notes |
|---|---|---|
| Automated tests | ✅ | Unit tests under `test/`, Maestro UI flows under `.maestro/`, a structured test plan (`testing/test_plan.yaml`). |
| CI enforced | ❌ | `ci/flutter_ci.yml` is **not active** — `ci/README.md` says it couldn't be written to `.github/workflows/`. Today nothing blocks a merge. |
| Lint gate strength | ⚠️ | CI runs `flutter analyze --no-fatal-infos --no-fatal-warnings`; consider failing on warnings for new code. |
| Peer review | ❓ | PRs are used (merge commits #13–#15) but no evidence of required reviewers, CODEOWNERS, or branch protection. Commit `6e47671` appears to be a direct push. |
| Dependency management | ⚠️ | `pubspec.lock` is **git-ignored**, so builds are not reproducible and auditors can't tie a release to exact dependency versions. Commit it (recommended for apps). Add Dependabot/Renovate and a vulnerability scan (`osv-scanner`). |
| Repo hygiene | ⚠️ | `android/.kotlin/errors/*.log` are committed build artefacts (harmless content, but add `.kotlin/` to `.gitignore`). `.vscode/settings.json` is a 760 KB dump of default VS Code settings — remove. |
| Release traceability | ❌ | No tags/releases or changelog tying store builds to commits. |

### 3.4 Availability, Confidentiality, Processing Integrity, Privacy (if in scope)

- **Availability:** client degrades gracefully (config error screen, metrics failures ignored). Backups, RPO/RTO, Supabase plan/region and DR testing — ❓ verify.
- **Confidentiality:** strong E2EE design (X25519/HKDF/AES-GCM, sender keys, message franking, PIN-protected backup with attempt limit and wipe). Weakened by public attachments (§4.1) and by escrow (§4.2), both of which must be documented.
- **Processing integrity:** governance keys must be signed by a pinned Ed25519 root; root change is refused (`e2ee_service.dart:373`). Good integrity control. Post edit history is retained and viewable — good.
- **Privacy criteria:** see GDPR section; the same gaps (notice, consent, access/export) apply to the SOC 2 Privacy category.

### 3.5 Organisation-level controls (not assessable here — required for SOC 2)

Information security policy set; risk assessment; vendor management with SOC 2 reports/DPAs for Supabase, Anthropic, Vercel, Apple/Google; HR controls (background checks, security training, NDAs); asset inventory; device management for staff laptops; business continuity plan; annual pen test; board/management oversight. Consider a compliance automation tool (Vanta, Drata, Secureframe) to collect evidence, and target a **SOC 2 Type I** first, then a 3–6 month Type II window.

---

## 4. Notable technical findings

### 4.1 🔴 DM attachments are not end-to-end encrypted and are publicly readable

`MessagingRepositoryImpl.uploadAttachment` uploads raw bytes to the `mint-media` bucket at `{userId}/{epochMillis}_{n}.{ext}` and returns `getPublicUrl(path)`. Only the URL travels inside the encrypted message.

- Anyone who obtains the URL (forwarding, logs, browser history, link previews) can read the file without signing in.
- Paths are predictable: user IDs are visible to other users, and the timestamp has millisecond granularity — enumeration is practical if the bucket allows listing or if an attacker narrows the time window.
- Users are told messaging is encrypted ("🔒 Encrypted message"), so this is a **transparency (GDPR Art. 5(1)(a), 13) and security-of-processing (Art. 32)** issue, and would be an exception in a SOC 2 Confidentiality test.

**Fix:** encrypt the file with a random key (AES-GCM) before upload and put key + nonce + hash in the encrypted payload; store in a **private** bucket and fetch with short-lived signed URLs. Same concern, lower severity, for post media in followers-only or deleted posts — confirm bucket policy and deletion of objects on post/account deletion.

### 4.2 🟡 Governance escrow of message plaintext

When the server reports governance as enabled, every outgoing message also carries a copy sealed to a platform "governance" key, which can be opened by a threshold (≥2) of key-holders (`e2ee_service.dart:354`, `escrow.dart`). Safeguards are good (threshold ≥2, root-signed keys, pinned root, refusal on root change, a "who can read this" notice via `governanceInfo()`).

GDPR/SOC 2 requirements: state this clearly in the privacy policy and in-app before first message; document the legal basis and the purposes it may be used for (e.g. lawful requests, child-safety); log and review every escrow opening; name the key-holders' roles; include it in the DPIA.

### 4.3 🟡 Location metadata in uploaded media

Photos picked via `ImagePicker` are re-encoded (`imageQuality: 85`), which usually but not reliably drops EXIF/GPS. Files picked via `FilePicker` (any type, including images and PDFs) are uploaded **as-is**, keeping GPS coordinates, device serials and author names. For an OSINT app where sources may be at risk, strip metadata client-side before upload and tell users. Posts also carry `regionLat/regionLng` — make the precision and visibility explicit.

### 4.4 🟢 Good practices worth keeping as audit evidence

- Config validation screen instead of crashing on missing env (`config_error_app.dart`).
- Typed RPC error mapping (`rpc_error_messages.dart`) avoids leaking raw DB errors to users.
- Compass: "Every call works on the caller's own data; no call takes a user id."
- Account deletion requires typed confirmation and explains what's erased vs. retained.

---

## 5. GDPR readiness

### 5.1 Transparency & notice (Art. 12–14) — ❌

- The sign-up screen claims agreement to "Terms" and "Privacy Policy", but they are plain styled text with a `TODO: link Terms and Privacy Policy once they exist` (`lib/features/auth/presentation/pages/auth_page.dart:188`). **There is no privacy notice.** This is the single biggest GDPR blocker and also blocks App Store / Play Store data-safety requirements.
- Settings has no "Privacy policy", "Terms" or "Contact DPO/privacy" entry.
- Also needed: Apple **privacy manifest** (`ios/Runner/PrivacyInfo.xcprivacy`) declaring required-reason APIs and collected data types; Google Play Data Safety form.

**Do:** write a layered privacy notice (controller identity, contact, purposes + legal bases per feature, recipients/sub-processors, transfers, retention, rights, complaint to supervisory authority, automated decision-making). Link it at sign-up and in Settings; store accepted version + timestamp server-side.

### 5.2 Lawful basis & consent (Art. 6, 7, 9) — ⚠️

| Processing | Likely basis | Status |
|---|---|---|
| Account, posts, messaging | Contract (6(1)(b)) | Needs documenting. |
| Feed impressions / ranking metrics (`feed_impressions.dart`, sent with ranking version) | Legitimate interest (6(1)(f)) | Needs an LIA and mention in notice; consider opt-out. |
| AI drafting via Anthropic | Contract / LI | Disclose that drafts are sent to an AI provider; confirm Anthropic DPA and zero-retention settings on the proxy. |
| Moderation, sanctions, reports | LI / legal obligation (DSA) | Document; reporters' identities retained "without your name" after deletion — define retention. |
| **Political compass** — inferred political opinion from likes | **Explicit consent (9(2)(a))** | Opt-in with `consented_at` ✅, delete-on-disable ✅, reset ✅. Need: explicit consent wording shown before enabling, consent text versioning, ability to withdraw as easily as given (✅ toggle), DPIA, and confirmation the server doesn't keep classifications after disable. |
| Google Fonts runtime fetch | — | Sends IP to Google without basis (German courts have fined for this on the web). Bundle fonts and set `GoogleFonts.config.allowRuntimeFetching = false`. |
| Escrow copies of DMs | LI / legal obligation | See §4.2. |

### 5.3 Data subject rights (Art. 15–22) — ⚠️

| Right | Status |
|---|---|
| Access (15) / Portability (20) | ❌ No "download my data". Add an RPC + edge function that exports JSON (profile, posts, comments, reactions, follows, messages metadata, reports filed, compass history, applications). |
| Rectification (16) | ✅ Edit profile, username, email (with confirmation), post edit. |
| Erasure (17) | ✅ In-app delete (`account_delete_self`). **Verify server-side** that it also deletes storage objects under `{user_id}/`, auth user, impressions, compass data, E2EE key bundles/backups, and that backups age out within a documented window. Confirm local E2EE vault is wiped on device. |
| Restriction / objection (18, 21) | ⚠️ Compass can be turned off; no objection to impression metrics/ranking. |
| Automated decision-making (22) | ⚠️ Credibility scores, trending ranker, AI-assisted moderation (if any) — disclose logic; ensure sanctions have human review and appeal. |
| Channel for requests | ❌ No privacy contact in app. "Send feedback" is not an adequate DSAR channel. |

### 5.4 Data minimisation & retention (Art. 5(1)(c),(e)) — ❓

No retention schedule visible. Define retention for: impressions, edit history, deleted messages ("show as deleted" — is ciphertext purged?), reports, sanctions, OSINT applications (incl. rejected), badge requests, compass trail, auth logs, backups. Debug logging of user IDs and search queries should be removed.

### 5.5 Security of processing & DPIA (Art. 25, 32, 35) — ⚠️

A DPIA is very likely **mandatory**: systematic processing of political opinions (special category), large-scale monitoring of public content, escrow of private communications, and OSINT content that may concern third parties not on the platform. Privacy-by-design positives: E2EE, device-only keys, compass self-scoped RPCs. Negatives: §4.1, §4.3, missing MFA.

### 5.6 Processors & international transfers (Art. 28, 44–49) — ❓

Build a sub-processor list with DPAs and transfer mechanism (SCCs / EU-US DPF) for: Supabase (and its region), Anthropic, Vercel, Google (Fonts, Play), Apple, email provider used by Supabase Auth, any analytics. Maintain a **Record of Processing Activities (Art. 30)**.

### 5.7 Children (Art. 8) — ❌

No age gate or minimum-age statement. Set a minimum age (13–16 depending on member state), state it in Terms, and add an age confirmation at sign-up.

### 5.8 Breach notification (Art. 33–34) — ❓

Need a 72-hour breach procedure, contact with the supervisory authority, and logging sufficient to scope a breach (ties to §3.2).

### 5.9 Third-party data in OSINT content

Analysts publish intelligence that may name or depict private individuals. Define an editorial/privacy policy, journalistic-exemption reliance (Art. 85, national law), a takedown/erasure route for non-users, and moderator guidance. The existing "Privacy — Shares private information" report reason is a good start.

---

## 6. Remediation backlog

| # | Item | Framework | Owner area | Effort | Priority |
|---|---|---|---|---|---|
| 1 | Encrypt DM attachments client-side; private bucket + signed URLs | GDPR 32, SOC2 C1/CC6 | Mobile + backend | M | P0 |
| 2 | Publish Privacy Policy & Terms; link at sign-up and Settings; record acceptance | GDPR 12–13 | Legal + mobile | M | P0 |
| 3 | Enable CI workflow; branch protection; required review; CODEOWNERS | SOC2 CC8 | Eng | S | P0 |
| 4 | DPIA (compass, escrow, OSINT, moderation) | GDPR 35 | Legal/DPO | M | P0 |
| 5 | Data export (Art. 15/20) | GDPR | Backend + mobile | M | P1 |
| 6 | Verify & document deletion completeness (storage, backups, keys) | GDPR 17 | Backend | S | P1 |
| 7 | Strip EXIF/metadata from all uploads | GDPR 25/32 | Mobile | S | P1 |
| 8 | Bundle Google Fonts; disable runtime fetching | GDPR 6 | Mobile | S | P1 |
| 9 | MFA (TOTP) for all users; mandatory for moderator/admin/osint | SOC2 CC6 | Backend + mobile | M | P1 |
| 10 | Crash reporting with PII scrubbing; server audit logs + retention | SOC2 CC7 | Eng | M | P1 |
| 11 | Commit `pubspec.lock`; Dependabot + OSV scan in CI | SOC2 CC8/CC7 | Eng | S | P1 |
| 12 | Escrow governance: disclosure, access log, holder roster, review | GDPR 5/13, SOC2 CC6 | Security + legal | M | P1 |
| 13 | Explicit-consent copy + versioning for compass | GDPR 9 | Product + mobile | S | P1 |
| 14 | Privacy contact / DSAR entry in Settings; `SECURITY.md` | GDPR 12, SOC2 CC2 | Mobile | S | P2 |
| 15 | Age gate + minimum age in Terms | GDPR 8 | Mobile + legal | S | P2 |
| 16 | iOS privacy manifest; Play Data Safety | Store policy | Mobile | S | P2 |
| 17 | Remove PII from `dev.log`; delete `.vscode/settings.json` dump and `.kotlin/` logs | Hygiene | Mobile | S | P2 |
| 18 | Retention schedule, RoPA, sub-processor list, DPAs/SCCs | GDPR 5/28/30/44 | Legal/ops | M | P2 |
| 19 | Policies, risk assessment, vendor mgmt, training — pick compliance tool, target SOC 2 Type I | SOC2 | Leadership | L | P2 |

---

## 7. Evidence to collect from outside this repo

- Supabase: RLS policies for every table in `content`, `identity`, `media`, `admin`; storage bucket policies; `SECURITY DEFINER` RPC source (esp. `account_delete_self`, compass RPCs, impressions); Auth settings (MFA, password policy, leaked-password protection, rate limits, email confirmation); project region; backup/PITR config; audit log retention.
- Edge functions: `anthropic-proxy` — auth check, rate limiting, input logging, Anthropic data-retention settings, model allow-list.
- Admin/web apps: admin access controls, governance key ceremony, escrow-opening logs.
- Company: policies, org chart, access reviews, vendor contracts, incident runbooks, training records.
