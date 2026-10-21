# Google Wallet / Google Pay Notification Spec & Samples

## Real Device Sample (Philippines / UnionBank)
- **Source Package**: `com.google.android.apps.walletnfcrel` (or `com.google.android.gms`)
- **Channel**: `tapandpay_purchases` (or `gms.pay_default`)
- **Notification Title**: `7-Eleveb-ST4594`
- **Notification Content**: `P123.00 with UnionBank Rewards Platinum **3353`

### Extracted Fields
- **Merchant / Payee**: `7-Eleveb-ST4594`
- **Amount**: `123.00`
- **Currency Code / Sign**: `PHP` (`P`)
- **Payment Method / Card**: `UnionBank Rewards Platinum`
- **Card Last 4**: `3353`

---

## Variant Patterns

### Pattern A: Standard Merchant in Title
```text
Title: Starbucks
Content: ₱185.00 with Mastercard •••• 1234
```
- **Merchant**: `Starbucks`
- **Amount**: `185.00`
- **Currency**: `PHP` (`₱`)
- **Card**: `Mastercard •••• 1234`
- **Card Last 4**: `1234`

### Pattern B: US Dollar with Masked Number
```text
Title: Trader Joe's
Content: $42.75 with Chase Freedom •••• 9876
```
- **Merchant**: `Trader Joe's`
- **Amount**: `42.75`
- **Currency**: `USD` (`$`)
- **Card**: `Chase Freedom •••• 9876`
- **Card Last 4**: `9876`

### Pattern C: Generic "Google Wallet" Header with Merchant in Body
```text
Title: Google Wallet
Content: Paid ₱250.00 at Mercury Drug
```
- **Merchant**: `Mercury Drug`
- **Amount**: `250.00`
- **Currency**: `PHP` (`₱`)
- **Card**: null
