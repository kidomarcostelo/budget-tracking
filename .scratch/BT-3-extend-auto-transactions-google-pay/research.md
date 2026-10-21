# Google Pay / Google Wallet notification automation: feasibility research

Scope: primary sources only (Google/Android docs, plugin source, AOSP source, Play policy, Play listings). Secondary sources are labeled. No code was changed.

## Summary

- Package names: `com.google.android.apps.walletnfcrel` is Google Wallet and `com.google.android.apps.nbu.paisa.user` is "Google Pay: Save and Pay" (Play listing titles). Neither package is documented officially for notifications.
- No official source describes the text fields (merchant, amount, card last 4) of Wallet or Pay payment notifications, or says whether that format is stable. This must be measured on a device.
- Google's Wallet help says users can turn transaction push notifications on or off in Wallet settings.
- `notificationsStream` in plugin 0.3.3 is a broadcast stream, so multiple Dart listeners are allowed. A second `listen()` does not throw.
- The plugin `id` is the app-supplied `StatusBarNotification.getId()`, not the unique `getKey()`. Do not use it as a dedupe key on its own.
- Posted and removed events both arrive as separate events (`hasRemoved`). The current `onNotification` ignores `hasRemoved`, so it can create duplicate transactions.
- Android does not re-send active notifications when a listener connects. Backfill needs an explicit `getActiveNotifications()` call, which plugin 0.3.3 does not make.
- Re-posting a notification with the same key fires `onNotificationPosted` again with no removal event, so duplicate posted events are expected.
- No official Google Wallet or Google Pay API lets a consumer app read the user's transaction history. None was found.
- The Play policy pages checked do not mention NotificationListenerService. SMS is a poor alternative: budget-tracking SMS use is restricted to default-handler status or an exception.

---

## Q1. Google Wallet / Google Pay notifications

**Package names**
- `com.google.android.apps.walletnfcrel` is titled "Google Wallet" on its Play listing. https://play.google.com/store/apps/details?id=com.google.android.apps.walletnfcrel
- `com.google.android.apps.nbu.paisa.user` is titled "Google Pay: Save and Pay" on its Play listing. https://play.google.com/store/apps/details?id=com.google.android.apps.nbu.paisa.user
  - The listing also contains the string "Google Pay app no longer available for use". It may be a regional banner, so check it on device.
- Whether either package posts payment notifications is not stated by any official source found.

**Official documentation of notifications**
- Google Wallet help "Manage passes notifications": "You can turn on notifications from Google Wallet to receive push notifications about your transactions, passes, and more." Turn-on/off is in the Wallet app settings. https://support.google.com/wallet/answer/14775537 (description meta and page body, fetched 2026)
- The same help section links a separate article, "View transactions on the Google Wallet app", which describes in-app viewing only. https://support.google.com/wallet/answer/14775537 (sidebar)
- Not found in any official source: notification text fields (merchant, amount, card last 4), notification title or channel names, or any statement that the notification format is not a stable API.

**Lock-screen visibility**
- Wallet's own visibility setting for these notifications is not documented.
- Android default: `VISIBILITY_PRIVATE` (value 0) shows the icon and ticker on the lock screen but hides contents until unlock. `VISIBILITY_PUBLIC` (1) shows contents. `VISIBILITY_SECRET` (-1) hides the icon too. https://github.com/aosp-mirror/platform_frameworks_base/blob/android14-release/core/java/android/app/Notification.java (lines 854–903) and https://developer.android.com/reference/android/app/Notification
- Whether a Wallet notification sets `VISIBILITY_PUBLIC` is unknown. Check on device.

**Confidence: Medium for package names (Play listing titles). Low for the notification content, format stability, and Wallet's visibility setting (no official documentation found).**

---

## Q2. notification_listener_service 0.3.3 (plugin source)

Source: plugin 0.3.3 pub archive (`https://pub.dev/packages/notification_listener_service/versions/0.3.3`, sha256 matches `budget/pubspec.lock`) and its repo https://github.com/X-SLAYER/notification_listener_service. There is no `0.3.3` git tag in the repo (checked with `gh api`), so the pub archive is the authoritative 0.3.3 source. The repo's default branch is `main`.

**(a) Broadcast or single subscription: broadcast.**
- `NotificationListenerService.notificationsStream` returns `_eventChannel.receiveBroadcastStream().map(ServiceNotificationEvent.fromMap)`. `lib/notification_listener_service.dart` (~lines 16–26).
- Flutter's `EventChannel.receiveBroadcastStream` uses `StreamController<dynamic>.broadcast`. https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/services/platform_channel.dart (~line 695)
- The native receiver is registered on the first listen and unregistered on the last cancel. `NotificationListenerServicePlugin.java` (`onListen` ~112–124, `onCancel` ~126–130).
- So a second `listen()` should not throw. Dart-side `listen()` calls still share one native receiver.
- The app's `initNotificationScanning()` cancels the old subscription before listening again (`budget/lib/pages/autoTransactionsPageEmail.dart` lines 38–49), which is safe.

**(b) `id` semantics and posted/removed events**
- `id` is `StatusBarNotification.getId()`, the int the posting app supplies. It is not `getKey()`. `NotificationListener.java` `handleNotification` (~line 59).
- Notifications with the same id but different tags, or from different apps, collide. Use the pair (`packageName`, `id`) plus `title`/`content`, or a Drift-stored key. Do not treat `id` as unique.
- `hasRemoved` is set from `onNotificationRemoved` (`isRemoved`). `NotificationReceiver.java` event map (~lines 39–51).
- Posting and later removing one notification therefore produces two events with the same `id` and `packageName`, one with `hasRemoved=false` and one with `true`.
- The app's `onNotification` (`autoTransactionsPageEmail.dart` lines 58–64) does not check `hasRemoved`. It passes every event to `queueTransactionFromMessage`. The message text includes a "Notification removed: ..." line (~line 164). The first 40 lines of `queueTransactionFromMessage` do not filter on that flag, and no dedupe was found there. The rest of the function was not reviewed.

**(c) Re-send of existing notifications on connect: no.**
- The plugin does not override `onListenerConnected` and does not call `getActiveNotifications()`. The 0.3.3 Java source has no call to `getActiveNotifications` (checked).
- AOSP `onListenerConnected` only delivers ranking updates, not existing notifications. https://github.com/aosp-mirror/platform_frameworks_base/blob/android14-release/core/java/android/service/notification/NotificationListenerService.java (~line 573)

**(d) Known issues (plugin GitHub tracker, https://github.com/X-SLAYER/notification_listener_service/issues)**
- #14: NPE in CharSequence handling.
- #24: ClassCastException on large icon.
- #28: NameNotFoundException.
- #35: exported broadcast receiver on API 34+ (`RECEIVER_EXPORTED` with an implicit action). Other apps may be able to send fake events. Fixed in 1.0.0 (commit `33486eab1`), not in 0.3.3. Exploitability not tested.
- #39: permission error, closed in 0.3.5.
- #44: `requestPermission` can kill the app (open).
- Duplicate events: none found in the tracker for 0.3.3. The duplicates come from the Android side (Q3).
- Content limitation: the plugin reads only `EXTRA_TEXT`. `EXTRA_BIG_TEXT` and `EXTRA_TEXT_LINES` are ignored, so expanded notifications can be truncated. `NotificationListener.java` (~line 74).
- 0.3.3 has no timestamp field. A timestamp was added in 1.0.0 (commit `2e5864af3`).
- Manifest: the plugin does not declare the listener service. The consuming app must declare it with `BIND_NOTIFICATION_LISTENER_SERVICE`.

**Confidence: High (verified from source files at the 0.3.3 archive). Medium for the exploitability of issue #35 (not tested).**

---

## Q3. Android framework semantics

- `onNotificationPosted(sbn)` fires for new notifications and for updates. A notification re-posted with the same key triggers `onNotificationPosted` again, and there is no removal callback for the update. AOSP `NotificationManagerService.java` `isUpdate` path, then `notifyPosted` (`services/core/java/com/android/server/notification/NotificationManagerService.java`, ~lines 7919, 11337, 11658, android14-release). https://github.com/aosp-mirror/platform_frameworks_base/blob/android14-release/services/core/java/com/android/server/notification/NotificationManagerService.java
- `onNotificationRemoved(sbn)` fires when a notification is dismissed or cancelled. The light `StatusBarNotification` keeps the tag, id, and package, so a removal can be matched to its posted event. https://developer.android.com/reference/android/service/notification/NotificationListenerService and https://developer.android.com/reference/android/service/notification/StatusBarNotification
- `onListenerConnected()` is for ranking setup. Existing notifications are not re-posted. Use `getActiveNotifications()` to backfill. https://developer.android.com/reference/android/service/notification/NotificationListenerService
- Callbacks run on the main thread from API 24.
- The user must enable notification access for the app in system settings, and the service must be bound with `BIND_NOTIFICATION_LISTENER_SERVICE`. https://developer.android.com/reference/android/service/notification/NotificationListenerService (medium confidence: the exact wording was not re-read this session).

**Confidence: High for the AOSP behavior (read in source). Medium for the developer.android.com wording (page reached but the relevant sections were not fully reviewed).**

---

## Q4. Google Play policy on notification access

- The Play policy page for sensitive permissions (`https://support.google.com/googleplay/android-developer/answer/16558241`, redirected from `play.google.com/about/privacy-security-deception/permissions/`) defines restricted permissions as Dangerous, Special, Signature, or documented below. It requires a compelling, critical feature with no alternative, no manipulation, and honoring denials.
- The full text of that page was not read. Notification listener access is not a listed special case in the text retrieved. A text search of the preview page (`https://support.google.com/googleplay/android-developer/answer/16909972`) for "notification listener" and "notification access" returned nothing.
- The Play Console declaration form for notification access was not reached. Whether NotificationListenerService requires a declaration is unverified.
- Google Play policy applies to apps distributed through Google Play. A personal sideloaded build is not reviewed by Play (inference from the policy's scope, not stated on a cited page). Android still requires the user to grant notification access in system settings.

**Confidence: Low for the Play declaration requirement (the form and full text were not reached). Medium for the restricted-permission definition (verified from the policy page).**

---

## Q5. Official Google Wallet / Google Pay APIs for consumer transaction reading

- The Google Wallet API reference lists endpoints for passes (issuing and managing them). No transaction-history or consumer payment-read endpoint was found. https://developers.google.com/wallet/reference/rest
- The Google Wallet retail overview covers pass issuance. No consumer read API was found. https://developers.google.com/wallet/retail
- The Google Pay API page covers payment flows for merchants and does not provide consumer transaction reads. https://developers.google.com/pay/api
- Secondary source: a web-search AI summary also concluded that no API exposes a consumer's Google Pay or Wallet transaction history. It is not primary and is included only as corroboration. Search result, not a cited page.
- Conclusion: no official consumer-facing transaction-read API for Google Wallet or Google Pay was found.

**Confidence: Medium. This is an absence-of-evidence finding from the developer pages checked.**

---

## Q6. SMS as an alternative source (RECEIVE_SMS and Play policy)

- Play SMS & Call Log policy: SMS and Call Log permissions (including `RECEIVE_SMS` and `READ_SMS`) may be declared and used only if the app is the default SMS/Phone/Assistant handler. Apps must stop using them if they lose that status. A non-default app may not declare them, even as a placeholder. https://support.google.com/googleplay/android-developer/answer/10208820
- The policy's eligible-use table lists "SMS-based money management (for example, apps that track and manage budget)" and "SMS-based financial transactions". Their status is unclear from the page text. They appear to need default-handler status or a temporary exception.
- The policy's not-permitted list includes "SMS or phone notification enhancement and alerts" for non-default apps without an eligible exception. https://support.google.com/googleplay/android-developer/answer/10208820
- The policy's alternatives include the SMS Retriever API and the SMS intent. Neither reads bank alerts in the background. https://support.google.com/googleplay/android-developer/answer/10208820
- Sideloaded builds are not subject to this Play review, but the Android permission itself still requires the user to grant it.

**Confidence: High for the default-handler requirement (read on the policy page). Medium for the budget-app category status (table text unclear).**

---

## Open unknowns requiring a device experiment

1. Which notifications Google Wallet and Google Pay actually post on the test device, and under which channel.
2. Exact text fields for a payment notification (title, text, big text, sub-text), and whether merchant, amount, and card last 4 appear in them.
3. Whether the Wallet and Pay notifications are delivered to the listener at default settings, and whether the Wallet "turn on notifications" setting changes that.
4. Lock-screen visibility (`VISIBILITY_*`) of those notifications.
5. Whether a single payment produces posted-then-removed events, and whether the `id` is stable across them.
6. Whether a bank notification and the Wallet notification for the same payment both appear, and their relative timing.
7. Whether re-posts (updates) happen for the same payment, and whether they carry the same key.
8. Whether `EXTRA_TEXT` holds the full merchant and amount, or whether `EXTRA_BIG_TEXT` is needed (the plugin ignores it).
9. Whether the "Google Pay app no longer available for use" banner on the Play listing applies to the test region.
10. Whether plugin 0.3.3 broadcast spoofing (#35) is practically exploitable on the target device. Upgrading to 1.0.0 closes it (verified: uses `RECEIVER_NOT_EXPORTED` on API 34+).

---

## Q7. notification_listener_service: 0.3.3 vs 1.0.0 Evaluation (S0b)

Source: Upstream GitHub repository `X-SLAYER/notification_listener_service` at `main` (containing 1.0.0 release) and pub.dev listing.

1. **Security Fix (Android 14+ / API 34+):**
   - Plugin issue #35 reported an exported broadcast receiver on API 34+.
   - In 1.0.0, `NotificationListenerServicePlugin.java` explicitly registers the receiver with `Context.RECEIVER_NOT_EXPORTED` on `Build.VERSION_CODES.UPSIDE_DOWN_CAKE` (API 34+), closing the broadcast spoofing vulnerability.

2. **API & Interface Compatibility:**
   - Dart API: `NotificationListenerService.notificationsStream` continues to return `Stream<ServiceNotificationEvent>`.
   - `isPermissionGranted()` and `requestPermission()` have identical signatures and behavior.
   - `ServiceNotificationEvent` retains `id`, `canReply`, `haveExtraPicture`, `hasRemoved`, `packageName`, `title`, and `content`.
   - Added fields: `onGoing` (bool), `timestamp` (int, milliseconds since epoch), `humanTime` (DateTime getter), `appIcon` (Uint8List?), `extrasPicture` (Uint8List?), `largeIcon` (Uint8List?).
   - Added method: `NotificationListenerService.getActiveNotifications()` returns `Future<List<ServiceNotificationEvent>>`.
   - Impact on Cashew: **100% backward-compatible** with existing usages in `autoTransactionsPageEmail.dart`.

3. **Content Extraction & `EXTRA_BIG_TEXT` Limitation:**
   - In 1.0.0, `NotificationListener.java` still queries `extras.getCharSequence(Notification.EXTRA_TEXT)` (line 168) and truncates to 500 characters.
   - `EXTRA_BIG_TEXT` is **still NOT read** in 1.0.0.
   - If Google Wallet or banking apps place full transaction details in `EXTRA_BIG_TEXT` (e.g. `NotificationCompat.BigTextStyle`), upgrading to 1.0.0 alone does not resolve that limitation. A native patch or plugin fork would be required if on-device testing proves `EXTRA_TEXT` is insufficient.

4. **Recommendation / Decision (S0b):**
   - **Upgrade to `notification_listener_service: ^1.0.0`:** The upgrade is safe, non-breaking, resolves the API 34 security flaw, and provides `timestamp` necessary for the deduplication time window in S3.
   - S1 (Single dispatcher & ignore `hasRemoved`) is unblocked and can proceed.

