# MariBank App Receipt Spec & Sample

## Receipt Metadata
- **Institution**: MariBank (Philippines)
- **Sample File**: `sample-receipt.png`
- **Network**: InstaPay (`Realtime`)

## Extracted Data
- **Transaction Type**: Fund Transfer (Inter-bank)
- **Header**: `Transaction Receipt`
- **Amount**: `PHP 1,000.00`
- **Transfer Fee**: `FREE`
- **Total Amount**: `PHP 1,000.00`
- **Source (From)**:
  - Account Name: `KID OMAR C.`
  - Account: `MariBank: *******6603`
- **Destination (To)**:
  - Recipient Name: `Kid Omar Costelo`
  - Bank/Wallet: `Maya Philippines, Inc./Maya Wallet`
  - Mobile No: `09568579768`
- **Reference Number**: `454658`
- **Processing Time**: `Realtime`
- **Transaction Date & Time**: `19 Oct 2026, 22:26`

## Extraction Heuristics & Regex

### Institution Detection
```regex
MariBank
```

### Amount Regex
```regex
(?:PHP|Total Amount)\s*(?<amount>[0-9,]+\.[0-9]{2})
```

### Reference Number Regex
```regex
Reference Number\s*(?<ref>[0-9]+)
```

### Timestamp Regex
```regex
Transaction Date & Time\s*(?<datetime>\d{1,2}\s+[A-Za-z]{3}\s+\d{4},\s+\d{1,2}:\d{2})
```
*DateTime Format*: `d MMM yyyy, HH:mm`
