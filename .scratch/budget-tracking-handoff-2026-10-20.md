# Handoff: Budget Tracking (Cashew Fork)

**Date:** 2026-10-20  
**Current Branch:** `main` (up to date with `origin/main`, commit `2f1421e4`)  
**Target Repository:** `kidomarcostelo/budget-tracking`

---

## 1. Executive Summary & Session Accomplishments

1. **APK Cloud Build & Device Verification**:
   - The user tested the debug APK produced by GitHub Actions workflow `.github/workflows/build-apk.yml`.
   - The APK was downloaded to `/storage/emulated/0/Download/app-debug.apk`.
   - **User Test Result**: Confirmed **"the OCR worked"** for Philippine bank receipts shared via Android `ACTION_SEND`.
2. **Issue #3 & #4 Converted to Documented Tasks**:
   - **BT-5**: [`BT-5-gmail-extraction-sync-feasibility`](.scratch/BT-5-gmail-extraction-sync-feasibility/task.md) with complete [`research.md`](.scratch/BT-5-gmail-extraction-sync-feasibility/research.md) covering Google CASA Tier 1, restricted `gmail.readonly`, MIME extraction, and SQLite WAL mode. GitHub Issue [#3](https://github.com/kidomarcostelo/budget-tracking/issues/3) updated.
   - **BT-6**: [`BT-6-prototype-triage-inbox-ui`](.scratch/BT-6-prototype-triage-inbox-ui/task.md) detailing the Triage Inbox screen and interactive `TriageTransactionCard` layout. GitHub Issue [#4](https://github.com/kidomarcostelo/budget-tracking/issues/4) updated.
   - Updated [`.scratch/index.md`](.scratch/index.md).
3. **New Feature Request: Owner Recognition & Self-Transfer Routing**:
   - User requested owner recognition to distinguish internal self-transfers from external expenses.
   - User confirmed adding an **Account Owner Name** preference (`appStateSettings["accountOwnerName"]`).
   - Created GitHub Issue [#12](https://github.com/kidomarcostelo/budget-tracking/issues/12) (`enhancement`, `ready-for-agent`).
   - Created local task **BT-7**: [`BT-7-owner-recognition-self-transfers`](.scratch/BT-7-owner-recognition-self-transfers/task.md).
   - Bumped `Next ID: 8` in [`.scratch/index.md`](.scratch/index.md).

---

## 2. Immediate Next Task: Implement Issue #12 / BT-7

The user explicitly approved the design and asked to proceed with implementing owner recognition and self-transfer routing.

### The Problem to Solve
When capturing an inter-bank transfer between user-owned accounts (e.g. UnionBank to MariBank), Cashew currently opens the single-wallet **Expense** screen (`AddTransactionPage`). It should instead open Cashew's native **Transfer** sheet ([`TransferBalancePopup`](budget/lib/pages/addWalletPage.dart#L1022)), populating both `walletFrom` and `walletTo`.

### Architecture & Implementation Plan
1. **Preferences & Settings**:
   - Add `"accountOwnerName": ""` in [`budget/lib/struct/defaultPreferences.dart`](budget/lib/struct/defaultPreferences.dart).
   - In [`budget/lib/widgets/accountAndBackup.dart`](budget/lib/widgets/accountAndBackup.dart), if `accountOwnerName` is empty when signing in with Google, initialize it to `googleUser?.displayName ?? ""`.
   - Expose an editable "Account Owner Name" text field in settings (e.g. [`budget/lib/pages/accountsPage.dart`](budget/lib/pages/accountsPage.dart)).
2. **Model Expansion & Dynamic Extraction (Bugfix for Hardcoded Defaults)**:
   - Add `sourceName` and `destinationBank` to `ParsedBankReceipt` in [`budget/lib/struct/receiptParser.dart`](budget/lib/struct/receiptParser.dart).
   - **Crucial Bugfix**: Eliminate hardcoded `destinationName` strings (`Maya Wallet` in `_parseMariBank`, `MariBank` in `_parseGoTyme`, `Maribank` in `_parseUnionBank`). During stress testing, a **MariBank -> UnionBank** transfer falsely logged destination details for Maya because of `destinationName: 'Maya Wallet'`.
   - Update parsers (`_parseGoTyme`, `_parseMaya`, `_parseMariBank`, `_parseUnionBank`) to dynamically extract sender and recipient names/banks from OCR lines under `From` and `To`:
     - GoTyme: `From: KID O*** C******` -> `sourceName`, `To: KID O*** C*` -> `destinationName`, `MariBank Philippines (SeaBank)` -> `destinationBank`.
     - Maya: `- from KID OMAR` -> `sourceName`, `Destination RICA T.` -> `destinationName`.
     - MariBank: `From KID OMAR C.` -> `sourceName`, `To Kid Omar Costelo` -> `destinationName`, dynamically parse destination bank (e.g. `UnionBank`, `Maya`, etc.) -> `destinationBank`.
     - UnionBank: `From KID OMAR RENDON COSTELO` -> `sourceName`, `To Kid Omar Costelo` -> `destinationName`, `Maribank` -> `destinationBank`.
3. **OwnerResolver Engine**:
   - Create `budget/lib/struct/ownerResolver.dart`.
   - Token-based fuzzy matcher handling:
     - Case and punctuation insensitivity.
     - Asterisk masks (e.g. `KID O*** C******` matches `Kid Omar Costelo` and `KID O*** C*`).
     - Initials (e.g. `KID OMAR C.` matches `Kid Omar Costelo`).
     - Middle names (e.g. `KID OMAR RENDON COSTELO` matches `Kid Omar Costelo`).
   - Decision logic:
     - Self-Transfer if: `fromName == toName` OR (`fromName == accountOwnerName` AND `destinationBank` matches an existing wallet in database).
     - Expense if: `toName` is an external party/merchant or does not match an existing wallet.
4. **Router Branching in [`sharedReceiptCapture.dart`](budget/lib/widgets/util/sharedReceiptCapture.dart)**:
   - If `isSelfTransfer`:
     - Resolve `destinationWallet` via `database.getRelatingWallet(receipt.destinationBank)`.
     - Open `openBottomSheet(context, TransferBalancePopup(wallet: matchedWallet, allowEditWallet: true, initialAmount: receipt.amount, initialDate: receipt.dateTime, initialTitle: "Transfer to ${destinationWallet?.name ?? receipt.destinationBank}", showAllEditDetails: true))`.
   - If not self-transfer:
     - Keep existing flow launching `AddTransactionPage(...)` (Expense).
5. **Testing**:
   - Add unit tests in `receipt_parser_test.dart` and `owner_resolver_test.dart`.
   - Verify `flutter analyze` has 0 warnings, `dart format` is clean, all tests pass.

---

## 3. Key Repositories & Reference Links

- **Parent Map #2**: [kidomarcostelo/budget-tracking#2](https://github.com/kidomarcostelo/budget-tracking/issues/2)
- **Map #8 (Receipt Capture)**: [kidomarcostelo/budget-tracking#8](https://github.com/kidomarcostelo/budget-tracking/issues/8) (Completed)
- **Active Issue #12 (Owner Recognition)**: [kidomarcostelo/budget-tracking#12](https://github.com/kidomarcostelo/budget-tracking/issues/12)
- **Task Tracking**:
  - [`.scratch/index.md`](.scratch/index.md)
  - [`.scratch/BT-7-owner-recognition-self-transfers/task.md`](.scratch/BT-7-owner-recognition-self-transfers/task.md)
- **Architectural Constraints**:
  - [`CONSTRAINTS.md`](CONSTRAINTS.md)
  - [`GLOSSARY.md`](GLOSSARY.md)
  - [`docs/adr/0001-local-first-drift-sqlite.md`](docs/adr/0001-local-first-drift-sqlite.md)

---

## 4. Suggested Skills for Next Agent

1. **`test-driven-development` / `tdd`**:
   - Write unit tests for `OwnerResolver` (token matching, mask expansion, middle name handling) before wiring UI components.
2. **`incremental-implementation`**:
   - Land changes in clean slices: model & parser updates $\to$ `OwnerResolver` $\to$ settings preference $\to$ UI routing seam.
3. **`code-review-and-quality`**:
   - Verify zero static analysis warnings (`flutter analyze`) and strict adherence to Cashew's theming and database conventions.

---

## 5. Non-Negotiable Constraints & Guardrails

- **No AI / Co-authored-by Trailers**: Never add `Co-authored-by` or assistant attribution trailers in git commit messages.
- **Local-First Privacy**: 100% on-device processing. No external identity services or cloud APIs.
- **Quality Gates**: Maintain 0 `flutter analyze` warnings, 0 `dart format` diffs, and all tests passing before pushing to `origin/main`.
