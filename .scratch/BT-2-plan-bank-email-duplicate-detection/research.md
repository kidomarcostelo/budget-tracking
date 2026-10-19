# Research: Bank-email duplicate detection heuristics

**Issue:** [#6](https://github.com/kidomarcostelo/budget-tracking/issues/6) · **Parent:** [#2](https://github.com/kidomarcostelo/budget-tracking/issues/2) · **Related:** [#3](https://github.com/kidomarcostelo/budget-tracking/issues/3), [#5](https://github.com/kidomarcostelo/budget-tracking/issues/5) · Research only; no app code or Drift schema change.

## Question

What heuristics (timestamp window, currency/amount matching, fuzzy merchant titles, inter-bank transfer pairs) best prevent duplicate entries between bank emails and manually entered Transactions?

## Short answer

Rank evidence in tiers and never let a weak tier decide alone.

| Tier | Evidence | Default rule |
| --- | --- | --- |
| 0 | Gmail message `id` (`emailMessageId`, #3) | Idempotency only — dedupes *email vs. email*, never *email vs. Transaction*. |
| 1 | Bank reference / trace ID parsed from the body | Same reference already on a Transaction → high-confidence candidate. |
| 2 | Same Wallet + same direction (`income`) + amount equal to the **last minor unit** + time within window | **±72 h**, widened to **±5 calendar days** for authorization/pending alerts, date-only emails, or differing currencies. |
| 3 | Normalized merchant title similarity | Supporting only. Jaro–Winkler ≥ 0.90 after NFKC + full case folding + aggregator-prefix strip raises confidence; a low score never creates a match or breaks a tie alone. |
| 4 | Transfer-pair linkage across two Wallets | Opposite directions, different Wallets, amount matching after fees/FX, gap ≤ **30 min** (card rails) or ≤ **2 business days** (bank rails); else require explicit confirmation. |

Tiers 0–1 are identifiers and safe to trust; tier 2 is bounded and explainable; tier 3 is the only genuinely fuzzy signal and has documented failure modes on business names. Every non-tier-1 outcome is a *reviewable candidate*, never an auto-merge. **The thresholds are engineering defaults, not sourced facts** — chosen to sit inside the bounds the sources establish (e.g. 72 h < Visa's 3-business-day issuer posting rule) and needing tuning against real redacted samples.

## Findings

### (a) Timestamp windows

Email time is not transaction time. Gmail's `internalDate` is "the internal message creation timestamp (epoch ms)… the time the message was originally accepted by Google, which is more reliable than the `Date` header" [1]. The `Date` header is weaker still — it is "specifically not intended to convey the time that the message is actually transported" (RFC 5322 §3.6.1) [2]. So: prefer a timestamp parsed from the body, fall back to `internalDate`, use `Date` last.

Authorization is not posting. Open Banking (an ISO 20022-derived profile) defines `BookingDateTime` as "the date the transaction is booked (or posted) and becomes immutable, **which is not the date the transaction took place**"; a `Pending` entry "is mutable (ie some of its fields like date, description and amount may change or the transaction may be backed out completely)", and only `Booked` is immutable [4]. Posting lag is days by rule: Visa requires Issuers to post a Credit Transaction Receipt "within 5 calendar days from the Settlement date" in most regions, or in the US "within 3 business days" for Credit Cards and "within 1 business day" for Visa Check Cards [5].

Bank-side times may be date-only and timezone-free: "Where time elements do not exist in ASPSP systems, the time portion of the DateTime element will be defaulted to 00:00:00+00:00", and in filters "Timezone… must be ignored by the ASPSP" [4]. RFC 3339 §4.3 reserves `-00:00` for an unknown local offset [3]. **Consequence:** a sub-minute window is wrong here; compare UTC instants, not wall-clock strings, and size the window by alert type.

### (b) Currency and amount matching

Minor units are per-currency: ISO 4217 publishes `CcyMnrUnts` (JPY `0`, KWD `3`, PHP/EUR `2`) [6]. CLDR carries a *separate, display-oriented* table that deliberately differs (e.g. `AFN digits="0"` vs. ISO's `2`; `CHF cashRounding="5"`) [7] — use ISO for arithmetic, CLDR only for display.

The authorized amount may not be final: Visa permits an "Estimated Authorization Request… when the final Transaction amount is not known" and requires Issuers to notify cardholders that such amounts "may differ from the final Transaction amount" [5]. Cross-currency amounts are not reproducible client-side: Visa's Currency Conversion Rate is "A rate set by Visa from the range of rates available (not necessarily executed) in wholesale currency markets… may be adjusted by application of an Optional Issuer Fee", reversals use the rate "effective on the **Processing Date**", and "An Issuer shall set the conversion rate to its Cardholder" [5]. Fees ride alongside the entry — Open Banking models `ChargeAmount` separately [4].

**Consequence:** when email currency == Wallet currency, require exact equality on integers scaled by the ISO minor-unit exponent (±1 minor unit for rounding only). When currencies differ, do not try to reproduce the bank's rate; convert only to form a candidate band (≈±5 % plus a fee allowance) and require tier-1/tier-2 corroboration. ADR 0002 points the same way.

### (c) Fuzzy merchant titles

Normalize first. NFKC folds compatibility differences — "the halfwidth and fullwidth katakana characters will normalize to the same strings, as will Roman numerals and their letter equivalents" — but UAX #15 warns these forms "must *not* be blindly applied to arbitrary text… they may remove distinctions that are important to the semantics of the text" [8]. Use **full** case folding ("FUSS" ≡ "Fuß"); note "case folding does not preserve normalization formats" [9], so fold then re-normalize, and keep the result as a match key only — never as the stored Associated Title.

Aggregator prefixes are a documented, structural artifact: Stripe's descriptor is "concatenated with the prefix, the `*` symbol, and a space", ≤ 22 characters, Latin only, prefix 2–10 chars, with over-long descriptors truncated "to fit the character limit" [10]. So `PREFIX* SUFFIX` splitting is sound, and the bank's text can be a *lossy truncation* of the real merchant name.

Similarity measures: Jaro counts common characters and transpositions, where "the agreeing character must be within half the length of the shorter string"; Winkler added position weighting from evidence "that the probability of keypunch errors increased as the character position in a string moved from the left to the right" [11 §3.3]. The same report names the failure mode: "Business lists are typically more difficult to match than other types of lists… because of the variants of names and the variants of addresses" [11 §2]; alternatives (edit distance, q-grams, soft TF-IDF) may outperform Jaro–Winkler on some lists "while being slower to compute" [11 §3.3]. Critically, **Jaro–Winkler's left-biased weighting is actively harmful when the shared left prefix is the aggregator's prefix** — strip before scoring.

### (d) Inter-bank transfer pairs

A transfer is two entries on two accounts with opposite `CreditDebitIndicator` values, each potentially carrying its own `ChargeAmount` and currency-exchange detail [4]. Timing is rail-dependent: Visa's Fast Funds requires a "Recipient Issuer to make funds available to a Cardholder within 30 minutes of receipt and approval of an incoming Original Credit Transaction" ("In the US Region: Within 60 seconds of approving a domestic OCT") [5]; on bank rails the pending→booked transition can still change date and amount or back the entry out entirely [4]. Prefer identifiers where exposed: Open Banking defines `TransactionId` ("unique and immutable" within the servicing institution) and `TransactionReference` ("may… be the FPID in the Faster Payments context") [4].

**Consequence:** an outflow of X from Wallet A and an *unrelated* purchase of X from Wallet B are indistinguishable on amount alone. Pair only on opposite direction + different Wallets + amount reconciled after fees/FX + rail-appropriate gap, and require a shared reference or explicit confirmation before writing `pairedTransactionFk`.

### (e) Precision/recall — why "possible duplicate for review" beats auto-merge

This is the Fellegi–Sunter three-region rule, not a binary classifier: a pair above Tμ is a match, a pair below Tλ is a nonmatch, and "If Tλ ≤ R ≤ Tμ, then designate pair as a possible match **and hold for clerical review**"; the thresholds "are determined by a priori error bounds on false matches and false nonmatches" [11 §3.1, restating 12].

Cost asymmetry settles it: a false negative creates a visible duplicate the user deletes in one tap; a false positive silently suppresses a real Transaction and corrupts Budget totals with no signal anything is missing. Given that pending entries may be "backed out completely" [4] and authorized amounts may differ from final amounts [5], auto-merge is unsafe. Set Tμ effectively at "tier-1 identifier match" and route everything else into the review region.

### (f) Explainability

The review region is only usable if the reviewer can see *why* a pair scored where it did [11 §3.1]. Persist structured reasons rather than one opaque score — `amountExactMinorUnits`, `walletInferredFromLast4`, `timeDeltaSeconds`, `directionMatches`, `titleSimilarity=0.93 (NFKC+casefold+prefixStrip)`, `currencyConverted(USD→PHP, band ±5%)`, `bankReferenceMatched` — which also makes thresholds tunable from real user decisions later.

## Repo implications (verified)

- **The existing ±1 s pairing logic is not reusable here.** `getCloselyRelatedBalanceCorrectionTransaction` (`budget/lib/database/tables.dart:7467-7522`) requires `categoryFk == "0"`, opposite `income` (`:7502`), and `dateCreated` within `second ± 1` (`:7510`, `:7518`). That works only because the app writes both legs itself — `budget/lib/pages/addWalletPage.dart:1181-1201` creates one leg at `selectedDateTimeSetToNow.add(Duration(seconds: 1))` and the other at `selectedDateTimeSetToNow`. Email events have no such guarantee (§a), so keep §(d) transfer-pair detection a **separate** path.
- **`pairedTransactionFk` is set one-directionally** (`tables.dart:276-280`; only the second leg receives it, `addWalletPage.dart:1194-1196`), and the lookup compensates by querying both directions (`tables.dart:7477-7483`). Preserve that asymmetry.
- **Amounts are floats:** `RealColumn get amount => real()()` (`tables.dart:281`); Drift maps `real()` to SQL `REAL` [14] and SQLite stores `REAL` as "an 8-byte IEEE floating point number" [13]. Never use `==` on `amount`; compare integers scaled to the Wallet currency's ISO 4217 minor unit.
- **Timestamps are second-resolution:** "Database dates stored in seconds since epoch" (`tables.dart:7449`), matching Drift's default [14]. Fine for a ±72 h window, but compute it on UTC instants.
- **Currency lives on the Wallet, not the Transaction** (`tables.dart:261-263`; `budget/lib/struct/currencyFunctions.dart:54-80`). There is no per-Transaction original-currency/original-amount field, so a foreign-currency email cannot round-trip today — that gap belongs to #5.
- **`MethodAdded.email` already exists** (`tables.dart:122-128`) and `Transactions.methodAdded` (`:319`) is nullable, so email-ingested Transactions can be labelled with no schema change.
- **Direction is `income: bool`** (`tables.dart:302`) and `TransactionSpecialType` (`:44-50`) has no `transfer` member — transfers are paired balance corrections, so transfer heuristics must work from `income` + `walletFk` + `pairedTransactionFk`, not `type`.

## Open questions / assumptions needing bank sample data

`.scratch/bank-samples/` contains only `README.md` — **no samples exist**, so all of the following is unvalidated:

1. Do the emails describe an **authorization/pending** or a **posted** event? Decides 72 h vs. 5 days, and whether the amount is final.
2. Do they carry a **stable bank reference** (tier 1)? If yes, the fuzzy machinery becomes a fallback. Samples must preserve reference *format* while masking digits.
3. Can the Wallet be inferred from a masked PAN/account suffix (`XXXX-1234` per the README)? Without it, tier 2 loses its strongest constraint.
4. Do emails ever state an amount in a currency other than the Wallet's, and disclose rate/fee?
5. Which aggregator prefixes appear locally, and do *both* legs of an inter-bank transfer generate emails (with what lag)?

**Not verified from primary sources:** local acquirer descriptor conventions (Stripe's `PREFIX*` format is documented; local ones are not); ISO 8583 field 43 (card acceptor name/location) formatting, as the standard is not freely published; ACH/SEPA statutory settlement deadlines (Nacha rules are paywalled; EUR-Lex and EPC PDFs were unreachable), so the "±2 business days" bank-rail figure is an engineering default; whether bank *alert emails* track the Visa/Open Banking timings cited; and every specific threshold (72 h, ±5 days, 0.90, ±5 %), which no cited source prescribes.

## Sources

1. Gmail API discovery document, `Message.internalDate` — <https://gmail.googleapis.com/$discovery/rest?version=v1> (reference page: <https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages>)
2. RFC 5322, *Internet Message Format*, §3.6.1 — <https://www.rfc-editor.org/rfc/rfc5322.txt>
3. RFC 3339, *Date and Time on the Internet*, §4.3–4.4 — <https://www.rfc-editor.org/rfc/rfc3339.txt>
4. Open Banking Read/Write API v3.1.11, Transactions (Notes, Mutability, Data Dictionary) — <https://openbankinguk.github.io/read-write-api-site3/v3.1.11/resources-and-data-models/aisp/Transactions.html>
5. Visa Core Rules and Visa Product and Service Rules, public edition (Apr 2026): Issuer Credit Transaction Posting; §4.1.8.2 (ID# 0029466); §5.7.2.4 Estimated Authorization Request Requirements; Issuer Reversal of a Duplicate or Erroneous Transaction; glossary ID# 0024534 Currency Conversion Rate; glossary Fast Funds — <https://usa.visa.com/dam/VCOM/download/about-visa/visa-rules-public.pdf>
6. ISO 4217 currency list `list-one.xml`, SIX (ISO 4217 Maintenance Agency) — <https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-one.xml>
7. Unicode CLDR `supplementalData.xml`, `<currencyData><fractions>` — <https://github.com/unicode-org/cldr/blob/main/common/supplemental/supplementalData.xml>
8. Unicode Standard Annex #15, *Unicode Normalization Forms* — <https://www.unicode.org/reports/tr15/>
9. Unicode Character Database, `CaseFolding.txt` — <https://www.unicode.org/Public/UCD/latest/ucd/CaseFolding.txt>
10. Stripe, *Statement descriptors* (first-party vendor documentation) — <https://docs.stripe.com/get-started/account/statement-descriptors>
11. W. E. Winkler, *Overview of Record Linkage and Current Research Directions*, U.S. Census Bureau RRS Statistics #2006-2 — <https://www.census.gov/content/dam/Census/library/working-papers/2006/adrm/rrs2006-02.pdf>
12. I. P. Fellegi & A. B. Sunter, *A Theory for Record Linkage*, JASA 64(328):1183–1210, 1969 — <https://doi.org/10.1080/01621459.1969.10501049>
13. SQLite, *Datatypes In SQLite* §2, Storage Classes — <https://www.sqlite.org/datatype3.html>
14. Drift documentation, *Tables* (column types, DateTime storage) — <https://drift.simonbinder.eu/dart_api/tables/>
15. Repo: `budget/lib/database/tables.dart`, `budget/lib/pages/addWalletPage.dart`, `budget/lib/struct/currencyFunctions.dart`, `docs/adr/0002-currency-precision-and-exchange.md`
