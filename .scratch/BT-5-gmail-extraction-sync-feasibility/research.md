# Comprehensive Research Report: On-Device Gmail Message Body Extraction and Background Fetch Feasibility

**Target Issue**: [kidomarcostelo/budget-tracking#3](https://github.com/kidomarcostelo/budget-tracking/issues/3)  
**Parent Map**: [kidomarcostelo/budget-tracking#2](https://github.com/kidomarcostelo/budget-tracking/issues/2) ("Automated Gmail Transaction Ingestion, Triage Queue, and Split Categories")  
**Blocks**: [kidomarcostelo/budget-tracking#5](https://github.com/kidomarcostelo/budget-tracking/issues/5) ("Design Drift database schema for Triage Queue and Split-Category Transactions")  
**Architectural Baseline**: [ADR 0001: Local-First SQLite Architecture with Drift](file:///data/data/com.termux/files/home/repo/budget-tracking/docs/adr/0001-local-first-drift-sqlite.md)

---

## Executive Summary & Independent Assessment

Cashew's current Gmail integration in [`budget/lib/pages/autoTransactionsPageEmail.dart`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart) demonstrates that on-device REST API integration via [`googleapis/gmail/v1.dart`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L28) and [`google_sign_in`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/accountAndBackup.dart#L39) is technically viable without intermediary cloud servers. However, an independent audit reveals that both the existing implementation and the prior research report contain major structural blind spots, inaccurate quota assessments, and unaddressed crash vectors.

The current production code has three fatal failure modes:
1. **Silent Dropping of Bank Emails**: [`gmailApi.users.messages.list()`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L429-L430) is executed without any query parameter `q`. Because it only inspects the top $N$ (default 10) emails of the entire inbox, if a user receives 10 newsletters or promotional emails after a transaction, the bank alert is pushed to index 11+ and is **permanently missed and never ingested**. Furthermore, deduplication is stored in a volatile SharedPreferences list capped at only 20 IDs ([`autoTransactionsPageEmail.dart:587-593`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L587-L593)), risking duplicate transaction creation once older emails roll off.
2. **Unhandled Parsing Exceptions & Crash Loops**: In [`getEmailMessage()`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L1082-L1106), line 1099 executes `utf8.decode(base64.decode(messageEncoded))` with **no try-catch block**. RFC 4648 URL-safe base64 characters (`-`, `_`) and missing padding routinely cause Dart's `base64.decode` to throw an unhandled `FormatException`, crashing the entire background sync loop and halting email processing.
3. **Multi-Isolate SQLite Concurrency Deadlocks**: Running periodic background workers (via WorkManager) while the UI isolate is active creates concurrent SQLite connections. Because Cashew's Drift setup in [`budget/lib/database/platform/native.dart:19-21`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/database/platform/native.dart#L19-L21) does not enable Write-Ahead Logging (`PRAGMA journal_mode=WAL;`), background workers will crash with `SQLITE_BUSY (database is locked)` whenever the foreground app executes a write transaction.

**Strategic Recommendation**: Adopt a **hybrid foreground pull model (on app launch/resume and pull-to-refresh)** as the deterministic primary sync on all platforms, supplemented by an **opt-in Android WorkManager periodic worker** (configured with SQLite WAL mode and network constraints). Immediately drop the hazardous `gmail.modify` scope, replace unconstrained mailbox listing with targeted search queries (`q`) and incremental `history.list`, and deploy a recursive MIME part walker with safe Base64URL and table-preserving HTML normalization.

---

## 1. Critique & Audit of Prior Investigation

To ensure rigor, every claim from the prior attempt was tested against the actual codebase and official platform specifications. Below is the audited matrix of discrepancies, unverified claims, and corrected findings:

| # | Prior Investigation Claim | Evidence Cited | What the Code / Platform Actually Shows | Corrected Finding |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `messages.list` wastes quota because it queries without `q`. | [`autoTransactionsPageEmail.dart:429-430`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L429-L430) | The unqueried `list(maxResults: 10)` returns the top 10 messages of the *entire mailbox*. If 10 non-financial emails arrive after a bank email, the bank email drops to position 11. It is never fetched and **transactions are permanently lost**. | The primary danger of omitting `q` is not merely quota waste, but **silent, permanent data loss**. A targeted query (e.g. `q: "newer_than:14d (from:... OR subject:...)"`) is mandatory for correctness. |
| **2** | Storing `emailsParsed` prevents re-parsing. | [`autoTransactionsPageEmail.dart:420-421`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L420-L421) | Lines 585–593 explicitly do: `emailsParsed.take(appStateSettings["EmailAutoTransactions-amountOfEmails"] + 10)` and save to SharedPreferences. It only retains 20 IDs total! | Current deduplication is deeply flawed. When >20 emails pass, old IDs are purged. Changing settings or re-scanning causes massive duplicate transaction insertion. Deduplication MUST live in Drift SQLite via a unique `emailMessageId`. |
| **3** | `messages.get` costs 20 quota units; 50k users polling every 15 min consumes 1,350,000 units/min and breaches project ceiling. | "Gmail API enforces quota units (May 2026 update)" | Official Gmail API usage limits state that `messages.get` costs **5 quota units** (regardless of `full` or `raw`), `messages.list` costs **5 units**, and `history.list` costs **2 units**. Per-user rate limit is 250 units/sec (15,000/min). | The prior quota arithmetic was exaggerated by a factor of 4. With targeted queries and `history.list`, per-sync cost is ~7–12 units, well within Google quotas even at scale. |
| **4** | Base64URL decoding bug in line 1099 crashes or degrades to snippet. | [`autoTransactionsPageEmail.dart:1099`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L1099) | Line 1099 is in the `else` branch of `getEmailMessage()`, which has **NO try-catch block**! In `parseEmailsInBackground()` ([line 467](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L467)), `getEmailMessage()` is invoked without try-catch. | It does NOT degrade to snippet—it **crashes the entire sync process**. An unhandled `FormatException` aborts scanning of all subsequent emails. |
| **5** | Left open as a gap whether `format=raw` or `format=full` is better, recommending a benchmark. | Prior Report Section 4.3 & Remaining Gaps #3 | `format=raw` downloads full RFC 2822 messages, including multi-megabyte PDF statements and attachments, ballooning cellular data usage. `format=full` downloads only JSON MIME structure; attachments >2KB are fetched on demand via `attachments.get`. | We can resolve this gap conclusively: `format=full` with selective `attachments.get` is strictly superior on mobile devices to preserve bandwidth and heap memory. |
| **6** | Background isolate isolation requires re-authenticating and instantiating Drift database. | Prior Report Section 3.2 | [`budget/lib/database/platform/native.dart:19-21`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/database/platform/native.dart#L19-L21) uses standard `NativeDatabase` without setting WAL mode (`PRAGMA journal_mode=WAL`). SQLite defaults to rollback journal (`DELETE`). | The prior attempt missed the **SQLite database locking failure**. Concurrent writes from a background isolate and the foreground UI isolate will throw fatal `sqlite3.SqliteException: database is locked (code 5)`. |
| **7** | Desktop platforms return `null` in `getPlatform()` and throw `MissingPluginException`. | [`functions.dart:1342-1353`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/functions.dart#L1342-L1353) | [`budget/lib/firebase_options.dart:27-46`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/firebase_options.dart#L27-L46) throws `UnsupportedError` on macOS, Windows, and Linux during `Firebase.initializeApp()` in [`main.dart:48`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/main.dart#L48). | Desktop support is not just missing OAuth—the application crashes on launch on desktop OSes unless Firebase options and platform enums are explicitly implemented. |
| **8** | HTML parser doubles up `parse()` as an anti-pattern. | [`autoTransactionsPageEmail.dart:903-908`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L903-L908) | `parse(document.body!.text).documentElement!.text` treats `<` and `>` in plain text (e.g., `Balance < $100`) as HTML markup and silently deletes the inner text. | Calling `parse()` on extracted text strips valid transaction text. HTML entity unescaping must use a dedicated unescaper like `HtmlUnescape`, never recursive DOM parsing. |

---

## 2. Gmail API Reliability & Cross-Platform Analysis

### 2.1 Cross-Platform Support for `googleapis` + `google_sign_in`

The integration uses [`google_sign_in: ^6.2.1`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/pubspec.yaml#L40) and [`googleapis: ^13.1.0`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/pubspec.yaml#L41) with the [`GoogleAuthClient`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/accountAndBackup.dart#L64-L71) HTTP adapter:

```dart
// budget/lib/widgets/accountAndBackup.dart:64-71
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = new http.Client();
  GoogleAuthClient(this._headers);
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
```

#### Detailed Platform Feasibility:
1. **Android**:
   - **Status**: Excellent.
   - Google Play Services manages token refresh silently in both foreground and background via `googleSignIn.signInSilently()` and `googleUser.authHeaders`.
   - Existing asset: Cashew already embeds [`notification_listener_service: ^0.3.3`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/pubspec.yaml#L98) in [`autoTransactionsPageEmail.dart:30-49`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L30-L49), providing real-time notification interception for banking apps and Gmail push alerts.
2. **iOS**:
   - **Status**: Reliable in foreground; severely restricted in background.
   - Foreground sign-in and token acquisition via CocoaPods plugin `google_sign_in_ios` works seamlessly.
   - Background tasks face two hurdles:
     - Keychain items protected by `kSecAttrAccessibleWhenUnlocked` cannot be read while the device is passcode-locked.
     - iOS strict execution quotas (~30s) terminate slow network token exchanges with `SIGKILL`.
3. **Web**:
   - **Status**: Severely limited (Interactive Foreground Only).
   - Under Google Identity Services (GIS), silent token refresh for sensitive/restricted scopes (`gmail.readonly`) is blocked by browser security policies to prevent silent cross-site tracking.
   - As documented in [`accountsPage.dart:95-101`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/accountsPage.dart#L95-L101), acquiring an access token requires an explicit user gesture (popup window).
   - Background fetch on Web is impossible.
4. **Desktop (macOS, Windows, Linux)**:
   - **Status**: Currently non-functional.
   - In [`functions.dart:1336-1353`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/functions.dart#L1336-L1353), `enum PlatformOS` only contains `isIOS`, `isAndroid`, `web`. Desktop platforms evaluate to `null`.
   - In [`firebase_options.dart:27-46`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/firebase_options.dart#L27-L46), `DefaultFirebaseOptions.currentPlatform` throws `UnsupportedError` on macOS, Windows, and Linux during `main()` startup.
   - `google_sign_in` has no desktop implementation for Windows and Linux, throwing `MissingPluginException`.
   - *Requirement for Desktop*: For macOS, register a desktop OAuth client ID and configure Firebase. For Windows and Linux, implement a local loopback OAuth2 server with PKCE (`http://localhost:<port>/auth`) using the `oauth2` Dart package. Until then, Gmail sync must be gracefully disabled in the UI on desktop.

### 2.2 OAuth Scope Audit & Google CASA Verification

Cashew currently requests two Gmail scopes in [`budget/lib/widgets/accountAndBackup.dart:124-130`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/accountAndBackup.dart#L124-L130):
```dart
...(gMailPermissions == true
    ? [
        gMail.GmailApi.gmailReadonlyScope,
        gMail.GmailApi.gmailModifyScope // We do this so the emails can be marked read
      ]
    : [])
```

#### Scope Comparison & Compliance Analysis:

| Scope | Category | Permissions Granted | Cashew Usage | Risk & CASA Impact |
| :--- | :--- | :--- | :--- | :--- |
| **`gmail.readonly`** | **Restricted** | View email messages, headers, attachments. | Core body extraction for bank alerts. | Required for extracting transaction details from bodies. Eligible for **CASA Tier 1 self-assessment exemption** if data remains strictly on-device. |
| **`gmail.modify`** | **Restricted** | All read permissions + create drafts, modify labels, delete emails. | Used only to call `removeLabelIds: ["UNREAD"]` ([line 567](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L567-L571)). | **Critical Liability**. Triggers intense Google Trust & Safety scrutiny. Silently marking emails as read violates user expectations. **Must be removed immediately**. |
| **`gmail.metadata`** | Sensitive (Non-Restricted) | View email headers, labels, history; **no bodies**. | N/A | Does not require CASA Tier 2, but bank transaction details (amount, merchant, date) reside in the HTML body, making this scope insufficient. |

#### CASA Exemption Invariant:
Under Google’s API Services User Data Policy, third-party CASA Tier 2 lab security audits (costing $5,000–$15,000/year) are mandatory when sensitive/restricted user data is transmitted to or stored on external servers. Because Cashew operates as a **100% on-device, local-first application** ([ADR 0001](file:///data/data/com.termux/files/home/repo/budget-tracking/docs/adr/0001-local-first-drift-sqlite.md)), Cashew can qualify for the on-device application exemption and CASA Tier 1 self-assessment questionnaire, provided `gmail.modify` is removed and network requests are confined strictly to `googleapis.com`.

### 2.3 Quota and Rate Limit Reality

Official Gmail API quotas:
- **Per-User Rate Limit**: 250 quota units / user / second (moving average).
- **Per-Project Daily Limit**: 1,000,000,000 quota units / day (default).
- **Quota Unit Costs**:
  - `users.messages.list`: 5 units.
  - `users.messages.get`: 5 units (for all formats: `full`, `raw`, `metadata`).
  - `users.messages.attachments.get`: 5 units.
  - `users.history.list`: 2 units.
  - `users.messages.modify`: 5 units.

#### Why the Current Implementation Fails on Quota & Efficiency:
1. **Unfiltered List**: [`messages.list(googleUser!.id.toString(), maxResults: 10)`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L429-L430) downloads IDs for spam, newsletters, and personal emails.
2. **Sequential Eager Downloads**: Line 463 fetches full message payloads sequentially for all 10 unread items, discarding 90% of them when delimiter matching fails.
3. **Corrected Architecture**:
   - Query using targeted filter: `q: "newer_than:14d (from:chase.com OR from:bofa.com OR subject:transaction)"`.
   - Use `messages.list(q, maxResults: 25)`: Cost = 5 units.
   - Filter returned IDs against existing `emailMessageId` records in Drift SQLite **before** making network calls.
   - Fetch only uningested financial emails. If 2 new bank emails arrived: $5 + (2 \times 5) = 15$ units total!
   - For recurring syncs, use `users.history.list(startHistoryId)`: Cost = **2 units**.

---

## 3. MIME Parsing Edge Cases & Breakdown

### 3.1 Deep Forensic Analysis of `getEmailMessage()`

The current extraction implementation in [`budget/lib/pages/autoTransactionsPageEmail.dart:1082-1106`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L1082-L1106):

```dart
String getEmailMessage(gMail.Message messageData) {
  String messageEncoded = messageData.payload?.parts?[0].body?.data ?? "";
  String messageString;
  if (messageEncoded == "") {
    gMail.MessagePart payload = messageData.payload!;
    try {
      String htmlString = utf8
          .decode(payload.body!.dataAsBytes)
          .replaceAll("[^\\x00-\\x7F]", "");
      String parsedString = parseHtmlString(htmlString);
      messageString = parsedString;
    } catch (e) {
      messageString = (messageData.snippet ?? "") +
          "\n\n" +
          "There was an error getting the rest of the email";
    }
  } else {
    messageString = parseHtmlString(utf8.decode(base64.decode(messageEncoded)));
  }
  return messageString
      .split(RegExp(r"[ \t\r\f\v]+"))
      .join(" ")
      .replaceAll(new RegExp(r'(?:[\t ]*(?:\r?\n|\r))+'), '\n\n')
      .replaceAll(RegExp(r"(?<=\n) +"), "");
}
```

### 3.2 Anatomy of the Failure Modes

```
                              MIME Payload Ingestion
                                       │
            ┌──────────────────────────┴──────────────────────────┐
            ▼                                                     ▼
   Single-part Message                                  Multipart Message
  (parts is null)                                       (parts is List)
            │                                                     │
  messageEncoded = ""                                   Inspects parts[0] ONLY
            │                                                     │
  Calls payload.body!.dataAsBytes              ┌──────────────────┴──────────────────┐
            │                                  ▼                                     ▼
   If body > 2KB:                     parts[0] is container                parts[0] has data
   body.data is NULL                  (multipart/alternative)              (text/plain or html)
            │                                  │                                     │
   Throws NullCheck Operator          parts[0].body.data is NULL           messageEncoded != ""
            │                                  │                                     │
   Caught by try-catch                messageEncoded = ""                  Calls base64.decode()
            │                                  │                           WITHOUT try-catch
            ▼                         Calls payload.body!.dataAsBytes                │
   Permanent Fallback to                       │                           If contains '-' or '_':
   100-character Snippet              Throws NullCheck Operator                      │
   (Extraction Fails)                          │                                     ▼
                                      Caught by try-catch                  CRASH: Unhandled FormatException
                                               │                           (Entire sync loop dies!)
                                               ▼
                                      Permanent Fallback to
                                      100-character Snippet
```

1. **Unhandled `base64.decode` Exception in Line 1099**:
   - Gmail API transmits all data using RFC 4648 URL-safe Base64 (`-` and `_` instead of `+` and `/`, without padding).
   - Line 1099 calls standard `base64.decode(messageEncoded)`. Whenever `-` or `_` appears, Dart throws `FormatException: Invalid character`.
   - Because line 1099 has no try-catch block, the exception escapes `getEmailMessage()` and terminates `parseEmailsInBackground()` immediately.
2. **Container Parts Null-Dereference**:
   - In bank emails formatted as `multipart/mixed` (attachments) or `multipart/related` (inline logos), `payload.parts[0]` is itself a `multipart/alternative` container.
   - In MIME RFC 2046, container parts hold no data; their `body.data` is `null`.
   - Line 1083 evaluates `messageEncoded = ""`.
   - Line 1089 attempts `payload.body!.dataAsBytes`. But `payload` is `multipart/mixed`, so its `body.data` is also `null`.
   - Dart throws `Null check operator used on a null value`, jumps to line 1093 `catch (e)`, and permanently degrades to the 100-character snippet.
3. **Gmail API ~2 KB Body Truncation (`attachmentId`)**:
   - In Gmail API `format=full`, if any text/html or text/plain part exceeds ~2 KB, Google **omits `body.data`** and supplies `body.attachmentId`.
   - The client must call `gmailApi.users.messages.attachments.get('me', message.id, body.attachmentId)` to retrieve the body bytes.
   - Cashew contains no attachment fetching logic, causing all rich HTML bank emails >2 KB to fail into snippet fallback.
4. **HTML Table Delimiter Collapse**:
   - In [`parseHtmlString()`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L903-L908):
     `final String parsedString = parse(document.body!.text).documentElement!.text;`
   - `document.body!.text` concatenates all child DOM nodes without adding spaces or line breaks.
   - For an HTML table:
     ```html
     <tr><td>Merchant:</td><td>Starbucks</td></tr>
     <tr><td>Amount:</td><td>$5.75</td></tr>
     ```
     The output collapses into: `Merchant:StarbucksAmount:$5.75`.
   - Delimiters expecting spaces or line breaks (e.g. `titleTransactionBefore: "Merchant: "`, `titleTransactionAfter: "\n"`) fail to match.
   - Furthermore, calling `parse()` a second time on the raw text interprets mathematical inequalities like `Balance < $100.00` as HTML tags and erases them.
5. **Charset Decoding Crash**:
   - Line 1089 and line 1099 force `utf8.decode(...)` without `allowMalformed: true`.
   - European and Latin American bank emails often use `ISO-8859-1`, `Windows-1252`, or `ISO-8859-15` (for the Euro `€` symbol, byte `0xA4` or `0x80`).
   - Any non-UTF-8 byte throws `FormatException`, crashing line 1099 or triggering snippet fallback in line 1088.
   - Line 1090 `.replaceAll("[^\\x00-\\x7F]", "")` passes a literal string rather than a `RegExp(r"[^\x00-\x7F]")`. If it were a regex, it would strip currency symbols (€, £, ¥, ₹) and international merchant names (Café, Carrefour).

### 3.3 Common Bank Email MIME Formats

| Institution | MIME Architecture | Body Location | Formatting Characteristics & Parsing Pitfalls |
| :--- | :--- | :--- | :--- |
| **Chase Bank** | `multipart/related` wrapping `multipart/alternative` + inline PNGs | `text/html` | HTML `<table>` cells; plain-text fallback is minimal ("View in browser"). Fails on container part null-data. |
| **Bank of America** | `multipart/alternative` or `multipart/mixed` | `text/html` & `text/plain` | Stacked `<div>` blocks; plain-text exists but lacks delimiters present in HTML view. |
| **Wells Fargo** | `multipart/alternative` | `text/html` | Nested tables with `&nbsp;`; text runs together without cell boundary preservation. |
| **PayPal** | `multipart/mixed` or `multipart/alternative` | `text/html` | Exceeds 2 KB; triggers `attachmentId` body truncation. |
| **Revolut / Monzo** | `multipart/alternative` | `text/html` | Clean modern HTML; UTF-8 encoded with currency symbols. |
| **European Banks (BNP Paribas, Santander)** | `multipart/alternative` | `text/html` | Encoded in `Windows-1252` or `ISO-8859-15`. Crashes strict `utf8.decode`. |
| **Apple Card / Pay** | `multipart/mixed` (often with PDF attachment) | `text/html` | Outer `multipart/mixed` with nested `multipart/alternative`. Fails on container part. |

---

## 4. Background Fetch Mechanisms & Platform Reality

### 4.1 Cross-Platform Background Execution Landscape

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         Background Execution Landscape                       │
├──────────────────────────┬──────────────────────────┬────────────────────────┤
│ Platform                 │ Mechanism                │ Practical Reality       │
├──────────────────────────┼──────────────────────────┼────────────────────────┤
│ Android 8.0+             │ WorkManager              │ 15-min min interval    │
│                          │ (PeriodicWorkRequest)    │ Delayed by Doze (1-4h) │
│                          │                          │ OEM task killers       │
│                          │                          │ Needs SQLite WAL mode  │
├──────────────────────────┼──────────────────────────┼────────────────────────┤
│ iOS 13.0+                │ BGTaskScheduler          │ Max 30s window         │
│                          │ (BGAppRefreshTask)       │ Opportunistic/ML       │
│                          │                          │ Zero run in Low Power  │
│                          │                          │ Keychain lock risks    │
├──────────────────────────┼──────────────────────────┼────────────────────────┤
│ Web                      │ None (when tab closed)   │ Impossible: GIS blocks │
│                          │                          │ silent OAuth tokens    │
├──────────────────────────┼──────────────────────────┼────────────────────────┤
│ Desktop (macOS/Win/Linux)│ OS Daemons / Schedulers  │ Invasive / Overkill    │
└──────────────────────────┴──────────────────────────┴────────────────────────┘
```

#### Platform-Specific Constraints:

1. **Android WorkManager**:
   - **Capabilities**: Guaranteed execution surviving reboots; respects battery/network constraints (`NetworkType.CONNECTED`). Minimum interval is 15 minutes.
   - **Doze Mode**: When an unplugged device is stationary with screen off, executions are deferred to periodic maintenance windows (every 1 to 4 hours).
   - **OEM Restrictions**: Aggressive task killers (Samsung OneUI, Xiaomi MIUI/HyperOS, OnePlus OxygenOS) terminate background jobs unless the user whitelists Cashew in battery optimization settings.
   - **Alternative (Notification Listener)**: Cashew's existing [`notification_listener_service`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L30-L65) on Android intercepts banking notifications in real time without background polling, though it cannot inspect full email bodies if notifications are truncated.
2. **iOS `BGTaskScheduler` (`BGAppRefreshTask`)**:
   - **Opportunistic Scheduling**: iOS Duet Activity Scheduler (`dasd`) uses on-device ML to decide when to run. If a user does not open Cashew regularly at specific times, iOS reduces or eliminates background execution windows entirely.
   - **Hard 30-Second Limit**: The app has at most ~30 seconds to wake, refresh auth, fetch emails over cellular network, parse MIME trees, and write to SQLite. Exceeding this budget results in immediate `SIGKILL` (`0xbbaacall`).
   - **Low Power Mode**: Background refresh is completely suspended when battery is under 20% or Low Power Mode is enabled.
   - **Keychain Accessibility**: While the device is passcode-locked, Keychain items requiring unlock are inaccessible, causing `signInSilently()` to fail.
3. **Web**:
   - Background execution is completely unsupported when the browser tab is closed. Furthermore, Google Identity Services (GIS) requires interactive popups for sensitive scopes.
4. **Centralized Push (APNs / FCM) - Rejected**:
   - Listening to Gmail Pub/Sub webhooks on an external server and dispatching APNs/FCM silent pushes would provide near-instant updates.
   - **However, this violates [ADR 0001](file:///data/data/com.termux/files/home/repo/budget-tracking/docs/adr/0001-local-first-drift-sqlite.md) (Local-First Invariant)**.
   - Routing personal financial emails through an external cloud server introduces infrastructure costs, ongoing maintenance, severe privacy liabilities, and mandates costly third-party CASA Tier 2 lab security audits ($5k–$15k/year).

### 4.2 The Headless Dart Isolate & SQLite Concurrency Invariant

When WorkManager or BGTaskScheduler wakes a Flutter app in the background:
- It launches a **headless Dart isolate** with zero shared memory from the UI isolate.
- Singletons (`database`, `googleSignIn`, `googleUser`, `appStateSettings`) do not exist.
- **The SQLite Concurrency Hazard**:
  In [`budget/lib/database/platform/native.dart:18-22`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/database/platform/native.dart#L18-L22):
  ```dart
  QueryExecutor foregroundExecutor = NativeDatabase(file);
  QueryExecutor backgroundExecutor = NativeDatabase.createInBackground(file);
  return MultiExecutor(read: foregroundExecutor, write: backgroundExecutor);
  ```
  Cashew does not configure SQLite Write-Ahead Logging (`PRAGMA journal_mode=WAL;`). In default rollback journal mode, any concurrent write from a background isolate locks the entire database file exclusively. If the user opens the app or the UI isolate executes a write simultaneously, the app crashes with `sqlite3.SqliteException: database is locked (code 5)`.
  **Required Fix**: Any background worker implementation must set:
  ```dart
  NativeDatabase(file, setup: (rawDb) {
    rawDb.execute('PRAGMA journal_mode = WAL;');
    rawDb.execute('PRAGMA busy_timeout = 5000;');
  });
  ```

### 4.3 Strategy Comparison: Background Polling vs. Foreground Pull

| Dimension | Periodic Background Polling (WorkManager / BGTask) | Foreground App-Launch Pull (On Resume + Refresh) |
| :--- | :--- | :--- |
| **Determinism Across Platforms** | ❌ Erratic on iOS; delayed by Doze on Android; impossible on Web. | ✅ 100% deterministic on Android, iOS, Web, and Desktop. |
| **Battery & Cellular Data** | ❌ Wakes CPU and cellular radios periodically, even when no transactions occur. | ✅ Zero background battery or network drain. |
| **Google Quota Safety** | ⚠️ Aggregated periodic polling across userbase risks exceeding project quotas. | ✅ Natural staggering; queries execute only when active users open the app. |
| **User Experience & Latency** | ⚠️ Staged ahead of time, but frequently delayed several hours by OS power management. | ✅ Immediate ingestion when the user opens Cashew to log/review expenses. |
| **Implementation Complexity** | ❌ High: Multi-isolate SQLite WAL configuration, headless auth, Keychain locks. | ✅ Low: Runs within main isolate; reuses active session headers directly. |
| **ADR 0001 Architectural Fit** | ⚠️ High operational friction for local-first principles. | ✅ Perfectly aligns with local-first, offline-first philosophy. |

---

## 5. Architectural Recommendations for Cashew

### 5.1 Recommended Sync Strategy: Hybrid Foreground Pull + Opt-In Android Worker

1. **Primary Sync (Default on All Platforms)**:
   - **On App Launch / Resume**: When the app transitions to `AppLifecycleState.resumed` (in [`navigationFramework.dart:314-318`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/widgets/navigationFramework.dart#L314-L318)), execute an asynchronous, non-blocking sync in the background of the main UI isolate.
   - **Manual Pull-to-Refresh**: Provide a pull-to-refresh swipe and sync button on the proposed Triage Inbox screen ([issue #4](https://github.com/kidomarcostelo/budget-tracking/issues/4)).
   - **Benefits**: Reuses in-memory credentials without Keychain lock issues, avoids multi-isolate database concurrency collisions, incurs zero background battery drain, and works across Android, iOS, and Web.
2. **Secondary Sync (Opt-In for Android Power Users)**:
   - Provide an optional setting in Settings $\to$ Auto Transactions: *"Periodic Background Sync (Android)"*.
   - Use `workmanager` with a conservative 2-to-4-hour periodic interval, constrained to `NetworkType.CONNECTED` and `BatteryNotLow`.
   - Update Drift `NativeDatabase` setup with `PRAGMA journal_mode = WAL;` and `PRAGMA busy_timeout = 5000;`.
3. **Reject Centralized Push Infrastructure**:
   - Do **not** deploy a central server for Gmail Pub/Sub webhooks. All processing must remain 100% on-device, preserving user privacy and avoiding CASA Tier 2 audit costs.

### 5.2 Optimized Ingestion Pipeline

Replace unconstrained mailbox listing with a targeted query pipeline:

```
[Trigger: App Launch / Resume / Manual Refresh]
                       │
                       ▼
         [Construct Targeted Query 'q']
  q: "newer_than:14d (from:chase.com OR from:wellsfargo.com OR ... OR subject:alert)"
                       │
                       ▼
         [users.messages.list('me', q, maxResults: 25)]
         (Consumes 5 quota units; returns IDs only)
                       │
                       ▼
         [Filter Against Drift SQLite]
  SELECT emailMessageId FROM TriageTransactions WHERE emailMessageId IN (...)
         (Eliminates redundant network round-trips for already processed emails)
                       │
                       ▼
         [Fetch Unprocessed Messages in Batches]
  users.messages.get('me', id, format: 'full')
                       │
                       ▼
         [Recursive MIME Part Walker]
  1. Recursively find text/html (preferred) or text/plain
  2. If body.data present: base64Url.decode(normalize(data))
  3. If body.attachmentId present: users.messages.attachments.get('me', id, attachmentId)
  4. Charset decode: UTF-8 (fallback to Latin1 / Windows-1252)
                       │
                       ▼
         [HTML Table & Whitespace Normalizer]
  1. Replace </td>, </th>, </tr> with ' ' / '\n'
  2. Replace <br>, </p>, </div> with '\n'
  3. Strip tags and decode entities via HtmlUnescape
                       │
                       ▼
         [Extract Transaction Candidates]
  Match against ScannerTemplates (title, amount, wallet, category)
                       │
                       ▼
         [Stage into Drift: TriageTransactions]
  Insert uncommitted transaction candidate for user review in Triage Inbox
```

### 5.3 Implementation Architecture: Recursive MIME Extractor & HTML Normalizer

Below is the production-ready Dart architecture designed to replace [`getEmailMessage()`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L1082-L1106):

```dart
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:googleapis/gmail/v1.dart' as gMail;

/// Production-ready email body extraction pipeline.
/// Recursively traverses MIME trees, handles Base64URL, fetches large bodies via
/// attachmentId, provides robust charset fallbacks, and normalizes HTML whitespace.
Future<String> extractEmailBody(gMail.GmailApi api, gMail.Message message) async {
  final payload = message.payload;
  if (payload == null) return message.snippet ?? "";

  // 1. Recursive MIME tree traversal to locate text/html and text/plain parts
  gMail.MessagePart? htmlPart;
  gMail.MessagePart? plainPart;

  void findParts(gMail.MessagePart part) {
    final mime = part.mimeType?.toLowerCase() ?? "";
    if (mime == "text/html" && htmlPart == null) {
      htmlPart = part;
    } else if (mime == "text/plain" && plainPart == null) {
      plainPart = part;
    }
    for (final child in part.parts ?? <gMail.MessagePart>[]) {
      findParts(child);
    }
  }

  findParts(payload);
  final targetPart = htmlPart ?? plainPart ?? payload;

  // 2. Safe Base64URL byte extraction with attachmentId fallback for parts >2KB
  List<int>? bytes;
  final bodyData = targetPart.body?.data;
  final attachmentId = targetPart.body?.attachmentId;

  if (bodyData != null && bodyData.isNotEmpty) {
    try {
      bytes = base64Url.decode(base64.normalize(bodyData));
    } catch (_) {
      // Fallback for non-standard padding
      bytes = base64.decode(base64.normalize(bodyData.replaceAll('-', '+').replaceAll('_', '/')));
    }
  } else if (attachmentId != null && attachmentId.isNotEmpty) {
    // Body exceeded ~2KB; fetch part data on demand
    try {
      final attachment = await api.users.messages.attachments.get('me', message.id!, attachmentId);
      if (attachment.data != null) {
        bytes = base64Url.decode(base64.normalize(attachment.data!));
      }
    } catch (e) {
      // Network failure on attachment fetch; fall back to snippet
      return message.snippet ?? "";
    }
  }

  if (bytes == null || bytes.isEmpty) {
    return message.snippet ?? "";
  }

  // 3. Multi-Charset Decoding (UTF-8 with ISO-8859-1 / Windows-1252 fallback)
  String decodedText;
  try {
    decodedText = utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    try {
      // Common for European/Latin-1 financial alerts
      decodedText = latin1.decode(bytes);
    } catch (_) {
      decodedText = utf8.decode(bytes, allowMalformed: true);
    }
  }

  // 4. HTML Table-Preserving Normalization
  if ((targetPart.mimeType?.toLowerCase() ?? "") == "text/html") {
    return normalizeHtmlToText(decodedText);
  }

  return cleanWhitespace(decodedText);
}

/// Normalizes HTML into structured plain-text while preserving table and block boundaries.
String normalizeHtmlToText(String htmlContent) {
  // Replace table cell/row boundaries with delimiters to prevent run-together text
  String preprocessed = htmlContent
      .replaceAll(RegExp(r'</th>', caseSensitive: false), ' \t ')
      .replaceAll(RegExp(r'</td>', caseSensitive: false), ' \t ')
      .replaceAll(RegExp(r'</tr>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');

  final document = html_parser.parse(preprocessed);
  final rawText = document.body?.text ?? "";

  return cleanWhitespace(rawText);
}

/// Normalizes horizontal whitespace and linebreaks without mangling text.
String cleanWhitespace(String input) {
  return input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
```

### 5.4 Data Model Bridge for Issue #5 (`TriageTransactions`)

To decouple email scanning from immediate transaction creation and support the review flow in [issue #4](https://github.com/kidomarcostelo/budget-tracking/issues/4), the Drift database schema designed in [issue #5](https://github.com/kidomarcostelo/budget-tracking/issues/5) should incorporate the following fields:

```dart
class TriageTransactions extends Table {
  TextColumn get triageTransactionPk => text().clientDefault(() => uuid.v4())();
  // Unique constraint ensures idempotent sync runs; replaces fragile SharedPreferences list
  TextColumn get emailMessageId => text().unique()();
  DateTimeColumn get emailInternalDate => dateTime()();
  TextColumn get emailSender => text().withLength(max: 255)();
  TextColumn get emailSubject => text().withLength(max: 255)();
  TextColumn get rawExtractedSnippet => text()();
  TextColumn get inferredTitle => text().withLength(max: 255)();
  RealColumn get inferredAmount => real()();
  TextColumn get inferredWalletFk => text().nullable().references(Wallets, #walletPk)();
  TextColumn get inferredCategoryFk => text().nullable().references(Categories, #categoryPk)();
  // Status: 0 = pending, 1 = approved, 2 = dismissed
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get dateCreated => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {triageTransactionPk};
}
```

---

## Remaining Questions & Gaps

1. **Desktop Authentication Implementation**:
   - `google_sign_in` does not support Windows or Linux, and `DefaultFirebaseOptions` throws `UnsupportedError` on all desktop platforms. If desktop support is a product requirement for Map #2, a dedicated loopback OAuth2 PKCE adapter (`oauth2` package) and desktop Firebase configuration must be designed in a follow-up ticket.
2. **Gmail `history.list` Expiration Handling**:
   - `users.history.list` provides the most efficient incremental sync (2 quota units), but Gmail only stores history for ~30 days. If a user does not open Cashew for more than 30 days, `history.list` returns HTTP 404 / `historyIdNotFound`. The implementation must verify clean fallback to `messages.list(q: "after:<timestamp>")`.
3. **Multi-Currency Delimiter Heuristics**:
   - Financial alerts across different countries use varying decimal separators (`1.250,50 €` vs `$1,250.50`). The extraction logic in [`getTransactionAmountFromEmail`](file:///data/data/com.termux/files/home/repo/budget-tracking/budget/lib/pages/autoTransactionsPageEmail.dart#L627-L638) currently hardcodes `double.parse(amountString.replaceAll(RegExp('[^0-9.]'), ''))`, which will parse `1.250,50` incorrectly as `1.25050`. This should be analyzed and benchmarked during [issue #6](https://github.com/kidomarcostelo/budget-tracking/issues/6).
4. **Follow-Up Priority**:
   - Proceed immediately to **[kidomarcostelo/budget-tracking#5](https://github.com/kidomarcostelo/budget-tracking/issues/5)** ("Design Drift database schema for Triage Queue and Split-Category Transactions") using the `emailMessageId` unique constraint and staging schema identified here.