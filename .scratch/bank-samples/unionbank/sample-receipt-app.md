# UnionBank App Receipt Spec & Sample

## Receipt Metadata
- **Institution**: UnionBank Online (Philippines)
- **Sample File**: `sample-receipt.jpeg`
- **Branding**: Orange header & footer (`UnionBank Online`)
- **Network**: InstaPay

## Extracted Data
- **Transaction Type**: Fund Transfer (Inter-bank)
- **Reference Number**: `UB1663112`
- **Status**: `Successful` (`Oct 19, 2026 | 10:25 PM`)
- **Instapay Reference Number**: `995044`
- **Destination (To)**:
  - Recipient Name: `Kid Omar Costelo`
  - Destination Bank: `Maribank`
  - Account Number: `1953 0416 603`
- **Amount**: `PHP 15,000.00`
- **Purpose**: `Fund Transfer`
- **Source (From)**:
  - Account Name: `KID OMAR RENDON COSTELO`
  - Card/Product: `Classic Savings ePaycard`
  - Account Number: `**** **** 9227`

## Extraction Heuristics & Regex

### Institution Detection
```regex
UnionBank(?:\s*Online)?
```

### Reference Number Regex
```regex
Reference Number\s*(?<ref>UB[0-9]+)
```

### Amount Regex
```regex
Amount\s*PHP\s*(?<amount>[0-9,]+\.[0-9]{2})
```

### Instapay Reference Number Regex
```regex
Instapay Reference Number\s*(?<ref>[0-9]+)
```

### Timestamp Regex
```regex
(?<date>[A-Za-z]{3}\s+\d{1,2},\s+\d{4})\s*\|\s*(?<time>\d{1,2}:\d{2}\s+[AP]M)
```
*DateTime Format*: `MMM d, yyyy | hh:mm a`
