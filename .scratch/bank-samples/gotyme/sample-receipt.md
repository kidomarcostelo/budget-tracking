# GoTyme Bank Receipt Spec & Sample

## Receipt Metadata
- **Institution**: GoTyme Bank (Philippines)
- **Sample File**: `sample-receipt.png`
- **Network**: InstaPay (`Instant`)

## Extracted Data
- **Transaction Type**: Fund Transfer (Inter-bank)
- **Amount**: `₱3,600.00`
- **Fee**: `₱0.00`
- **Total**: `₱3,600.00`
- **Source (From)**:
  - Account Name: `KID O*** C******`
  - Account Number: `********3887`
  - Bank Name: `GoTyme Bank`
- **Destination (To)**:
  - Recipient Name: `KID O*** C*`
  - Account Number: `*******6603`
  - Bank Name: `MariBank Philippines (SeaBank)`
- **Trace ID**: `038004`
- **Reference No**: `ITO261019143038004`
- **Transaction Timestamp**: `19 Oct 2026 at 10:30 PM`

## Extraction Heuristics & Regex

### Institution Detection
```regex
GoTyme Bank
```

### Amount Regex
```regex
(?:Amount|Transferred|Total)\s*[₱PHP]?\s*(?<amount>[0-9,]+\.[0-9]{2})
```

### Reference Number Regex
```regex
Reference No\.\s*(?<ref>[A-Z0-9]+)
```

### Timestamp Regex
```regex
Date\s*(?<date>\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\s+at\s+\d{1,2}:\d{2}\s+[AP]M)
```
*DateTime Format*: `d MMM yyyy 'at' hh:mm a`
