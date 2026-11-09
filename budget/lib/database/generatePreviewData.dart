import 'dart:math';
import 'package:budget/colors.dart';
import 'package:budget/database/initializeDefaultDatabase.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/pages/addWalletPage.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/notificationsSettings.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/viewAllTransactionsButton.dart';
import 'package:budget/widgets/walletEntry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

Future deletePreviewData({bool resetOnboard = false}) async {
  if (resetOnboard) {
    updateSettings("hasOnboarded", false, updateGlobalState: true);
  }

  loadingIndeterminateKey.currentState?.setVisibility(true);
  try {
    await cancelUpcomingTransactionsNotification();
  } catch (e) {
    print(e.toString());
  }

  try {
    List<Transaction> transactionsToDelete =
        await database.getAllPreviewTransactions();
    List<String> transactionPks = transactionsToDelete
        .map((transaction) => transaction.transactionPk)
        .toList();
    await database.deleteTransactions(transactionPks, updateSharedEntry: false);
  } catch (e) {
    print(e.toString());
  }

  try {
    await database.deleteWallet("10", 1);
  } catch (e) {
    print(e.toString());
  }
  try {
    await database.deleteWallet("11", 2);
  } catch (e) {
    print(e.toString());
  }
  try {
    await database.deleteWallet("12", 3);
  } catch (e) {
    print(e.toString());
  }
  try {
    await database.forceDeleteBudgets(["10", "11"]);
  } catch (e) {
    print(e.toString());
  }
  try {
    await database.forceDeleteObjectives(["10", "11"]);
  } catch (e) {
    print(e.toString());
  }

  await database.createOrUpdateWallet(
    defaultWallet(),
    customDateTimeModified: DateTime(0),
  );

  await setPrimaryWallet("0");

  await database.deleteAllDeleteLogs();

  await createDefaultCategories();
  await initializeBalanceCorrectionCategory();

  loadingIndeterminateKey.currentState?.setVisibility(false);
  updateSettings("previewDemo", false, updateGlobalState: false);
  updateSettings("accountOwnerName", "", updateGlobalState: false);
}

Future generatePreviewData() async {
  updateSettings("previewDemo", true, updateGlobalState: false);
  updateSettings("accountOwnerName", "Kid Omar Costelo",
      updateGlobalState: false);
  loadingIndeterminateKey.currentState?.setVisibility(true);
  await createDefaultCategories();
  await initializeBalanceCorrectionCategory();
  await database.createOrUpdateWallet(
    TransactionWallet(
      walletPk: "0",
      name: "UnionBank",
      colour: "0xffff7900",
      iconName: null,
      dateCreated: DateTime.now(),
      dateTimeModified: null,
      order: 0,
      currency: "php",
      decimals: 2,
      homePageWidgetDisplay: defaultWalletHomePageWidgetDisplay,
    ),
  );
  await database.createOrUpdateWallet(
    TransactionWallet(
      walletPk: "10",
      name: "MariBank",
      colour: "0xfffa5a2a",
      iconName: null,
      dateCreated: DateTime.now(),
      dateTimeModified: null,
      order: 1,
      currency: "php",
      decimals: 2,
      homePageWidgetDisplay: defaultWalletHomePageWidgetDisplay,
    ),
  );
  await database.createOrUpdateWallet(
    TransactionWallet(
      walletPk: "11",
      name: "GoTyme",
      colour: "0xff00d084",
      iconName: null,
      dateCreated: DateTime.now(),
      dateTimeModified: null,
      order: 2,
      currency: "php",
      decimals: 2,
      homePageWidgetDisplay: defaultWalletHomePageWidgetDisplay,
    ),
  );
  await database.createOrUpdateWallet(
    TransactionWallet(
      walletPk: "12",
      name: "Maya",
      colour: "0xff2bb673",
      iconName: null,
      dateCreated: DateTime.now(),
      dateTimeModified: null,
      order: 3,
      currency: "php",
      decimals: 2,
      homePageWidgetDisplay: defaultWalletHomePageWidgetDisplay,
    ),
  );
  DateTime tripStart = DateTime.now().subtract(Duration(days: 7));
  DateTime tripEnd = DateTime.now().add(Duration(days: 14));
  await database.createOrUpdateBudget(
    updateSharedEntry: false,
    Budget(
      budgetPk: "10",
      name: "Vacation",
      amount: 25000.0,
      colour: "0xffef5350",
      startDate: tripStart.subtract(Duration(minutes: 24)),
      endDate: tripEnd,
      categoryFks: [],
      addedTransactionsOnly: true,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.custom,
      dateCreated: DateTime.now(),
      dateTimeModified: null,
      pinned: true,
      order: 1,
      walletFk: "0",
      isAbsoluteSpendingLimit: true,
      income: false,
      archived: false,
    ),
  );
  await database.createOrUpdateObjective(
    Objective(
      objectivePk: "10",
      name: "Emergency Fund",
      amount: 50000.0,
      order: 0,
      colour: "0xff66bb6a",
      dateCreated: DateTime.now().subtract(Duration(days: 5)),
      dateTimeModified: DateTime.now(),
      iconName: "piggy-bank.png",
      emojiIconName: null,
      income: true,
      pinned: true,
      walletFk: "10",
      archived: false,
      type: ObjectiveType.goal,
    ),
  );
  await database.createOrUpdateObjective(
    Objective(
      objectivePk: "11",
      name: "Trip Savings Jar",
      amount: 20000.0,
      order: 1,
      colour: "0xffff7043",
      dateCreated: DateTime.now().subtract(Duration(days: 25)),
      dateTimeModified: DateTime.now(),
      iconName: "coconut-tree.png",
      emojiIconName: null,
      income: true,
      pinned: true,
      walletFk: "0",
      archived: false,
      type: ObjectiveType.goal,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      objectiveFk: "10",
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Emergency fund deposit",
      amount: 15000.0,
      note: "Initial deposit into MariBank savings",
      categoryFk: "11",
      walletFk: "10",
      dateCreated: DateTime.now().subtract(Duration(days: 4)),
      dateTimeModified: null,
      income: true,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      objectiveFk: "11",
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Trip savings deposit",
      amount: 5000.0,
      note: "Monthly savings for vacation",
      categoryFk: "11",
      walletFk: "0",
      dateCreated: tripStart.subtract(Duration(days: 4)),
      dateTimeModified: null,
      income: true,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Cebu Pacific Flight",
      amount: -4500.0,
      note: "Manila to Caticlan roundtrip",
      categoryFk: "10",
      walletFk: "0",
      dateCreated: tripStart.subtract(Duration(minutes: 41)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
      sharedReferenceBudgetPk: "10",
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Resort Hotel Booking",
      amount: -8200.0,
      note: "3 nights accommodation",
      categoryFk: "10",
      walletFk: "0",
      dateCreated: tripStart.subtract(Duration(minutes: 15)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
      sharedReferenceBudgetPk: "10",
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Meralco Electricity",
      amount: -3450.0,
      note: "UnionBank Online • Ref: UB982341",
      categoryFk: "6",
      walletFk: "0",
      dateCreated:
          tripStart.add(Duration(days: 2)).subtract(Duration(minutes: 41)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Converge Fiber Internet",
      amount: -1699.0,
      note: "Monthly Plan 1699",
      categoryFk: "6",
      walletFk: "0",
      dateCreated:
          tripStart.add(Duration(days: 3)).subtract(Duration(minutes: 20)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Starbucks Coffee",
      amount: -185.0,
      note: "UnionBank Rewards Platinum •••• 3353",
      categoryFk: "1",
      walletFk: "0",
      dateCreated:
          tripStart.add(Duration(days: 2)).subtract(Duration(minutes: 39)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "7-Eleveb-ST4594",
      amount: -123.0,
      note: "UnionBank Rewards Platinum •••• 3353",
      categoryFk: "2",
      walletFk: "0",
      dateCreated:
          tripStart.add(Duration(days: 4)).subtract(Duration(minutes: 34)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "GrabFood",
      amount: -340.0,
      note: "UnionBank Debit •••• 9227",
      categoryFk: "1",
      walletFk: "0",
      dateCreated:
          tripStart.add(Duration(days: 1)).subtract(Duration(minutes: 27)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Shopee",
      amount: -890.0,
      note: "MariBank Direct Debit",
      categoryFk: "3",
      walletFk: "10",
      dateCreated:
          tripStart.add(Duration(days: 4)).subtract(Duration(minutes: 23)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Mercury Drug",
      amount: -450.0,
      note: "GoTyme Debit •••• 3887",
      categoryFk: "8",
      walletFk: "11",
      dateCreated:
          tripStart.add(Duration(days: 3)).subtract(Duration(minutes: 8)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "GrabCar",
      amount: -280.0,
      note: "Maya Wallet (+63 956 857 9768)",
      categoryFk: "4",
      walletFk: "12",
      dateCreated:
          tripStart.add(Duration(days: 5)).subtract(Duration(minutes: 18)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Jollibee",
      amount: -650.0,
      note: "Maya QR Payment",
      categoryFk: "1",
      walletFk: "12",
      dateCreated:
          tripStart.add(Duration(days: 6)).subtract(Duration(minutes: 12)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  int monthlySpendingDayStart = DateTime.now().day <= 10 ? 15 : 2;
  await database.createOrUpdateBudget(
    updateSharedEntry: false,
    Budget(
      budgetPk: "11",
      name: "Monthly Spending",
      amount: 35000.0,
      colour: null,
      startDate: DateTime(DateTime.now().year, DateTime.now().month,
              monthlySpendingDayStart)
          .subtract(Duration(minutes: 19)),
      endDate: DateTime.now(),
      categoryFks: null,
      addedTransactionsOnly: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      dateCreated: DateTime.now(),
      dateTimeModified: null,
      pinned: true,
      order: 0,
      walletFk: "0",
      budgetTransactionFilters: [],
      memberTransactionFilters: null,
      sharedKey: null,
      sharedOwnerMember: null,
      sharedDateUpdated: null,
      sharedMembers: null,
      sharedAllMembersEver: null,
      isAbsoluteSpendingLimit: false,
      income: false,
      archived: false,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Payroll",
      amount: 45000.0,
      note: "Salary Crediting - UnionBank",
      categoryFk: "11",
      walletFk: "0",
      dateCreated: DateTime(DateTime.now().year, DateTime.now().month - 2, 15)
          .subtract(Duration(minutes: 17)),
      dateTimeModified: null,
      income: true,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Payroll",
      amount: 45000.0,
      note: "Salary Crediting - UnionBank",
      categoryFk: "11",
      walletFk: "0",
      dateCreated: DateTime(DateTime.now().year, DateTime.now().month - 1, 15)
          .subtract(Duration(minutes: 13)),
      dateTimeModified: null,
      income: true,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Payroll",
      amount: 45000.0,
      note: "Salary Crediting - UnionBank",
      categoryFk: "11",
      walletFk: "0",
      dateCreated:
          DateTime.now().firstDayOfMonth().subtract(Duration(minutes: 35)),
      dateTimeModified: null,
      income: true,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: null,
      paid: true,
      createdAnotherFutureTransaction: false,
      skipPaid: true,
    ),
  );

  // Self-transfer 1: UnionBank -> MariBank (₱15,000)
  DateTime ubTransferDate = DateTime.now().subtract(Duration(days: 12));
  int? ubInRowId = await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "MariBank transfer-in",
      amount: 15000.0,
      note: "Transferred balance\nUnionBank → MariBank\nRef: UB1663112",
      categoryFk: "0",
      walletFk: "10",
      dateCreated: ubTransferDate.add(Duration(seconds: 1)),
      dateTimeModified: null,
      income: true,
      paid: true,
      skipPaid: false,
    ),
  );
  String? ubInPk;
  if (ubInRowId != null) {
    final t = await database.getTransactionFromRowId(ubInRowId);
    ubInPk = t.transactionPk;
  }
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      pairedTransactionFk: ubInPk,
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "UnionBank transfer-out",
      amount: -15000.0,
      note: "Transferred balance\nUnionBank → MariBank\nRef: UB1663112",
      categoryFk: "0",
      walletFk: "0",
      dateCreated: ubTransferDate,
      dateTimeModified: null,
      income: false,
      paid: true,
      skipPaid: false,
    ),
  );

  // Self-transfer 2: MariBank -> Maya (₱1,000)
  DateTime mbTransferDate = DateTime.now().subtract(Duration(days: 6));
  int? mbInRowId = await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Maya transfer-in",
      amount: 1000.0,
      note: "Transferred balance\nMariBank → Maya\nRef: 454658",
      categoryFk: "0",
      walletFk: "12",
      dateCreated: mbTransferDate.add(Duration(seconds: 1)),
      dateTimeModified: null,
      income: true,
      paid: true,
      skipPaid: false,
    ),
  );
  String? mbInPk;
  if (mbInRowId != null) {
    final t = await database.getTransactionFromRowId(mbInRowId);
    mbInPk = t.transactionPk;
  }
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      pairedTransactionFk: mbInPk,
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "MariBank transfer-out",
      amount: -1000.0,
      note: "Transferred balance\nMariBank → Maya\nRef: 454658",
      categoryFk: "0",
      walletFk: "10",
      dateCreated: mbTransferDate,
      dateTimeModified: null,
      income: false,
      paid: true,
      skipPaid: false,
    ),
  );

  // Self-transfer 3: GoTyme -> MariBank (₱3,600)
  DateTime gtTransferDate = DateTime.now().subtract(Duration(days: 8));
  int? gtInRowId = await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "MariBank transfer-in",
      amount: 3600.0,
      note: "Transferred balance\nGoTyme → MariBank\nRef: ITO261019143038004",
      categoryFk: "0",
      walletFk: "10",
      dateCreated: gtTransferDate.add(Duration(seconds: 1)),
      dateTimeModified: null,
      income: true,
      paid: true,
      skipPaid: false,
    ),
  );
  String? gtInPk;
  if (gtInRowId != null) {
    final t = await database.getTransactionFromRowId(gtInRowId);
    gtInPk = t.transactionPk;
  }
  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      pairedTransactionFk: gtInPk,
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "GoTyme transfer-out",
      amount: -3600.0,
      note: "Transferred balance\nGoTyme → MariBank\nRef: ITO261019143038004",
      categoryFk: "0",
      walletFk: "11",
      dateCreated: gtTransferDate,
      dateTimeModified: null,
      income: false,
      paid: true,
      skipPaid: false,
    ),
  );

  await database.createOrUpdateTransaction(
    updateSharedEntry: false,
    insert: true,
    Transaction(
      methodAdded: MethodAdded.preview,
      transactionPk: "-1",
      name: "Netflix Subscription",
      amount: -549.0,
      note: "Premium Plan",
      categoryFk: "5",
      walletFk: "12",
      dateCreated:
          DateTime.now().add(Duration(days: 2)).subtract(Duration(minutes: 20)),
      dateTimeModified: null,
      income: false,
      periodLength: 1,
      reoccurrence: BudgetReoccurence.monthly,
      upcomingTransactionNotification: true,
      type: TransactionSpecialType.subscription,
      paid: false,
      createdAnotherFutureTransaction: false,
      skipPaid: false,
    ),
  );
  await database.createOrUpdateCategoryLimit(
    insert: true,
    CategoryBudgetLimit(
      categoryLimitPk: "-1",
      categoryFk: "1",
      budgetFk: "11",
      amount: 10000.0,
      dateTimeModified: DateTime.now(),
      walletFk: "0",
    ),
  );
  await database.createOrUpdateCategoryLimit(
    insert: true,
    CategoryBudgetLimit(
      categoryLimitPk: "-1",
      categoryFk: "2",
      budgetFk: "11",
      amount: 12000.0,
      dateTimeModified: DateTime.now(),
      walletFk: "0",
    ),
  );
  await database.createOrUpdateCategoryLimit(
    insert: true,
    CategoryBudgetLimit(
      categoryLimitPk: "-1",
      categoryFk: "3",
      budgetFk: "11",
      amount: 8000.0,
      dateTimeModified: DateTime.now(),
      walletFk: "0",
    ),
  );
  await database.createOrUpdateCategoryLimit(
    insert: true,
    CategoryBudgetLimit(
      categoryLimitPk: "-1",
      categoryFk: "10",
      budgetFk: "10",
      amount: 15000.0,
      dateTimeModified: DateTime.now(),
      walletFk: "0",
    ),
  );
  loadingIndeterminateKey.currentState?.setVisibility(false);
  List<String> previewWalletPks = ["0", "10", "11", "12"];
  for (int i = 0; i < 20; i++) {
    List<int> moreCommonCategories = [1, 2, 3, 4, 5];
    List<int> moreCommonCommonCategories = [1, 2, 4];
    await database.createOrUpdateTransaction(
      updateSharedEntry: false,
      insert: true,
      Transaction(
        methodAdded: MethodAdded.preview,
        transactionPk: "-1",
        name: "",
        amount: (150 + Random().nextDouble() * 350) * -1,
        note: "",
        categoryFk: (Random().nextInt(2) == 0
                ? Random().nextInt(2) == 0
                    ? moreCommonCategories[
                        Random().nextInt(moreCommonCommonCategories.length)]
                    : moreCommonCategories[
                        Random().nextInt(moreCommonCategories.length)]
                : Random().nextInt(11) + 1)
            .toString(),
        walletFk: previewWalletPks[Random().nextInt(previewWalletPks.length)],
        dateCreated: DateTime.now()
            .subtract(Duration(days: i))
            .subtract(Duration(minutes: i * 13)),
        income: false,
        paid: true,
        skipPaid: true,
      ),
    );
  }
  for (int i = 5; i < 300; i = i + Random().nextInt(4)) {
    List<int> moreCommonCategories = [1, 2, 3, 4, 5];
    List<int> moreCommonCommonCategories = [1, 2, 4];
    loadingProgressKey.currentState?.setProgressPercentage(i / 300);
    await database.createOrUpdateTransaction(
      updateSharedEntry: false,
      insert: true,
      Transaction(
        methodAdded: MethodAdded.preview,
        transactionPk: "-1",
        name: "",
        amount: (50 + Random().nextDouble() * 1200) * -1,
        note: "",
        categoryFk: (Random().nextInt(2) == 0
                ? Random().nextInt(2) == 0
                    ? moreCommonCategories[
                        Random().nextInt(moreCommonCommonCategories.length)]
                    : moreCommonCategories[
                        Random().nextInt(moreCommonCategories.length)]
                : Random().nextInt(11) + 1)
            .toString(),
        walletFk: previewWalletPks[Random().nextInt(previewWalletPks.length)],
        dateCreated: DateTime.now()
            .subtract(Duration(days: i))
            .subtract(Duration(minutes: i * 2)),
        income: false,
        paid: true,
        skipPaid: true,
      ),
    );
  }
  loadingProgressKey.currentState?.setProgressPercentage(0);

  for (int i = 90; i < 320; i = i + 25 + Random().nextInt(10)) {
    loadingIndeterminateKey.currentState?.setVisibility(true);
    await database.createOrUpdateTransaction(
      updateSharedEntry: false,
      insert: true,
      Transaction(
        methodAdded: MethodAdded.preview,
        transactionPk: "-1",
        name: "Side Income",
        amount: 2500 + Random().nextDouble() * 5000,
        note: "",
        categoryFk: "11",
        walletFk: (Random().nextInt(2) == 0 ? "0" : "10"),
        dateCreated: DateTime.now()
            .subtract(Duration(days: i))
            .subtract(Duration(minutes: i * 2)),
        income: true,
        paid: true,
        skipPaid: true,
      ),
    );
  }

  // if (allowDangerousDebugFlags) {
  //   // Large database test

  //   List<TransactionsCompanion> insert = [];

  //   for (int i = 0; i < 35000; i++) {
  //     insert.add(
  //       Transaction(
  //         methodAdded: MethodAdded.preview,
  //         transactionPk: uuid.v4(),
  //         name: "",
  //         amount: -(10 + Random().nextDouble() * 200),
  //         note: "",
  //         categoryFk: (Random().nextInt(2) == 0 ? 6 : 10).toString(),
  //         walletFk: "0",
  //         dateCreated: DateTime.now().subtract(Duration(days: i)),
  //         income: false,
  //         paid: true,
  //         skipPaid: true,
  //       ).toCompanion(true),
  //     );
  //   }
  //   for (int i = 0; i < 35000; i++) {
  //     insert.add(
  //       Transaction(
  //         methodAdded: MethodAdded.preview,
  //         transactionPk: uuid.v4(),
  //         name: "",
  //         amount: -(10 + Random().nextDouble() * 200),
  //         note: "",
  //         categoryFk: (Random().nextInt(2) == 0 ? 6 : 10).toString(),
  //         walletFk: "0",
  //         dateCreated: DateTime.now().subtract(Duration(days: i)),
  //         income: false,
  //         paid: true,
  //         skipPaid: true,
  //       ).toCompanion(true),
  //     );
  //   }
  //   await database.createBatchTransactionsOnly(insert);
  // }

  loadingIndeterminateKey.currentState?.setVisibility(false);
}

class PreviewDemoWarning extends StatelessWidget {
  const PreviewDemoWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return appStateSettings["previewDemo"] == true
        ? Padding(
            padding: EdgeInsetsDirectional.only(
                bottom: MediaQuery.viewPaddingOf(context).top),
            child: Tappable(
              onTap: () async {
                deletePreviewData(resetOnboard: true);
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20, vertical: 10),
                child: TextFont(
                  text: "preview-demo-warning".tr(),
                  textColor: Theme.of(context).colorScheme.onError,
                  fontSize: 15,
                  maxLines: 10,
                ),
              ),
              color: Theme.of(context).colorScheme.error,
            ),
          )
        : SizedBox.shrink();
  }
}

class PreviewDemoButton extends StatelessWidget {
  const PreviewDemoButton({required this.nextNavigation, super.key});
  final Function nextNavigation;

  @override
  Widget build(BuildContext context) {
    // Only allow preview demo if the language is English
    if (context.locale.toString() == "en") {
      return LowKeyButton(
        onTap: () {
          openPopup(
            context,
            title: "preview-demo".tr(),
            description: "preview-demo-description".tr(),
            onCancel: () {
              popRoute(context);
            },
            onCancelLabel: "cancel".tr(),
            onSubmit: () {
              popRoute(context);
              nextNavigation(generatePreview: true);
            },
            onSubmitLabel: "activate".tr(),
          );
        },
        text: "preview-demo".tr(),
        extraWidget: Padding(
          padding: const EdgeInsetsDirectional.only(start: 5),
          child: Icon(
            Icons.help,
            size: 17,
            color: getColor(context, "black").withOpacity(0.5),
          ),
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }
}

Future<bool> checkLockedFeatureIfInDemoMode(BuildContext? context) async {
  if (context == null && appStateSettings["previewDemo"] == true) return false;
  if (appStateSettings["previewDemo"] == true) {
    await openPopup(
      context!,
      icon: appStateSettings["outlinedIcons"]
          ? Icons.warning_outlined
          : Icons.warning_rounded,
      title: "not-available-in-preview-demo".tr(),
      description: "not-available-in-preview-demo-description".tr(),
      onCancel: () {
        popRoute(context);
      },
      onCancelLabel: "cancel".tr(),
      onSubmit: () {
        popAllRoutes(context);
        deletePreviewData(resetOnboard: true);
      },
      onSubmitLabel: "exit-demo".tr(),
    );
    return false;
  }
  return true;
}
