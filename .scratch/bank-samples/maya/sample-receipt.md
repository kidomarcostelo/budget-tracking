# Maya Receipt Spec & Sample

## Receipt Metadata
- **Institution**: Maya (formerly PayMaya, Philippines)
- **Sample File**: `sample-receipt.jpeg`
- **Branding**: `maya` logo at bottom

## Extracted Data
- **Transaction Type**: P2P Send Money (Expense / Transfer)
- **Header**: `Sent money`
- **Recipient**: `RICA T.`
- **Recipient Mobile**: `+639206923443`
- **Amount**: `- ₱100.00`
- **Status**: `Completed`
- **Source**: `My Wallet (+63 956 857 9768)`
- **Transaction Fee**: `₱0.00`
- **Reference ID**: `456C6B393301`
- **Message Note**: `- from KID OMAR`

## Extraction Heuristics & Regex

### Institution Detection
```regex
\bmaya\b
```

### Amount Regex
```regex
(?:-\s*)?[₱PHP]\s*(?<amount>[0-9,]+\.[0-9]{2})
```

### Reference ID Regex
```regex
Reference ID\s*(?<ref>[A-Z0-9]+)
```

### Recipient / Destination Regex
```regex
Destination\s*(?<name>[^\n\r]+?)(?:\s*(?<phone>\+?63\d{10}))?
```

### Message Note Regex
```regex
-\s*from\s*(?<sender>[^\n\r]+)
```
