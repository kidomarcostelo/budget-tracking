# Bank Email Samples (.scratch/bank-samples/)

Organize redacted sample emails by bank/institution to serve as test fixtures for extraction rules and regex matching.

## Directory Structure
Organize samples in subdirectories named after the bank or financial institution:

```
.scratch/bank-samples/
├── <bank-name>/
│   ├── debit_purchase.txt
│   ├── fund_transfer_sent.txt
│   ├── fund_transfer_received.txt
│   └── bill_payment.txt
└── README.md
```

## Anonymization Guidelines (Redact Before Saving)
Please ensure all personal and sensitive details are replaced with placeholders:
- **Card / Account Numbers:** Replace with `XXXX-1234` (keep last 4 digits to test wallet auto-mapping).
- **Amounts:** Feel free to change real amounts to dummy numbers (e.g. `1,250.00`).
- **Names:** Replace account holder names with `[User]` or `[Recipient]`.
- **Reference / OTP / Transaction IDs:** Replace sensitive digits (e.g. `REF-XXXX999`).

## File Format
Each `.txt` file can contain the raw email text (or HTML source) along with a brief header:

```
Subject: [Pasted subject line]
From: [Sender email address, e.g. alerts@bank.com]
Type: [Debit / Credit / Transfer / Payment]
---
[Pasted body text or HTML]
```

## Curated Banks & Samples
- **UnionBank**: [`unionbank/sample-transfer.md`](unionbank/sample-transfer.md) (Outgoing Fund Transfer via InstaPay to MariBank)
- **MariBank**: [`maribank/sample-received-transfer.md`](maribank/sample-received-transfer.md) (Incoming Fund Transfer from UnionBank)

