import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/homePage/homePageNetWorth.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/spendingSummaryHelper.dart';
import 'package:budget/widgets/categorySpendingLegend.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/pieChart.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/util/keepAliveClientMixin.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

GlobalKey<StatsPageState> statsPageStateKey = GlobalKey();

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => StatsPageState();
}

class StatsPageState extends State<StatsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<PieChartDisplayState> _pieChartDisplayStateKey = GlobalKey();

  bool _isIncome = false;
  DateTime _currentDate = DateTime.now();
  String? _selectedCategoryPk;

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPeriod() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
      _selectedCategoryPk = null;
      _pieChartDisplayStateKey.currentState?.setTouchedIndex(-1);
    });
  }

  void _nextPeriod() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
      _selectedCategoryPk = null;
      _pieChartDisplayStateKey.currentState?.setTouchedIndex(-1);
    });
  }

  DateTimeRange _getDateRange() {
    final start = DateTime(_currentDate.year, _currentDate.month, 1);
    final end = DateTime(_currentDate.year, _currentDate.month + 1, 0, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  void _openPeriodSettings() async {
    await openBottomSheet(
      context,
      PopupFramework(
        title: "select-period".tr(),
        subtitle: "stats".tr(),
        child: const WalletPickerPeriodCycle(
          allWalletsSettingKey: "statsAllWallets",
          cycleSettingsExtension: "StatsPieChart",
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allWallets = Provider.of<AllWallets>(context);
    final dateRange = _getDateRange();
    final theme = Theme.of(context);
    final String monthYearLabel = DateFormat("MMM yyyy").format(_currentDate);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<CategoryWithTotal>>(
          stream: database.watchTotalSpentInEachCategoryInTimeRangeFromCategories(
            allWallets: allWallets,
            start: dateRange.start,
            end: dateRange.end,
            categoryFks: null,
            categoryFksExclude: null,
            budgetTransactionFilters: null,
            memberTransactionFilters: null,
            cycleSettingsExtension: "StatsPieChart",
            includeAllSubCategories: true,
            countUnassignedTransactions: true,
            isIncome: _isIncome,
          ),
          builder: (context, snapshot) {
            final TotalSpentCategoriesSummary s =
                watchTotalSpentInTimeRangeHelper(
              dataInput: snapshot.data ?? [],
              showAllSubcategories: true,
              multiplyTotalBy: 1,
              absoluteTotal: true,
            );

            // Stream for the other tab total to display amounts on both tab headers
            return StreamBuilder<List<CategoryWithTotal>>(
              stream: database
                  .watchTotalSpentInEachCategoryInTimeRangeFromCategories(
                allWallets: allWallets,
                start: dateRange.start,
                end: dateRange.end,
                categoryFks: null,
                categoryFksExclude: null,
                budgetTransactionFilters: null,
                memberTransactionFilters: null,
                cycleSettingsExtension: "StatsPieChart",
                includeAllSubCategories: true,
                countUnassignedTransactions: true,
                isIncome: !_isIncome,
              ),
              builder: (context, otherSnapshot) {
                final TotalSpentCategoriesSummary otherSummary =
                    watchTotalSpentInTimeRangeHelper(
                  dataInput: otherSnapshot.data ?? [],
                  showAllSubcategories: true,
                  multiplyTotalBy: 1,
                  absoluteTotal: true,
                );

                final double incomeTotal =
                    _isIncome ? s.totalSpent : otherSummary.totalSpent;
                final double expensesTotal =
                    _isIncome ? otherSummary.totalSpent : s.totalSpent;

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Top Navigation Header: < Month Year > and Period Button
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded,
                                      size: 28),
                                  onPressed: _previousPeriod,
                                  tooltip: "Previous month",
                                ),
                                const SizedBox(width: 4),
                                TextFont(
                                  text: monthYearLabel,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded,
                                      size: 28),
                                  onPressed: _nextPeriod,
                                  tooltip: "Next month",
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: _openPeriodSettings,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer
                                      .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    TextFont(
                                      text: "Monthly",
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      textColor: theme
                                          .colorScheme.onSecondaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: theme
                                          .colorScheme.onSecondaryContainer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Income / Expenses Tab Selector
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  if (!_isIncome) {
                                    setState(() {
                                      _isIncome = true;
                                      _selectedCategoryPk = null;
                                      _pieChartDisplayStateKey.currentState
                                          ?.setTouchedIndex(-1);
                                    });
                                  }
                                },
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: TextFont(
                                        text:
                                            "${"income".tr()} ${convertToMoney(allWallets, incomeTotal)}",
                                        fontSize: 15,
                                        fontWeight: _isIncome
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        textColor: _isIncome
                                            ? theme.colorScheme.onBackground
                                            : theme.colorScheme.onBackground
                                                .withOpacity(0.5),
                                      ),
                                    ),
                                    Container(
                                      height: 3,
                                      color: _isIncome
                                          ? const Color(0xFFFF6B6B)
                                          : Colors.transparent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  if (_isIncome) {
                                    setState(() {
                                      _isIncome = false;
                                      _selectedCategoryPk = null;
                                      _pieChartDisplayStateKey.currentState
                                          ?.setTouchedIndex(-1);
                                    });
                                  }
                                },
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: TextFont(
                                        text:
                                            "${"expenses".tr()} ${convertToMoney(allWallets, expensesTotal)}",
                                        fontSize: 15,
                                        fontWeight: !_isIncome
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        textColor: !_isIncome
                                            ? theme.colorScheme.onBackground
                                            : theme.colorScheme.onBackground
                                                .withOpacity(0.5),
                                      ),
                                    ),
                                    Container(
                                      height: 3,
                                      color: !_isIncome
                                          ? const Color(0xFFFF6B6B)
                                          : Colors.transparent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Pie Chart View
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: PieChartWrapper(
                            pieChartDisplayStateKey: _pieChartDisplayStateKey,
                            data: s.dataFilterUnassignedTransactions,
                            totalSpent: s.totalSpent,
                            setSelectedCategory: (categoryPk, category) {
                              setState(() {
                                if (categoryPk == "-1" || category == null) {
                                  _selectedCategoryPk = null;
                                } else {
                                  _selectedCategoryPk = categoryPk;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Full Category Spending Legend
                    if (s.dataFilterUnassignedTransactions.isNotEmpty)
                      SliverToBoxAdapter(
                        child: CategorySpendingLegend(
                          categoriesWithTotal:
                              s.dataFilterUnassignedTransactions,
                          subcategoriesMap:
                              s.subCategorySpendingIndexedByMainCategoryPk,
                          totalSpent: s.totalSpent,
                          selectedCategoryPk: _selectedCategoryPk,
                          onCategoryTapped: (categoryPk) {
                            setState(() {
                              if (categoryPk == null ||
                                  _selectedCategoryPk == categoryPk) {
                                _selectedCategoryPk = null;
                                _pieChartDisplayStateKey.currentState
                                    ?.setTouchedIndex(-1);
                              } else {
                                _selectedCategoryPk = categoryPk;
                                _pieChartDisplayStateKey.currentState
                                    ?.setTouchedCategoryPk(categoryPk);
                              }
                            });
                          },
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: TextFont(
                              text: _isIncome
                                  ? "no-income-within-period".tr()
                                  : "no-expense-within-period".tr(),
                              fontSize: 16,
                              textColor: theme.colorScheme.onBackground
                                  .withOpacity(0.6),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
