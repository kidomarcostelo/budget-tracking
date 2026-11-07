# Automation: App Links

Reference for triggering Cashew actions (mainly adding transactions) from other apps, shortcuts, or scripts via App Links.

Discussion: https://github.com/jameskokoska/Cashew/issues/127#issuecomment-1975096357
FAQ: https://cashewapp.web.app/faq.html#automation

## Overview

App links enable Cashew to execute actions automatically. They can be triggered in several ways:

- By clicking a link directly, which launches the application.
- Shortcuts on iOS, which can forward an App Link's data using Cashew's *Queue App Link URL* shortcut action.
- Broadcast receiver on Android, which can forward App Link data to Cashew while the app is not opened.

Using app links, you can add transactions to Cashew with a single tap and include any supported parameters.

## Routes

To create a full endpoint, the following base route is required.

| Platform | Route |
| --- | --- |
| Android / iOS | `https://cashewapp.web.app/[Endpoint here]` |
| Web App | `https://budget-track.web.app/[Endpoint here]` |

The examples below use the Android / iOS route, so they only work on an Android or iOS device with Cashew installed.

## Add Single Transaction

| Endpoint | Description |
| --- | --- |
| `/addTransaction` | Add a new transaction without a UI prompt (unless a category is missing). |
| `/addTransactionRoute` | Open the add new transaction route with information filled in. |

| Parameter | Description | Required | Default |
| --- | --- | --- | --- |
| `JSON` | A list of JSON objects of transactions. If provided, Cashew imports multiple transactions at once. Each object can use any parameter below. Keyed with `transactions` followed by the list of objects. See [Add Multiple Transactions with JSON](#add-multiple-transactions-with-json). | No | None |
| `subcategoryPk` | Primary key of the subcategory entry. | No | None |
| `subcategory` | Name of the subcategory. If provided, overwrites the category if a subcategory is found under a main category. Name search, first entry, not case sensitive. | No | None |
| `categoryPk` | Primary key of the category entry. | No | Prompt user |
| `category` | Name of the category. Name search, first entry, not case sensitive. Used to determine income or expense. | No | Prompt user |
| `walletPk` | Primary key of the wallet (account) entry. | No | Primary account |
| `account` / `wallet` | Name of the account. Name search, first entry, not case sensitive. | No | Primary account |
| `budgetPk` | Primary key of the budget entry. Must be an "Added Transactions Only" budget. | No | None |
| `budget` | Name of the "Added Transactions Only" budget. | No | None |
| `objectivePk` | Primary key of the objective entry. An objective is either a goal or a long-term loan. | No | None |
| `goal` | Name of the goal to add the transaction to. | No | None |
| `loan` | Name of the long-term loan to add the transaction to. | No | None |
| `objective` | Name of the objective (goal name). | No | None |
| `date` / `dateCreated` | Date of the transaction. Supported formats are in `getCommonDateFormats()` in the app source. | No | Current date |
| `amount` | Amount of the transaction. Income/expense type is determined by the category. | No | 0 |
| `title` / `name` | Title of the transaction. If an associated title is found and the category is not set, the associated title's category is used. | No | Empty string |
| `notes` / `note` | Notes for the transaction. | No | Empty string |
| `prompt` | Whether to prompt for initial inputs when `/addTransactionRoute` is used. Boolean. | No | `true` |
| `categoryPolarity` | Whether to use the category's polarity (income/expense). If disabled, the polarity of the amount is used (negative = expense, positive = income). Boolean. | No | `true` |
| `fallbackCategory` | Category/subcategory name to fall back to if (1) no category name/id is found or (2) no associated title/category pair is found. Avoids the forced "Select Category" prompt. Useful with an "Uncategorized" category. | No | None |

Transaction parameters are ordered by precedence. Parameters listed higher are parsed first, so overlapping fields are resolved by the first one that matches.

### Examples

Create a transaction with an amount of 100 in the Shopping category at the current date and time:

```
https://cashewapp.web.app/addTransaction?amount=100&title=All%20the%20shopping&category=Shopping&notes=Went%20shopping
```

Create a transaction with no category at the current date and time (the user is prompted for one):

```
https://cashewapp.web.app/addTransaction?amount=100&title=Income&notes=Got%20money
```

Open the add transaction page with a custom date and prefilled details:

```
https://cashewapp.web.app/addTransactionRoute?amount=50&title=All%20the%20shopping&notes=Went%20shopping&date=2024-03-02
```

## Add Multiple Transactions with JSON

| Endpoint | Description |
| --- | --- |
| `/addTransaction` | Add a new transaction without a UI prompt (unless a category is missing). |
| `/addTransactionRoute` | Open the add new transaction route with information filled in. |

| Parameter | Description | Required | Default |
| --- | --- | --- | --- |
| `JSON` | A list of JSON objects of transactions. Each object can use any single-transaction parameter above. | No | None |

Input format for `addTransaction` and `addTransactionRoute`:

```json
{
  "transactions": [
    { ... },
    { ... },
    { ... }
  ]
}
```

Example:

```json
{
  "transactions": [
    {
      "amount": "-100",
      "notes": "This is a note",
      "category": "Shopping"
    },
    {
      "amount": "-150",
      "notes": "This is a note 2"
    }
  ]
}
```

The JSON must be URL-encoded, because JSON contains characters that are invalid in URIs. The encoded link looks like:

```
https://cashewapp.web.app/addTransaction?JSON=%7B%22transactions%22%3A%5B%7B%22amount%22%3A%22-100%22%2C%20%22notes%22%3A%22This%20is%20a%20note%22%2C%20%22category%22%3A%22Shopping%22%7D%2C%7B%22amount%22%3A%22-150%22%2C%20%22notes%22%3A%22This%20is%20a%20note%202%22%7D%5D%7D
```

## Add Transfers

| Endpoint | Description |
| --- | --- |
| `/addTransferRoute` | Open the add new transfer route with information filled in. |

| Parameter | Description | Required | Default |
| --- | --- | --- | --- |
| `amountFrom` | Transfer deduction amount. | No | 0 |
| `amountTo` | Transfer addition amount. If not passed, an exchange rate between `walletFrom` and `walletTo` converts `amountFrom`. | No | Use exchange rate |
| `accountFrom` / `walletFrom` | Account to deduct from. Name search, first entry, not case sensitive. | No | Primary account |
| `accountTo` / `walletTo` | Account to add to. Name search, first entry, not case sensitive. | No | (none) |
| `title` / `name` | Title of the transfer transaction. | No | Empty string |
| `date` / `dateCreated` | Date of the transfer. Supported formats are in `getCommonDateFormats()`. | No | Current date |

## Correct Total Balance

| Endpoint | Description |
| --- | --- |
| `/correctTotalBalance` | Set the balance of an account to a certain amount. |
| `/correctTotalBalanceRoute` | Open the correct account balance route with information filled in. |

| Parameter | Description | Required | Default |
| --- | --- | --- | --- |
| `amount` | Amount to set the account to. | No | 0 |
| `subcategory` | Subcategory of the balance correction. Must be part of the balance correction main category. | No | 0 |
| `account` / `wallet` | Name of the account. Name search, first entry, not case sensitive. | No | Primary account |
| `title` / `name` | Title of the balance correction transaction. | No | Empty string |
| `date` / `dateCreated` | Date of the transaction. Supported formats are in `getCommonDateFormats()`. | No | Current date |

## Add Transaction by Parsing a Notification Message

The Notification/Message Parsing feature must be enabled in **Experimental Features** in Settings.

| Endpoint | Description |
| --- | --- |
| `/addTransaction/parseMessageForTransaction` | Add a new transaction by parsing a notification message with a Notification Scanner Template. |
| `/addTransactionRoute/parseMessageForTransaction` | Open the add new transaction page prefilled after parsing a notification message with a Notification Scanner Template. |

| Parameter | Description | Required | Default |
| --- | --- | --- | --- |
| `message` | The message to send to Cashew for parsing. | Yes | None |

## Add Transaction With Intelligence

The Intelligence feature must be enabled in **Experimental Features** in Settings. Processing the message can take some time after the app is opened.

| Endpoint | Description |
| --- | --- |
| `/addTransaction/intelligence` | Add a new transaction by parsing a prompt with AI. |
| `/addTransactionRoute/intelligence` | Open the add new transaction route after parsing a prompt with AI. |

| Parameter | Description | Required | Default |
| --- | --- | --- | --- |
| `prompt` / `message` | The prompt to send to the AI model. | Yes | None |

Example:

```
https://cashewapp.web.app/addTransactionRoute/intelligence?prompt=Spent%2035%24%20while%20going%20out%20for%20dinner%20yesterday%20and%20got%20a%20burger
```

## Opening Specific App Pages

| Endpoint | Description |
| --- | --- |
| `/addTransactionPage` | Open the add transaction page. |
| `/addTransferPage` | Open the add transfer page. |
| `/addBudgetPage` | Open the add budget page. |
| `/searchTransactionsPage` | Open the search transactions page. Use a `query` argument to search by that string. |
| `/notificationSettingsPage` | Open the notification settings page. |
| `/allSpendingPage` | Open the all spending summary page. |
| `/upcomingOverdueTransactionsPage` | Open the upcoming/overdue transactions page. |

Example:

```
https://cashewapp.web.app/searchTransactionsPage?query=Shopping
```

## Testing

### Using ADB for Android

```
adb shell am start -a android.intent.action.VIEW -d "https://cashewapp.web.app/addTransaction?amount=-70\&title=Grocery%20Shopping\&date=2024-03-02\&category=Food\&subcategory=Groceries\&notes=Bought%20fruits%20and%20vegetables\&account=test"
```

### Using links

Click a link to open it with Cashew. See the examples above.

## Changelog

- Introduce iOS support (Cashew v5.3.5+400 and up)
- Breaking: Remove unsupported app link domain `cashew://budget.app` (Cashew v5.3.4+396 and up)
- Support for more parameters documented under Detailed Parameters (Cashew v5.2.9+358 and up)
- Introduce Android and web support (Cashew v5.2.3+328 and up)

## Troubleshooting

Ensure the app is installed on the target device.

### Android

- If the link opens the website instead of the app, the device may not be set up to open App Links. Go to device settings, **Default apps**, **Opening links**, and make sure Cashew can open `cashewapp.web.app` under **Supported web addresses**.
- This may be disabled by default if Cashew was not installed from Google Play (for example, downloaded from GitHub). Cashew uses App Links, which Android 12+ verifies against the app's signing key.
- Alternatively, use a redirect app such as LinkSheet to choose which app opens a link.

### iOS

- Sometimes app links do not open automatically. Tap **Open** in the banner at the top of the webpage the link opened.

### Links that do not open the app

Links that use shorteners, tracking/redirect URLs, non-HTTPS, or a different subdomain/path than supported typically open in the browser. Some in-app browsers do not fully support App Links (Universal Links), so open the link in Safari.

### Web App

Links copied from this documentation use the mobile route (`cashewapp.web.app`). The web app's endpoint is its own address: `https://budget-track.web.app/[Endpoint here]`.

## Notes for maintainers

The App Links code at `budget/lib/widgets/util/appLinks.dart` (upstream `main`, commit `9cfbe50`, March 2026) only handles `addTransaction` and `addTransactionRoute`, with the `JSON` parameter and a debug-only `messageToParse` parameter. The transfer, balance-correction, notification-parsing, intelligence, and page endpoints above are not in that commit. Verify them against the Cashew version you target before relying on them. The Android manifest only routes `/addTransaction` and `/addTransactionRoute` to the app.
