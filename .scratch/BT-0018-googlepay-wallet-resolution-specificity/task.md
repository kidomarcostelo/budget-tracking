# BT-0018: Fix Google Pay Wallet Resolution — Prefer Most Specific Wallet Name Match

**Status:** `ready-for-agent`  
**Category:** `bug`  
**Priority:** Medium  
**Affects:** `budget/lib/struct/googlePayParser.dart`  
**Tests:** `budget/test/google_pay_wallet_resolve_test.dart` (regression — currently RED on Case 3)

---

## Problem Statement

When a Google Pay notification arrives for a card named **"UnionBank Visa Platinum"** (or similar multi-word card product names), and the user has:
- A wallet named `"UnionBank"` (generic)
- A wallet named `"UnionBank Visa"` or `"UnionBank Visa Platinum"` (specific)

…the prefilled wallet in `AddTransactionPage` resolves to **`"UnionBank"`** (too generic) instead of the more specific wallet that better represents the card used.

**User report:** *"When the transaction is from UnionBank Visa Platinum, the prefilled bank is on the 'UnionBank' not the 'UnionBank Visa Platinum'."*

---

## Diagnosis Summary (Phase 1–4 complete)

### Root Cause: First-token-wins in `resolveWallet` token-split fallback

**File:** [`budget/lib/struct/googlePayParser.dart`](../../budget/lib/struct/googlePayParser.dart), lines 183–194

```dart
// 2. Match card name against wallet names (e.g. "UnionBank")
if (result.cardName != null && result.cardName!.isNotEmpty) {
  final wallet = await database.getRelatingWallet(result.cardName!);
  if (wallet != null) return wallet;              // ✓ works when exact wallet exists

  final tokens = result.cardName!.split(RegExp(r'\s+'));
  for (final token in tokens) {                   // ← BUG: first-token-wins
    if (token.length >= 4) {
      final tokenWallet = await database.getRelatingWallet(token);
      if (tokenWallet != null) return tokenWallet;  // ← returns "UnionBank" immediately
    }
  }
}
```

**What happens for card name `"UnionBank Visa Platinum"` with wallets `["UnionBank", "UnionBank Visa"]`:**

| Step | Action | Result |
|------|--------|--------|
| 1 | `getRelatingWallet("UnionBank Visa Platinum")` | `null` (no exact wallet named this) |
| 2 | Token split: `["UnionBank", "Visa", "Platinum"]` | — |
| 3 | `getRelatingWallet("UnionBank")` | `"UnionBank"` ← **RETURNED (wrong!)** |
| — | `getRelatingWallet("Visa")` | never reached |
| — | `getRelatingWallet("Platinum")` | never reached |

**`"UnionBank Visa"`** is never considered even though it's a better (longer) match for `"UnionBank Visa Platinum"`.

### Secondary Issue: `getRelatingWallet` uses LIKE `%token%` (substring, not exact)

`getRelatingWallet("Visa")` returns `"UnionBank Visa Platinum"` via `LIKE %Visa%` — this is directionally opposite to what we want (the token is a *part of* the wallet name, not the wallet containing the token). The token-split path uses an already-wrong API for the wrong purpose.

### Why the full-name path fails
`getRelatingWallet("UnionBank Visa Platinum")` uses LIKE `%UnionBank Visa Platinum%` on wallet names, meaning: *"wallets whose name CONTAINS 'UnionBank Visa Platinum' as a substring"*. A wallet named `"UnionBank Visa"` does NOT contain `"UnionBank Visa Platinum"` → returns null → token-split fires.

---

## Tight Feedback Loop

```bash
# Run from budget/
flutter test test/google_pay_wallet_resolve_test.dart
```

**Before fix:** 1 failure (Case 3 — `[BUG] token-split first-token-wins`)  
**After fix:** All 5 cases green

---

## Fix Design

### Strategy: Replace token-split with "longest-contained-name" scan

After the existing full-name pass (Step 1 in `resolveWallet`) fails, instead of splitting tokens and returning on first hit, **load all wallets and find the one whose name is longest and is contained in the full cardName string**.

**Rationale:** A wallet name being contained in the card name string is directionally correct — `"UnionBank Visa"` ⊆ `"UnionBank Visa Platinum"` ✓. Picking the longest such match gives the most specific result.

> [!NOTE] This approach is already partially used in `sharedReceiptProcessor.resolveWalletByName` (lines 123–129 of `sharedReceiptProcessor.dart`), but without longest-first ordering. The fix aligns both modules to use the same robust strategy.

### Implementation Steps

#### Step 1: Add `resolveWalletByBestContainedName` helper to `GooglePayParser`

In `budget/lib/struct/googlePayParser.dart`, add a private static helper:

```dart
/// Finds the wallet whose name is the longest substring of [cardName].
/// Returns null if no wallet name is contained in [cardName].
static Future<TransactionWallet?> _resolveByLongestContainedName(
  String cardName,
) async {
  final allWallets = await database.getAllWallets();
  final cardNameLower = cardName.toLowerCase();

  TransactionWallet? bestMatch;
  int bestLength = 0;

  for (final wallet in allWallets) {
    final nameLower = wallet.name.trim().toLowerCase();
    if (nameLower.isEmpty) continue;
    if (cardNameLower.contains(nameLower) && nameLower.length > bestLength) {
      bestMatch = wallet;
      bestLength = nameLower.length;
    }
  }

  return bestMatch;
}
```

#### Step 2: Replace the token-split block in `resolveWallet`

**Before (lines 183–194):**
```dart
// 2. Match card name against wallet names (e.g. "UnionBank")
if (result.cardName != null && result.cardName!.isNotEmpty) {
  final wallet = await database.getRelatingWallet(result.cardName!);
  if (wallet != null) return wallet;

  final tokens = result.cardName!.split(RegExp(r'\s+'));
  for (final token in tokens) {
    if (token.length >= 4) {
      final tokenWallet = await database.getRelatingWallet(token);
      if (tokenWallet != null) return tokenWallet;
    }
  }
}
```

**After:**
```dart
// 2. Match card name against wallet names
if (result.cardName != null && result.cardName!.isNotEmpty) {
  // 2a. Try exact/LIKE full-name match first
  final wallet = await database.getRelatingWallet(result.cardName!);
  if (wallet != null) return wallet;

  // 2b. Find the wallet whose name is longest and is contained in the card name.
  //     e.g. card="UnionBank Visa Platinum", wallets=["UnionBank","UnionBank Visa"]
  //          → "UnionBank Visa" (14 chars) preferred over "UnionBank" (9 chars)
  final bestMatch =
      await _resolveByLongestContainedName(result.cardName!);
  if (bestMatch != null) return bestMatch;
}
```

#### Step 3: (Optional but recommended) Fix `sharedReceiptProcessor.resolveWalletByName`

The same first-match (not longest-match) vulnerability exists in [sharedReceiptProcessor.dart](../../budget/lib/struct/sharedReceiptProcessor.dart) lines 123–129:

```dart
// BEFORE:
for (final w in allWallets) {
  if (w.name.isNotEmpty &&
      trimmed.toLowerCase().contains(w.name.toLowerCase())) {
    return w;    // ← first match, not longest
  }
}

// AFTER:
TransactionWallet? best;
int bestLen = 0;
for (final w in allWallets) {
  final wl = w.name.trim().toLowerCase();
  if (wl.isNotEmpty &&
      trimmed.toLowerCase().contains(wl) &&
      wl.length > bestLen) {
    best = w;
    bestLen = wl.length;
  }
}
if (best != null) return best;
```

> [!IMPORTANT] This is a cross-cutting improvement. Apply it to both `googlePayParser.dart` and `sharedReceiptProcessor.dart` in the same PR to prevent the same bug from manifesting in receipt scanning.

---

## Tests to Write / Update

### New regression test (already written — currently RED)
**File:** [`budget/test/google_pay_wallet_resolve_test.dart`](../../budget/test/google_pay_wallet_resolve_test.dart)

This file contains 5 test cases covering:
1. ✅ Exact wallet match (full cardName → exact wallet) — GREEN before and after
2. ✅ Casing mismatch → case-insensitive LIKE match works — GREEN before and after  
3. 🔴 **[PRIMARY BUG]** No exact wallet, partial match — `"UnionBank Visa"` preferred over `"UnionBank"` — RED before fix, GREEN after
4. ✅ cardLast4 priority — GREEN before and after
5. ✅ Fallback to selectedWalletPk — GREEN before and after

**After fix:** All 5 must be GREEN.

### Existing tests to verify (must not regress)
```bash
flutter test test/google_pay_parser_test.dart
flutter test test/google_pay_flow_widget_test.dart
flutter test test/notification_dispatcher_test.dart
```

---

## Acceptance Criteria

- [ ] `flutter test test/google_pay_wallet_resolve_test.dart` → all 5 tests GREEN
- [ ] `flutter test test/google_pay_parser_test.dart` → all tests GREEN (no regression)
- [ ] `flutter test test/google_pay_flow_widget_test.dart` → all tests GREEN (no regression)
- [ ] `flutter test test/notification_dispatcher_test.dart` → all tests GREEN (no regression)
- [ ] `flutter analyze` → no new issues
- [ ] PR description states: *"Fix: resolveWallet preferred first-token-wins over longest-name match; replaced with contained-name scan sorted by name length DESC"*

---

## Files to Touch

| File | Change |
|------|--------|
| `budget/lib/struct/googlePayParser.dart` | Replace token-split block (L188–194) with `_resolveByLongestContainedName` |
| `budget/lib/struct/sharedReceiptProcessor.dart` | Fix same first-match bug in `resolveWalletByName` (L123–129) |
| `budget/test/google_pay_wallet_resolve_test.dart` | Already created — make it GREEN |

---

## Branching

```bash
git checkout -b fix/BT-0018-googlepay-wallet-resolution-specificity
```

Follow AGENTS.md: push branch, open PR against `main`, do NOT push to `main` directly.

---

## Hypothesis Confirmed (for PR message)

> `resolveWallet`'s token-split fallback iterated cardName tokens left-to-right and returned on first DB hit. Token `"UnionBank"` matched the generic wallet before longer matches like `"UnionBank Visa"` could be considered. Fix: scan all wallets and return the one whose name is longest and is contained in the full cardName string.
