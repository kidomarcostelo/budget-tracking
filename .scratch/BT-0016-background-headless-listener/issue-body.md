## Problem

When Cashew is in the background or the screen is locked, Android's process lifecycle management can freeze or terminate the app process. As a result, when the user performs a tap-to-pay payment via Google Wallet, Cashew's `NotificationListenerService` event stream cannot deliver the notification to Dart. The user currently has to open Cashew before making a payment so that the app process remains resident in memory.

## Goal

Implement an Android Foreground Keep-Alive Service (`CashewKeepAliveService`) that keeps Cashew resident in memory while the screen is locked, paired with on-device Battery Optimization guidance:
- Google Pay tap-to-pay notifications are captured reliably while Cashew is backgrounded / screen locked.
- All enabled bank scanner templates are also processed in the background without needing Cashew in the foreground.
- Captured transactions are saved as `pending = true` (integrating with BT-0015 pending queue) and trigger a local review notification.
- Automatic lifecycle: when notification scanning is on, the keep-alive monitor is active.
- A battery-optimization prompt tile in the notification settings page ensures OEM reliability.

## Scope

- **Primary guarantee:** App backgrounded / screen locked.
- **Platform:** Android only.

## References

- Parent epic: #7 (BT-0003 Google Pay auto-transactions)
- Pending queue integration: #33 (BT-0015)
- Local spec: `.scratch/BT-0016-background-headless-listener/task.md`
