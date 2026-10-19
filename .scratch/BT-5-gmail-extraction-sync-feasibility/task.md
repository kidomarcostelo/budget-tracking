# Task: Evaluate on-device Gmail message body extraction and background fetch feasibility

**ID:** BT-5  
**Issue Reference:** [#3](https://github.com/kidomarcostelo/budget-tracking/issues/3)  
**Parent Map:** [#2](https://github.com/kidomarcostelo/budget-tracking/issues/2)  
**Status:** Complete (Research & Feasibility Spec Approved)  
**Assignee:** Agent

---

## 1. Objective & Scope

- **Problem Statement:**  
  Cashew's existing Gmail scanning implementation in `budget/lib/pages/autoTransactionsPageEmail.dart` was a fragile proof-of-concept. It:
  1. Requested invasive write scopes (`gmail.modify`) solely to mark emails as read, risking user trust and Google verification rejection.
  2. Called `messages.list()` without search queries `q`, silently dropping bank receipts whenever 10+ unrelated emails arrived.
  3. Threw unhandled `FormatException` on RFC 4648 URL-safe base64 characters (`-`, `_`) and missing padding, crashing sync loops.
  4. Deduplicated using a 20-element volatile SharedPreferences list that rolled off, risking duplicate transaction insertions.
  5. Had no multi-isolate concurrency protection for SQLite when running background workers alongside foreground UI.
- **Expected Outcome:**  
  Establish a verified, production-grade technical architecture for on-device Gmail financial transaction ingestion, MIME parsing, and background synchronization that strictly preserves Cashew's local-first privacy model ([ADR 0001](file:///data/data/com.termux/files/home/repo/budget-tracking/docs/adr/0001-local-first-drift-sqlite.md)).

---

## 2. Invariants & Constraints

- **Local-First Invariant ([ADR 0001](../../docs/adr/0001-local-first-drift-sqlite.md)):** 100% on-device processing. No intermediary servers, external cloud AI parsing, or third-party email ingestion relays.
- **Google OAuth Privacy Bar:** Restrict scopes to `gmail.readonly`. Drop `gmail.modify`. Under CASA (Cloud Application Security Assessment), Cashew qualifies for Tier 1 self-assessment exemption because email data remains strictly on-device in local SQLite.
- **Database Concurrency:** Background isolates running Drift SQLite queries must use Write-Ahead Logging (`PRAGMA journal_mode = WAL;`) to prevent `SQLITE_BUSY: database is locked` exceptions when concurrent foreground UI writes occur.
- **Deduplication:** Repeated delivery of the same email must be prevented by a unique `emailMessageId` constraint in the Drift staging table (`TriageTransactions`), entirely replacing SharedPreferences.

---

## 3. Key Findings & Architecture Decisions

Full detailed research and code audits are documented in [`research.md`](research.md) and posted to GitHub [#3](https://github.com/kidomarcostelo/budget-tracking/issues/3#issuecomment-6266070560).

1. **API Scopes & Targeted Querying:**
   - Use `gmail.readonly` only.
   - Use targeted queries: `q: "newer_than:14d (from:... OR subject:...)"` or query templates derived from active `ScannerTemplate` records.
   - For incremental updates, use `users.history.list` with graceful fallback to `after:<timestamp>` when the 30-day history window expires.
2. **Robust MIME Extraction Pipeline:**
   - Normalize Base64URL encoding (`-` -> `+`, `_` -> `/`, restore missing `=` padding) wrapped in defensive try-catch.
   - Recursive multipart traversal prioritizing `text/html` then `text/plain`.
   - Attachment fallback: when `parts.body.size > 2048`, retrieve full body via `users.messages.attachments.get`.
   - Multi-charset decoding: fallback cascade from UTF-8 to Latin-1/Windows-1252.
   - Table delimiter normalization: preserve table boundaries (`</td>`, `</th>`, `<tr>`) with whitespace/newlines before HTML stripping to prevent text collapse like `Merchant:StarbucksAmount:.75`.
3. **Hybrid Sync Architecture:**
   - **Primary (Default):** Foreground pull on app launch / resume (`AppLifecycleState.resumed`) and manual pull-to-refresh in the Triage Inbox. Deterministic, zero battery overhead, no Keychain lockouts.
   - **Immediate Wake-Up (Android):** `notification_listener_service` triggers a lightweight local wake-up signal upon arrival of a Gmail or Bank push notification, immediately fetching the full email body and staging it.
   - **Periodic Fallback (Opt-in Android):** WorkManager periodic task (2–4 hours, `NetworkType.CONNECTED`).

---

## 4. Plan & Implementation Steps

- [x] Audit existing `autoTransactionsPageEmail.dart` for silent drops, rate limits, and crash vectors.
- [x] Investigate Google OAuth CASA tier requirements and scope boundaries (`gmail.readonly` vs `gmail.modify`).
- [x] Benchmark and design robust MIME extraction handling Base64URL, large attachments, table spacing, and character sets.
- [x] Formulate cross-platform sync strategy (foreground pull + notification trigger + optional WorkManager).
- [x] Define staging schema fields needed for [Issue #5](https://github.com/kidomarcostelo/budget-tracking/issues/5).
- [ ] Implement `GmailMessageExtractor` service module with unit test fixtures.
- [ ] Replace `gmail.modify` scope in `accountAndBackup.dart`.
- [ ] Enable Drift SQLite WAL mode in `native.dart`.

---

## 5. Acceptance & Verification

- [x] Citations and verified facts documented against real codebase lines in `research.md`.
- [x] All 3 fatal failure modes (unconstrained list, base64 crash, SQLite concurrency) documented with concrete mitigations.
- [x] Resolution posted to [#3](https://github.com/kidomarcostelo/budget-tracking/issues/3).
- [x] Unblocks Drift staging table design in [#5](https://github.com/kidomarcostelo/budget-tracking/issues/5).

---

## Links

- GitHub Issue: [#3](https://github.com/kidomarcostelo/budget-tracking/issues/3)
- Parent Map: [#2](https://github.com/kidomarcostelo/budget-tracking/issues/2)
- Downstream Tickets: [#4](https://github.com/kidomarcostelo/budget-tracking/issues/4), [#5](https://github.com/kidomarcostelo/budget-tracking/issues/5), [#6](https://github.com/kidomarcostelo/budget-tracking/issues/6)
- Full Research Report: [`research.md`](research.md)
- Architectural Decision Record: [`ADR 0001: Local-First SQLite`](../../docs/adr/0001-local-first-drift-sqlite.md)
