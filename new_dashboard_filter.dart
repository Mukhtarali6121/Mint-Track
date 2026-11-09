import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:expense_tracker/utils/constants.dart';
import 'package:intl/intl.dart';

class Dummy extends StatefulWidget {
  @override
  State<Dummy> createState() => _DummyState();
}

class _DummyState extends State<Dummy> {
  PeriodFilter _filter = PeriodFilter.month;
  String? _selectedAccountId;
  DateTimeRange? _customRange;
  void _loadData() {}

  String _labelForFilter(PeriodFilter p) => "test";

  void _showFilterBottomSheet(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts;

    PeriodFilter tempFilter = _filter;
    String? tempAccountId = _selectedAccountId;
    DateTimeRange? tempCustomRange = _customRange;
    int selectedTabIndex = 0;
    final List<String> tabs = ['Period', 'Account'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Widget buildListOption({
            required String label,
            required bool isSelected,
            required VoidCallback onTap,
          }) {
            return InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.accentGreen
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check, size: 18, color: AppColors.accentGreen),
                  ],
                ),
              ),
            );
          }

          Widget buildPeriodPane() {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final p in [
                  PeriodFilter.day,
                  PeriodFilter.week,
                  PeriodFilter.month,
                  PeriodFilter.year,
                  PeriodFilter.custom,
                ])
                  buildListOption(
                    label: _labelForFilter(p),
                    isSelected: tempFilter == p,
                    onTap: () async {
                      if (p == PeriodFilter.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2100),
                          initialDateRange: tempCustomRange,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppColors.accentGreen,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            tempCustomRange = picked;
                            tempFilter = p;
                          });
                        }
                      } else {
                        setState(() => tempFilter = p);
                      }
                    },
                  ),
                if (tempFilter == PeriodFilter.custom &&
                    tempCustomRange != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${DateFormat.yMMMd().format(tempCustomRange!.start)} - ${DateFormat.yMMMd().format(tempCustomRange!.end)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            );
          }

          Widget buildAccountPane() {
            if (accounts.isEmpty) {
              return Center(
                child: Text(
                  'No accounts found',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              );
            }
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                buildListOption(
                  label: 'All Accounts',
                  isSelected: tempAccountId == null,
                  onTap: () => setState(() => tempAccountId = null),
                ),
                ...accounts.map(
                  (account) => buildListOption(
                    label: account.name,
                    isSelected: tempAccountId == account.id,
                    onTap: () => setState(() => tempAccountId = account.id),
                  ),
                ),
              ],
            );
          }

          Widget buildRightPaneContent() {
            switch (selectedTabIndex) {
              case 0:
                return buildPeriodPane();
              case 1:
                return buildAccountPane();
              default:
                return const SizedBox.shrink();
            }
          }

          return Container(
            height:
                MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.close,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.border.withOpacity(0.3)),

                  // Body - Split View
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Pane (Tabs)
                        Container(
                          width: 130,
                          color: Colors.grey.shade50,
                          child: ListView.builder(
                            itemCount: tabs.length,
                            itemBuilder: (context, index) {
                              final isSelected = selectedTabIndex == index;
                              return InkWell(
                                onTap: () =>
                                    setState(() => selectedTabIndex = index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  child: Text(
                                    tabs[index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? AppColors.accentGreen
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Right Pane (Content)
                        Expanded(
                          child: Container(
                            color: Colors.white,
                            child: buildRightPaneContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.border.withOpacity(0.3)),

                  // Bottom Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                tempFilter = PeriodFilter.month;
                                tempAccountId = null;
                                tempCustomRange = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                'Clear all',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              this.setState(() {
                                _filter = tempFilter;
                                _selectedAccountId = tempAccountId;
                                _customRange = tempCustomRange;
                              });
                              _loadData();
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                'Apply',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
