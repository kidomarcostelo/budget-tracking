# UnionBank Email Receipt Spec & Sample

## Email Metadata
- **Sender Display Name**: `UnionBank Online`
- **Sender Address**: `online@unionbankph.com`
- **Subject Template**: `Fund Transfer Successful (Ref# {REFERENCE_NUMBER})`
- **Channel**: InstaPay / PESONet

## Sample 1: Inter-bank Transfer to MariBank
Extracted from transaction screenshot (`Screenshot_20261019_205442_com.gbox.android.jpg`):

- **Reference Number**: `UB1592601`
- **Transaction Date**: `October 19, 2026 08:53:19 PM`
- **Sent Via**: `Instapay`
- **Instapay Reference Number**: `631310`
- **To**:
  - Name: `Kid Omar Costelo`
  - Destination Bank: `Maribank`
  - Account Number: `19530416603`
- **Amount**: `PHP 100.00`
- **Purpose**: `Fund Transfer`
- **From**:
  - Name: `KID OMAR RENDON COSTELO`
  - Source Bank: `Union Bank of the Philippines`
  - Source Account: `********9227`

---

## Extraction Heuristics

### Subject Regex
```regex
^Fund Transfer Successful \(Ref# (?<ref>[A-Z0-9]+)\)$
```

### Amount & Currency Regex
```regex
Amount:\s*(?<currency>[A-Z]{3})\s*(?<amount>[0-9,]+\.[0-9]{2})
```
*Or from body summary:*
```regex
successfully transferred\s+(?<currency>[A-Z]{3})\s*(?<amount>[0-9,]+\.[0-9]{2})\s+to\s+(?<recipient>.+?)\s+via
```

### Transaction Date Regex
```regex
Transaction Date:\s*(?<date>[A-Za-z]+ \d{1,2}, \d{4} \d{1,2}:\d{2}:\d{2} [AP]M)
```
*DateTime Format*: `MMMM d, yyyy hh:mm:ss a`

### Inter-Wallet Transfer Pairing
When `Purpose: Fund Transfer` is present and Destination Bank matches another user wallet (e.g. `Maribank`), this transaction should be staged as a **Transfer** rather than an Expense:
- **Source Wallet**: Matched by `From` account suffix (`...9227`) or Bank Name (`UnionBank`).
- **Destination Wallet**: Matched by `Destination Bank` (`Maribank`) and/or `Account Number` (`19530416603`).
- **Pairing Key**: Amount (`100.00`) + Timestamp proximity ($\pm 5$ minutes) + Reference / Instapay Ref (`631310`).
