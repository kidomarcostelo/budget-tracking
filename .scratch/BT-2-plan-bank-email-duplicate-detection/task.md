# Task: Plan duplicate detection for bank-email Transactions

**ID:** BT-2  
**Issue Reference:** [#6](https://github.com/kidomarcostelo/budget-tracking/issues/6)

---

## What & why

Define safe, explainable heuristics for when a bank-email alert may describe a Transaction
already entered manually, without suppressing legitimate purchases, payments, or transfers.
Out of scope: implementing email parsing, a duplicate detector, or a Drift schema change.

## Invariants & constraints

- Consult [`CONSTRAINTS.md`](../../CONSTRAINTS.md) and [`GLOSSARY.md`](../../GLOSSARY.md).
- Keep email processing local-first; the parent map (#2) rules out external cloud AI or server-side ingestion.
- Treat repeated delivery of the same email (`emailMessageId`, #3) separately from a possible match to an existing Transaction.
- Never auto-discard, merge, or rewrite a Transaction based only on fuzzy similarity; surface uncertain matches for review.
- Coordinate any persisted match or source fields with #5.

## What we know

Full findings are in [`research.md`](research.md) and were posted to #6.

- Recommended tiers: (1) bank reference or trace ID; (2) same Wallet, same direction, exact amount at the ISO 4217 minor unit, within ±72 h (±5 days for pending or authorization alerts); (3) fuzzy merchant text as supporting evidence only; (4) transfer pairs across Wallets, opposite direction, ≤30 min on card rails or ≤2 business days on bank rails.
- Every non-tier-1 match is a reviewable "possible duplicate", never an auto-merge. A false negative costs one tap to delete; a false positive silently removes a real Transaction.
- Repo facts: `Transactions.amount` is `real()` (`budget/lib/database/tables.dart:281`), so never compare amounts with `==`. Currency lives on Wallets (`tables.dart:261-263`), with no original-currency field (gap for #5).
- `getCloselyRelatedBalanceCorrectionTransaction` (`tables.dart:7467-7522`) is not reusable for email matching: it relies on the app writing both transfer legs itself (`budget/lib/pages/addWalletPage.dart:1181-1201`).
- `MethodAdded.email` already exists (`tables.dart:122-128`), so labeling email-ingested Transactions needs no schema change.
- All thresholds and bank-specific formats are unverified until real samples exist.

## Plan

- [x] Complete the cited primary-source investigation in `research.md`, separating verified facts from recommendations.
- [ ] Define a normalized candidate representation: direction/type, amount and currency, event time with timezone assumptions, Wallet evidence, merchant text, stable bank reference, and source email message ID.
- [ ] Rank evidence from strongest to weakest, and derive thresholds from source evidence and redacted bank samples rather than one global time window.
- [ ] Gather representative, redacted bank samples into `.scratch/bank-samples/<bank>/` before tuning extraction rules or thresholds.
- [ ] Specify transfer-pair handling separately: opposite directions across Wallets, currency conversion and fees, and stronger evidence or explicit confirmation before pairing.
- [ ] Design the Triage Inbox outcome as an explainable "possible duplicate" with match reasons; never auto-delete or merge.
- [ ] When implementation is authorized, test exact duplicates, same-amount near misses, merchant-name variants, timezone and date boundaries, differing currencies, and transfer pairs using redacted fixtures.

## Acceptance & verification

- [x] Research claims cite the primary source that owns each claim (`research.md`, 15 sources).
- [x] Recommendations cover false-positive and false-negative tradeoffs and flag unresolved bank-specific assumptions (`research.md`, "Open questions / assumptions").
- [ ] Future implementation tests cover both matching cases and similar-but-distinct Transactions (deferred until implementation is authorized).

## Roadblock

Thresholds and bank-specific parser assumptions cannot be validated: `.scratch/bank-samples/` has no samples yet. Waiting on review of the #6 findings and on redacted samples.

## Tried

- The first background research agent ended without output.
- Re-ran with `claude-opus-5`, which produced `research.md`. Findings posted to #6: https://github.com/kidomarcostelo/budget-tracking/issues/6#issuecomment-6266877162

## Resume / next step

Review the findings on #6. Then gather redacted bank samples into `.scratch/bank-samples/<bank>/` and validate the thresholds. Feed the result into #5 (Triage and original-currency schema).

## Links

- GitHub: #6 (parent #2; related #3, #5)
- Research: [`research.md`](research.md)
- Sample convention: [`.scratch/bank-samples/README.md`](../bank-samples/README.md)
