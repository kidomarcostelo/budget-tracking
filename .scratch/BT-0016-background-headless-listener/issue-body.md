## Problem

When Cashew's Flutter engine is not running (screen locked, app backgrounded), the existing `notification_listener_service` EventChannel stream cannot deliver Google Pay or bank notification events. Users must open Cashew first before tapping to pay. If they forget, the transaction notification is missed entirely.

## Goal

Replace the event-channel-based listener with a **headless background isolate** approach using `flutter_notification_listener_plus`, so that:
- Google Pay tap-to-pay notifications are captured when Cashew is backgrounded / screen locked.
- All enabled bank scanner templates are also processed in the background.
- Captured transactions are saved as `pending = true` (integrating with BT-0015 pending queue) and trigger a local review notification.
- No new user-facing toggle: when notification scanning is on, background capture is the behaviour.
- A battery-optimization prompt tile in the existing notification settings page ensures OEM reliability.

## Scope

- **Primary guarantee:** App backgrounded / screen locked.
- **Best-effort:** Fully killed / swiped away (OEM-dependent).
- **Platform:** Android only.

## References

- Parent epic: #7 (BT-0003 Google Pay auto-transactions)
- Pending queue integration: #33 (BT-0015)
- Research: .scratch/BT-0003-extend-auto-transactions-google-pay/research.md
