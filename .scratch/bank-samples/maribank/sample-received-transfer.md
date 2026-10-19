# MariBank Email Receipt Spec & Sample

## Email Metadata
- **Sender Display Name**: `MariBank PH Alerts`
- **Subject**: `MariBank Transfer Notification`
- **Gmail Label**: `Finances/Transfers`

## Sample 1: Incoming Transfer from UnionBank
Extracted from transaction screenshot (`Screenshot_20261019_211616_com.gbox.android.jpg`):

- **Transaction time**: `19 Oct 2026 21:08`
- **Transfer from**: `Union Bank - 9227`
- **Transfer to**: `Kid Omar Costelo - 6603`
- **Transfer amount**: `PHP 200.00`
- **Reference No**: `720414`

---

## Extraction Heuristics

### Subject Regex
```regex
^MariBank Transfer Notification$
```

### Transaction Time Regex
```regex
Transaction time:\s*(?<datetime>\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\s+\d{1,2}:\d{2})
```
*DateTime Format*: `d MMM yyyy HH:mm`

### Transfer From Regex
```regex
Transfer from:\s*(?<sourceBank>[^-\n\r]+?)\s*-\s*(?<sourceSuffix>\d{4})
```

### Transfer To Regex
```regex
Transfer to:\s*(?<recipientName>[^-\n\r]+?)\s*-\s*(?<destSuffix>\d{4})
```

### Amount Regex
```regex
Transfer amount:\s*(?<currency>[A-Z]{3})\s*(?<amount>[0-9,]+\.[0-9]{2})
```

### Reference Number Regex
```regex
Reference No:\s*(?<ref>[0-9]+)
```

---

## Inter-Wallet Transfer Pairing Heuristics

When both UnionBank and MariBank emails are ingested:

| Property | UnionBank Email | MariBank Email | Matching Rule |
|---|---|---|---|
| **Direction** | Outgoing Transfer | Incoming Transfer | Complementary (`outgoing` + `incoming`) |
| **Amount** | `PHP 200.00` | `PHP 200.00` | Exact match |
| **Timestamp** | `21:08:xx` | `21:08` | Within $\pm 5$ minutes |
| **Source Account** | `********9227` | `Union Bank - 9227` | Bank name & 4-digit suffix match |
| **Destination Account** | `19530416603` | `Kid Omar Costelo - 6603` | Last 4 digits match (`6603`) |

### Triage Staging Action:
- Instead of creating 1 Expense + 1 Income:
- Stage a **single Transfer**:
  - `walletFk` = UnionBank Wallet ID
  - `toWalletFk` = MariBank Wallet ID
  - `amount` = `200.00`
  - `type` = `TransactionSpecialType.credit` (or paired transfer)
  - `pairedTransactionFk` links the outgoing and incoming Drift records.
