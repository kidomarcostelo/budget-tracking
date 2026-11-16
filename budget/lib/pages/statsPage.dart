import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addBudgetPage.dart';
import 'package:budget/pages/homePage/homePageNetWorth.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/spendingSummaryHelper.dart';
import 'package:budget/widgets/categorySpendingLegend.dart';
import 'package:budget/widgets/framework/popupFramework.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/periodCyclePicker.dart';
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
  int _cycleOffset = 0;
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
      _cycleOffset += 1;
      _selectedCategoryPk = null;
      _pieChartDisplayStateKey.currentState?.setTouchedIndex(-1);
    });
  }

  void _nextPeriod() {
    setState(() {
      _cycleOffset -= 1;
      _selectedCategoryPk = null;
      _pieChartDisplayStateKey.currentState?.setTouchedIndex(-1);
    });
  }

  CycleType _getSelectedPeriodType() {
    return CycleType.values[
        appStateSettings["selectedPeriodCycleTypeStatsPieChart"] ??
            CycleType.cycle.index];
  }

  DateTimeRange? _getDateRange(CycleType selectedPeriodType) {
    if (selectedPeriodType == CycleType.allTime) {
      return null;
    } else if (selectedPeriodType == CycleType.cycle) {
      final Budget tempBudget = getCustomCycleTempBudget("StatsPieChart");
      final DateTime datePast =
          getDatePastToDetermineBudgetDate(_cycleOffset, tempBudget);
      return getCycleDateTimeRange("StatsPieChart", currentDate: datePast);
    } else if (selectedPeriodType == CycleType.pastDays) {
      final DateTime startDate =
          getStartDateOfSelectedCustomPeriod("StatsPieChart") ?? DateTime.now();
      final DateTime endDate =
          getEndDateOfSelectedCustomPeriod("StatsPieChart") ?? DateTime.now();
      return DateTimeRange(start: startDate, end: endDate);
    } else if (selectedPeriodType == CycleType.dateRange) {
      final DateTime startDate =
          getStartDateOfSelectedCustomPeriod("StatsPieChart") ?? DateTime.now();
      final DateTime? endDate =
          getEndDateOfSelectedCustomPeriod("StatsPieChart");
      return DateTimeRange(
        start: startDate,
        end: endDate ?? DateTime.now().justDay(yearOffset: 100),
      );
    }
    return null;
  }

  String _getPeriodTitle(
      CycleType selectedPeriodType, DateTimeRange? budgetRange) {
    if (selectedPeriodType == CycleType.allTime || budgetRange == null) {
      return "all-time".tr();
    } else if (selectedPeriodType == CycleType.cycle) {
      final Budget tempBudget = getCustomCycleTempBudget("StatsPieChart");
      if (tempBudget.reoccurrence == BudgetReoccurence.monthly &&
          tempBudget.periodLength == 1) {
        return DateFormat("MMM yyyy").format(budgetRange.start);
      }
      return "${getWordedDateShort(budgetRange.start)} – ${getWordedDateShort(budgetRange.end)}";
    } else if (selectedPeriodType == CycleType.pastDays) {
      final int days =
          appStateSettings["customPeriodPastDaysStatsPieChart"] ?? 30;
      return "${"previous".tr()} $days ${days == 1 ? "day".tr() : "days".tr()}";
    } else if (selectedPeriodType == CycleType.dateRange) {
      final DateTime startDate =
          getStartDateOfSelectedCustomPeriod("StatsPieChart") ?? DateTime.now();
      final DateTime? endDate =
          getEndDateOfSelectedCustomPeriod("StatsPieChart");
      return "${getWordedDateShort(startDate)}${endDate == null ? ' ' + 'onwards'.tr().toLowerCase() : ' – ' + getWordedDateShort(endDate)}";
    }
    return "";
  }

  String _getPeriodCycleButtonLabel(CycleType selectedPeriodType) {
    if (selectedPeriodType == CycleType.allTime) {
      return "all-time".tr();
    } else if (selectedPeriodType == CycleType.cycle) {
      final Budget tempBudget = getCustomCycleTempBudget("StatsPieChart");
      if (tempBudget.periodLength == 1) {
        final dynamic recName = nameRecurrence[tempBudget.reoccurrence];
        if (recName != null) {
          return recName.toString().toLowerCase().tr().capitalizeFirst;
        }
        return "monthly".tr();
      } else {
        final dynamic recNames = namesRecurrence[tempBudget.reoccurrence];
        return "${tempBudget.periodLength} ${(recNames ?? "months").toString().toLowerCase().tr()}";
      }
    } else if (selectedPeriodType == CycleType.pastDays) {
      return "past-days".tr();
    } else if (selectedPeriodType == CycleType.dateRange) {
      return "custom".tr();
    }
    return "monthly".tr();
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
    if (mounted) {
      setState(() {
        _cycleOffset = 0;
        _selectedCategoryPk = null;
        _pieChartDisplayStateKey.currentState?.setTouchedIndex(-1);
      });
    }
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
    final selectedPeriodType = _getSelectedPeriodType();
    final dateRange = _getDateRange(selectedPeriodType);
    final periodTitle = _getPeriodTitle(selectedPeriodType, dateRange);
    final cycleButtonLabel = _getPeriodCycleButtonLabel(selectedPeriodType);
    final bool canNavigate = selectedPeriodType == CycleType.cycle;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<CategoryWithTotal>>(
          stream: database.watchTotalSpentInEachCategoryInTimeRangeFromCategories(
            allWallets: allWallets,
            start: dateRange?.start ?? DateTime.now(),
            end: dateRange?.end ?? DateTime.now(),
            categoryFks: null,
            categoryFksExclude: null,
            budgetTransactionFilters: null,
            memberTransactionFilters: null,
            allTime: selectedPeriodType == CycleType.allTime,
            followCustomPeriodCycle: true,
            cycleSettingsExtension: "StatsPieChart",
            forcedDateTimeRange: dateRange,
            includeAllSubCategories: true,
            countUnassignedTransactions: true,
            isIncome: null,
          ),
          builder: (context, snapshot) {
            final allCategories = snapshot.data ?? [];
            final incomeCategories =
                allCategories.where((c) => c.category.income == true).toList();
            final expenseCategories =
                allCategories.where((c) => c.category.income != true).toList();

            final TotalSpentCategoriesSummary incomeSummary =
                watchTotalSpentInTimeRangeHelper(
              dataInput: incomeCategories,
              showAllSubcategories: true,
              multiplyTotalBy: 1,
              absoluteTotal: true,
            );

            final TotalSpentCategoriesSummary expenseSummary =
                watchTotalSpentInTimeRangeHelper(
              dataInput: expenseCategories,
              showAllSubcategories: true,
              multiplyTotalBy: 1,
              absoluteTotal: true,
            );

            final double incomeTotal = incomeSummary.totalSpent;
            final double expensesTotal = expenseSummary.totalSpent;
            final TotalSpentCategoriesSummary activeSummary =
                _isIncome ? incomeSummary : expenseSummary;

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Top Navigation Header: < Period Title > and Period Setting Button
                SliverToBoxAdapter(
                  child: _StatsPeriodHeader(
                    title: periodTitle,
                    cycleButtonLabel: cycleButtonLabel,
                    canNavigate: canNavigate,
                    onPrevious: _previousPeriod,
                    onNext: _nextPeriod,
                    onOpenSettings: _openPeriodSettings,
                  ),
                ),

                // Income / Expenses Tab Selector
                SliverToBoxAdapter(
                  child: _StatsTabBar(
                    isIncome: _isIncome,
                    incomeTotal: incomeTotal,
                    expensesTotal: expensesTotal,
                    allWallets: allWallets,
                    onTabChanged: (isIncome) {
                      if (_isIncome != isIncome) {
                        setState(() {
                          _isIncome = isIncome;
                          _selectedCategoryPk = null;
                          _pieChartDisplayStateKey.currentState
                              ?.setTouchedIndex(-1);
                        });
                      }
                    },
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
                        data: activeSummary.dataFilterUnassignedTransactions,
                        totalSpent: activeSummary.totalSpent,
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
                if (activeSummary.dataFilterUnassignedTransactions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: CategorySpendingLegend(
                      categoriesWithTotal:
                          activeSummary.dataFilterUnassignedTransactions,
                      subcategoriesMap: activeSummary
                          .subCategorySpendingIndexedByMainCategoryPk,
                      totalSpent: activeSummary.totalSpent,
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
        ),
      ),
    );
  }
}

class _StatsPeriodHeader extends StatelessWidget {
  const _StatsPeriodHeader({
    required this.title,
    required this.cycleButtonLabel,
    required this.canNavigate,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenSettings,
  });

  final String title;
  final String cycleButtonLabel;
  final bool canNavigate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (canNavigate)
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  onPressed: onPrevious,
                  tooltip: "previous-period".tr(),
                ),
              const SizedBox(width: 4),
              TextFont(
                text: title,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(width: 4),
              if (canNavigate)
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  onPressed: onNext,
                  tooltip: "next-period".tr(),
                ),
            ],
          ),
          InkWell(
            onTap: onOpenSettings,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  TextFont(
                    text: cycleButtonLabel,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    textColor: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsTabBar extends StatelessWidget {
  const _StatsTabBar({
    required this.isIncome,
    required this.incomeTotal,
    required this.expensesTotal,
    required this.allWallets,
    required this.onTabChanged,
  });

  final bool isIncome;
  final double incomeTotal;
  final double expensesTotal;
  final AllWallets allWallets;
  final ValueChanged<bool> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatsTabButton(
              title:
                  "${"income".tr()} ${convertToMoney(allWallets, incomeTotal)}",
              isSelected: isIncome,
              onTap: () => onTabChanged(true),
            ),
          ),
          Expanded(
            child: _StatsTabButton(
              title:
                  "${"expenses".tr()} ${convertToMoney(allWallets, expensesTotal)}",
              isSelected: !isIncome,
              onTap: () => onTabChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsTabButton extends StatelessWidget {
  const _StatsTabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color activeIndicatorColor = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: TextFont(
              text: title,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              textColor: isSelected
                  ? theme.colorScheme.onBackground
                  : theme.colorScheme.onBackground.withOpacity(0.5),
            ),
          ),
          Container(
            height: 3,
            color: isSelected ? activeIndicatorColor : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
