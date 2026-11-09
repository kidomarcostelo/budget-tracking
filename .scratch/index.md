# Local task index (.scratch/)

Each task is a folder `.scratch/BT-NNNN-<slug>/` with its `task.md` (copied from `.scratch/templates/task.md`) and any artifacts such as `research.md`.

- IDs use 4-digit zero-padded numbering (`0001`, `0002`, etc.) to maintain natural sort order across filesystem listings and tools.
- IDs are stable and never renumbered. Rows are ordered by ID, which is creation order.
- To add a task: take `Next ID`, create `.scratch/BT-<NNNN>-<slug>/task.md`, add a row below, and bump `Next ID`.

Next ID: 0015

| ID | Title | Issue | Folder |
|----|-------|-------|--------|
| BT-0001 | Unlock Premium Features and Decouple Google Play Store Billing | [#1](https://github.com/kidomarcostelo/budget-tracking/issues/1) | [BT-0001-unlock-premium](BT-0001-unlock-premium/task.md) |
| BT-0002 | Plan duplicate detection for bank-email Transactions | [#6](https://github.com/kidomarcostelo/budget-tracking/issues/6) | [BT-0002-plan-bank-email-duplicate-detection](BT-0002-plan-bank-email-duplicate-detection/task.md) |
| BT-0003 | Extend automatic transaction creation to Google Pay (Android) | [#7](https://github.com/kidomarcostelo/budget-tracking/issues/7) | [BT-0003-extend-auto-transactions-google-pay](BT-0003-extend-auto-transactions-google-pay/task.md) |
| BT-0004 | Capture transactions from shared banking screenshots (Android first) | [#8](https://github.com/kidomarcostelo/budget-tracking/issues/8) | [BT-0004-screenshot-share-capture](BT-0004-screenshot-share-capture/task.md) |
| BT-0005 | Evaluate on-device Gmail message body extraction and background fetch feasibility | [#3](https://github.com/kidomarcostelo/budget-tracking/issues/3) | [BT-0005-gmail-extraction-sync-feasibility](BT-0005-gmail-extraction-sync-feasibility/task.md) |
| BT-0006 | Prototype the Triage Inbox UI and Review Flow | [#4](https://github.com/kidomarcostelo/budget-tracking/issues/4) | [BT-0006-prototype-triage-inbox-ui](BT-0006-prototype-triage-inbox-ui/task.md) |
| BT-0007 | Recognize account owner in receipt capture to automatically route self-transfers vs expenses | [#12](https://github.com/kidomarcostelo/budget-tracking/issues/12) | [BT-0007-owner-recognition-self-transfers](BT-0007-owner-recognition-self-transfers/task.md) |
| BT-0008 | Colocate Test Suites with Library Subsystem Structure | [#14](https://github.com/kidomarcostelo/budget-tracking/issues/14) | [BT-0008-colocate-tests](BT-0008-colocate-tests/task.md) |
| BT-0009 | Route recognized self-transfers directly to Transfer balance flow | [#17](https://github.com/kidomarcostelo/budget-tracking/issues/17) | [BT-0009-self-transfer-routing-fix](BT-0009-self-transfer-routing-fix/task.md) |
| BT-0010 | Isolate Android debug build with applicationIdSuffix and distinct app label | [#21](https://github.com/kidomarcostelo/budget-tracking/issues/21) | [BT-0010-debug-app-isolation](BT-0010-debug-app-isolation/task.md) |
| BT-0011 | Align preview demo data with user banks (UnionBank, MariBank, GoTyme, Maya) | [#27](https://github.com/kidomarcostelo/budget-tracking/issues/27) | [BT-0011-align-preview-demo-data-banks](BT-0011-align-preview-demo-data-banks/task.md) |
| BT-0012 | Fix addTransactionRoute deep link prefilled fields and sequence blocking | [#28](https://github.com/kidomarcostelo/budget-tracking/issues/28) | [BT-0012-fix-add-transaction-route-deep-link](BT-0012-fix-add-transaction-route-deep-link/task.md) |
| BT-0013 | Enable Google Sign-In and Google Drive Cloud Backup for Custom Builds | [#35](https://github.com/kidomarcostelo/budget-tracking/issues/35) | [BT-0013-google-drive-cloud-backup](BT-0013-google-drive-cloud-backup/task.md) |
| BT-0014 | Research Feasibility of Decoupled Bank Notification Parser (Automate / Tasker & Cashew API) | [#37](https://github.com/kidomarcostelo/budget-tracking/issues/37) | [BT-0014-decoupled-notification-parser](BT-0014-decoupled-notification-parser/task.md) |
