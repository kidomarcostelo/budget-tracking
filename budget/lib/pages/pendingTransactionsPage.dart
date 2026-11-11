import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/dedupeLedger.dart';
import 'package:budget/struct/initializeNotifications.dart';
import 'package:budget/struct/notificationsGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/globalSnackbar.dart';
import 'package:budget/widgets/noResults.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/openSnackbar.dart';
import 'package:budget/widgets/transactionEntry/transactionEntry.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class PendingTransactionsPage extends StatefulWidget {
  const PendingTransactionsPage({
    super.key,
    this.stream,
  });

  final Stream<List<TransactionWithCategory>>? stream;

  @override
  State<PendingTransactionsPage> createState() =>
      _PendingTransactionsPageState();
}

class _PendingTransactionsPageState extends State<PendingTransactionsPage> {
  Future<void> _approveAll(BuildContext context) async {
    await openPopup(
      context,
      title: "approve-all".tr(),
      description: "all-transactions-approved".tr(),
      icon: appStateSettings["outlinedIcons"]
          ? Icons.done_all_outlined
          : Icons.done_all_rounded,
      onSubmitLabel: "approve".tr(),
      onSubmit: () async {
        final pendingTxs = await database.watchPendingTransactions().first;
        await database.approveAllPendingTransactions();
        for (final item in pendingTxs) {
          await cancelPendingTransactionNotification(
              item.transaction.transactionPk);
        }
        await flutterLocalNotificationsPlugin.cancel(0);
        openSnackbar(SnackbarMessage(
          title: "all-transactions-approved".tr(),
          icon: appStateSettings["outlinedIcons"]
              ? Icons.check_circle_outline
              : Icons.check_circle_rounded,
        ));
      },
    );
  }

  Future<void> _dismissAll(BuildContext context) async {
    await openPopup(
      context,
      title: "dismiss-all".tr(),
      description: "all-transactions-dismissed".tr(),
      icon: appStateSettings["outlinedIcons"]
          ? Icons.delete_sweep_outlined
          : Icons.delete_sweep_rounded,
      onSubmitLabel: "dismiss".tr(),
      onSubmit: () async {
        final pendingTxs = await database.watchPendingTransactions().first;
        await database.dismissAllPendingTransactions();
        for (final item in pendingTxs) {
          await cancelPendingTransactionNotification(
              item.transaction.transactionPk);
        }
        await flutterLocalNotificationsPlugin.cancel(0);
        openSnackbar(SnackbarMessage(
          title: "all-transactions-dismissed".tr(),
          icon: appStateSettings["outlinedIcons"]
              ? Icons.delete_outline
              : Icons.delete_rounded,
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionWithCategory>>(
      initialData: const [],
      stream: widget.stream ?? database.watchPendingTransactions(),
      builder: (context, snapshot) {
        final List<TransactionWithCategory> items = snapshot.data ?? [];
        final bool hasItems = items.isNotEmpty;

        return PageFramework(
          title: "pending-transactions".tr(),
          backButton: true,
          actions: hasItems
              ? [
                  IconButton(
                    tooltip: "approve-all".tr(),
                    icon: Icon(appStateSettings["outlinedIcons"]
                        ? Icons.done_all_outlined
                        : Icons.done_all_rounded),
                    onPressed: () => _approveAll(context),
                  ),
                  IconButton(
                    tooltip: "dismiss-all".tr(),
                    icon: Icon(appStateSettings["outlinedIcons"]
                        ? Icons.delete_sweep_outlined
                        : Icons.delete_sweep_rounded),
                    onPressed: () => _dismissAll(context),
                  ),
                ]
              : null,
          slivers: [
            if (snapshot.hasData && !hasItems)
              SliverToBoxAdapter(
                child: Center(
                  child: NoResults(
                    message: "no-pending-transactions".tr(),
                  ),
                ),
              )
            else if (hasItems)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    final String pk = item.transaction.transactionPk;
                    final dedupeEntry = DedupeLedger.instance
                        .getUncertainEntryForTransaction(pk);
                    final bool isPossibleDuplicate = dedupeEntry != null;

                    return Dismissible(
                      key: ValueKey("pending_$pk"),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        color: getColor(context, "incomeAmount"),
                        alignment: AlignmentDirectional.centerStart,
                        padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              "approve".tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        color: getColor(context, "expenseAmount"),
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "dismiss".tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.delete_outline,
                                color: Colors.white, size: 28),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await database.approvePendingTransaction(pk);
                          await cancelPendingTransactionNotification(pk);
                          openSnackbar(SnackbarMessage(
                            title: "transaction-approved".tr(),
                            icon: appStateSettings["outlinedIcons"]
                                ? Icons.check_circle_outline
                                : Icons.check_circle_rounded,
                          ));
                          return true;
                        } else {
                          await database.dismissPendingTransaction(pk);
                          await cancelPendingTransactionNotification(pk);
                          openSnackbar(SnackbarMessage(
                            title: "transaction-dismissed".tr(),
                            icon: appStateSettings["outlinedIcons"]
                                ? Icons.delete_outline
                                : Icons.delete_rounded,
                          ));
                          return true;
                        }
                      },
                      child: Column(
                        children: [
                          HorizontalBreak(
                            padding: const EdgeInsetsDirectional.only(
                                top: 4, bottom: 6),
                          ),
                          TransactionEntry(
                            transaction: item.transaction,
                            category: item.category,
                            aboveWidget: isPossibleDuplicate
                                ? Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        start: 18, bottom: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 15,
                                          color: getColor(
                                              context, "warningAmount"),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "possible-duplicate-detected".tr(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: getColor(
                                                context, "warningAmount"),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                            openPage: AddTransactionPage(
                              transaction: item.transaction,
                              routesToPopAfterDelete:
                                  RoutesToPopAfterDelete.One,
                              isPossibleDuplicate: isPossibleDuplicate,
                              possibleDuplicateEntry: dedupeEntry,
                            ),
                            listID: "pendingTransactions",
                          ),
                          if (index == items.length - 1)
                            HorizontalBreak(
                              padding: const EdgeInsetsDirectional.only(
                                  top: 4, bottom: 6),
                            ),
                        ],
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
          ],
        );
      },
    );
  }
}
