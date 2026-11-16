import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:budget/functions.dart';
import 'package:budget/pages/addCategoryPage.dart';
import 'package:budget/pages/editHomePage.dart';
import 'package:budget/pages/transactionFilters.dart';
import 'package:budget/pages/transactionsSearchPage.dart';
import 'package:budget/pages/walletDetailsPage.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/struct/spendingSummaryHelper.dart';
import 'package:budget/widgets/animatedExpanded.dart';
import 'package:budget/widgets/categoryEntry.dart';
import 'package:budget/widgets/categorySpendingLegend.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/tappable.dart';
import 'package:budget/widgets/transactionEntry/incomeAmountArrow.dart';
import 'package:budget/widgets/util/keepAliveClientMixin.dart';
import 'package:budget/widgets/pieChart.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:budget/widgets/viewAllTransactionsButton.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:budget/widgets/pageIndicator.dart';

class HomePagePieChart extends StatefulWidget {
  const HomePagePieChart({super.key});

  @override
  State<HomePagePieChart> createState() => _HomePagePieChartState();
}

class _HomePagePieChartState extends State<HomePagePieChart>
    with SingleTickerProviderStateMixin {
  void openPieChartSettings() async {
    await openPieChartHomePageBottomSheetSettings(context);
    homePageStateKey.currentState?.refreshState();
  }

  @override
  Widget build(BuildContext context) {
    final PageController _pageController = PageController(
        initialPage: appStateSettings["pieChartTotal"] != "incoming" ? 0 : 1);
    TransactionCategory? selectedCategory;

    const double borderRadius = 15;
    return KeepAliveClientMixin(
      child: Padding(
        padding:
            const EdgeInsetsDirectional.only(bottom: 13, start: 13, end: 13),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: boxShadowCheck(boxShadowGeneral(context)),
            borderRadius: BorderRadiusDirectional.circular(borderRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadiusDirectional.circular(borderRadius),
            child: Tappable(
              borderRadius: borderRadius,
              onLongPress: openPieChartSettings,
              onTap: () {
                setState(() {
                  selectedCategory = null;
                });
              },
              color: getColor(context, "lightDarkAccentHeavyLight"),
              child: LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 320 * 2 + 50) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 25),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ExpandablePageView(
                          estimatedPageSize: 255,
                          onPageChanged: (value) {
                            updateSettings(
                              "pieChartTotal",
                              value == 0 ? "outgoing" : "incoming",
                              updateGlobalState: false,
                            );
                          },
                          animationDuration: Duration(milliseconds: 500),
                          animateFirstPage: true,
                          pageSnapping: true,
                          clipBehavior: Clip.none,
                          controller: _pageController,
                          children: [
                            PieChartHomeAndCategorySummary(
                                isIncome: false,
                                selectedCategory: selectedCategory),
                            PieChartHomeAndCategorySummary(
                                isIncome: true,
                                selectedCategory: selectedCategory)
                          ],
                        ),
                        PositionedDirectional(
                          start: 0,
                          end: 0,
                          bottom: -10,
                          child: PageIndicator(
                            controller: _pageController,
                            itemCount: 2,
                          ),
                        ),
                        PositionedDirectional(
                          top: 0,
                          end: 0,
                          child: IncomeOutcomeArrowPageIndicator(
                            controller: _pageController,
                            onTap: (isIncome) {
                              _pageController.animateToPage(
                                isIncome ? 0 : 1,
                                duration: Duration(milliseconds: 600),
                                curve: Curves.easeInOutCubicEmphasized,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsetsDirectional.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PieChartHomeAndCategorySummary(
                          isIncome: false,
                          animatedSizeCategoryContainer: true,
                          selectedCategory: selectedCategory,
                        ),
                      ),
                      Expanded(
                        child: PieChartHomeAndCategorySummary(
                          isIncome: true,
                          animatedSizeCategoryContainer: true,
                          selectedCategory: selectedCategory,
                        ),
                      )
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class IncomeOutcomeArrowPageIndicator extends StatelessWidget {
  final PageController controller;
  final Function(bool isIncome) onTap;

  IncomeOutcomeArrowPageIndicator({
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        int currentPage =
            controller.page?.round().toInt() ?? controller.initialPage;
        bool isIncome = currentPage != 0;
        return Tappable(
          borderRadius: 100,
          onTap: () => onTap(isIncome),
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(8.0),
            child: IncomeOutcomeArrow(
              iconSize: 30,
              width: 30,
              isIncome: isIncome,
              color: isIncome
                  ? getColor(context, "incomeAmount")
                  : getColor(context, "expenseAmount"),
            ),
          ),
        );
      },
    );
  }
}

class PieChartHomeAndCategorySummary extends StatefulWidget {
  const PieChartHomeAndCategorySummary(
      {required this.isIncome,
      this.animatedSizeCategoryContainer = false,
      this.selectedCategory,
      super.key});
  final bool isIncome;
  final bool animatedSizeCategoryContainer;
  final TransactionCategory? selectedCategory;

  @override
  State<PieChartHomeAndCategorySummary> createState() =>
      _PieChartHomeAndCategorySummaryState();
}

class _PieChartHomeAndCategorySummaryState
    extends State<PieChartHomeAndCategorySummary> {
  GlobalKey<PieChartDisplayState> pieChartDisplayStateKey = GlobalKey();
  late TransactionCategory? selectedCategory = widget.selectedCategory;
  bool expandCategorySelection = false;
  bool showAllSubcategories = appStateSettings["showAllSubcategories"];

  @override
  void didUpdateWidget(covariant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategory != selectedCategory) {
      if (widget.selectedCategory == null) {
        clearCategorySelection();
      } else {
        setState(() {
          selectedCategory = widget.selectedCategory;
        });
      }
    }
  }

  clearCategorySelection() {
    pieChartDisplayStateKey.currentState?.setTouchedIndex(-1);
    setState(() {
      expandCategorySelection = false;
    });
  }

  void openPieChartSettings() async {
    await openPieChartHomePageBottomSheetSettings(context);
    homePageStateKey.currentState?.refreshState();
  }

  void toggleAllSubcategories() {
    setState(() {
      showAllSubcategories = !showAllSubcategories;
    });
    Future.delayed(Duration(milliseconds: 10), () {
      if (expandCategorySelection)
        pieChartDisplayStateKey.currentState
            ?.setTouchedCategoryPk(selectedCategory?.categoryPk);
    });

    updateSettings("showAllSubcategories", showAllSubcategories,
        updateGlobalState: false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionWallet>>(
      stream: database.getAllPinnedWallets(HomePageWidgetDisplay.PieChart).$1,
      builder: (context, snapshot) {
        if (snapshot.hasData ||
            appStateSettings["pieChartAllWallets"] == true) {
          List<String>? walletPks =
              (snapshot.data ?? []).map((item) => item.walletPk).toList();
          if (walletPks.length <= 0 ||
              appStateSettings["pieChartAllWallets"] == true) walletPks = null;
          return StreamBuilder<List<CategoryWithTotal>>(
            stream:
                database.watchTotalSpentInEachCategoryInTimeRangeFromCategories(
              allWallets: Provider.of<AllWallets>(context),
              start: DateTime.now(),
              end: DateTime.now(),
              categoryFks: null,
              categoryFksExclude: null,
              budgetTransactionFilters: null,
              memberTransactionFilters: null,
              allTime: true,
              walletPks: walletPks,
              isIncome: widget.isIncome,
              followCustomPeriodCycle: true,
              cycleSettingsExtension: "PieChart",
              countUnassignedTransactions: true,
              includeAllSubCategories: true,
              searchFilters: SearchFilters(expenseIncome: [
                if (appStateSettings["pieChartIncomeAndExpenseOnly"] == true)
                  (widget.isIncome == true
                      ? ExpenseIncome.income
                      : ExpenseIncome.expense)
              ]),
            ),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                TotalSpentCategoriesSummary s =
                    watchTotalSpentInTimeRangeHelper(
                  dataInput: snapshot.data ?? [],
                  showAllSubcategories: showAllSubcategories,
                  multiplyTotalBy: 1,
                  absoluteTotal: true,
                );

                return Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                              start: 10, end: 10, bottom: 15, top: 20),
                          child: Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: AlignmentDirectional.center,
                              children: [
                                PieChartWrapper(
                                  disableLarge: true,
                                  pieChartDisplayStateKey:
                                      pieChartDisplayStateKey,
                                  data: s.dataFilterUnassignedTransactions,
                                  totalSpent: s.totalSpent,
                                  setSelectedCategory: (categoryPk, category) {
                                    if (category == null ||
                                        categoryPk == "-1") {
                                      clearCategorySelection();
                                    } else {
                                      setState(() {
                                        selectedCategory = category;
                                        expandCategorySelection = true;
                                      });
                                    }
                                  },
                                  middleColor: getColor(context,
                                      "lightDarkAccentHeavyLight"),
                                ),
                                if (snapshot.data!.isEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.all(8.0),
                                    child: Column(
                                      children: [
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 280),
                                          child: TextFont(
                                            text: widget.isIncome
                                                ? appStateSettings[
                                                            "pieChartIncomeAndExpenseOnly"] ==
                                                        true
                                                    ? "no-income-within-period"
                                                        .tr()
                                                    : "no-incoming-within-period"
                                                        .tr()
                                                : appStateSettings[
                                                            "pieChartIncomeAndExpenseOnly"] ==
                                                        true
                                                    ? "no-expense-within-period"
                                                        .tr()
                                                    : "no-outgoing-within-period"
                                                        .tr(),
                                            textAlign: TextAlign.center,
                                            maxLines: 20,
                                            fontSize: 17,
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                        LowKeyButton(
                                          onTap: openPieChartSettings,
                                          text: "select-period"
                                              .tr()
                                              .capitalizeFirstofEach,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          bottom: -2,
                          start: 0,
                          end: 0,
                          child: PieChartOptions(
                            isIncomeBudget: false,
                            hasSubCategories: s.hasSubCategories,
                            selectedCategory: expandCategorySelection
                                ? selectedCategory
                                : null,
                            onClearSelection: clearCategorySelection,
                            onEditSpendingGoals: null,
                            showAllSubcategories: true,
                            toggleAllSubCategories: toggleAllSubcategories,
                            useHorizontalPaddingConstrained: false,
                          ),
                        ),
                      ],
                    ),
                    if (s.dataFilterUnassignedTransactions.isNotEmpty)
                      CategorySpendingLegend(
                        categoriesWithTotal: s.dataFilterUnassignedTransactions,
                        subcategoriesMap:
                            s.subCategorySpendingIndexedByMainCategoryPk,
                        totalSpent: s.totalSpent,
                        selectedCategoryPk: selectedCategory?.categoryPk,
                        onCategoryTapped: (categoryPk) {
                          if (categoryPk == null) {
                            clearCategorySelection();
                          } else {
                            TransactionCategory? foundCat;
                            for (final c in s.dataFilterUnassignedTransactions) {
                              if (c.category.categoryPk == categoryPk) {
                                foundCat = c.category;
                                break;
                              }
                            }
                            setState(() {
                              selectedCategory = foundCat;
                              expandCategorySelection = true;
                              pieChartDisplayStateKey.currentState
                                  ?.setTouchedCategoryPk(categoryPk);
                            });
                          }
                        },
                      ),
                  ],
                );
              }
              return const SizedBox(height: 255);
            },
          );
        }
        return const SizedBox(height: 255);
      },
    );
  }
}
