import 'package:expense_tracker/models.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:expense_tracker/common/animation_utils.dart';
import 'package:expense_tracker/common/custom_page_route.dart';
import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/common/hive_storage.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/presentation/screens/edit_transaction.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../../providers/transaction_provider.dart';

class SearchScreen extends StatefulWidget {
  final PeriodFilter? initialPeriod;
  final List<String>? initialAccountIds;
  final DateTimeRange? initialCustomRange;

  const SearchScreen({
    super.key,
    this.initialPeriod,
    this.initialAccountIds,
    this.initialCustomRange,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();

  List<TransactionType>? _types;
  List<String>? _categories;
  List<String>? _accountIds;
  PeriodFilter? _period; // null = all transactions
  DateTimeRange? _customRange;
  SortOption _sortOption = SortOption.dateDesc;

  // Multi-select state
  bool _isSelectionMode = false;
  Set<String> _selectedTransactionIds = {};

  late AnimationController _deleteBarController;
  Animation<double>? _deleteBarAnimation;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    _accountIds = widget.initialAccountIds;
    _customRange = widget.initialCustomRange;

    _deleteBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _deleteBarAnimation = CurvedAnimation(
      parent: _deleteBarController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    _deleteBarController.dispose();
    super.dispose();
  }

  DateTimeRange? _currentRange() {
    if (_period == null) return null;
    final now = DateTime.now();
    switch (_period!) {
      case PeriodFilter.day:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case PeriodFilter.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
        );
      case PeriodFilter.month:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(end.year, end.month, end.day, 23, 59, 59, 999),
        );
      case PeriodFilter.year:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case PeriodFilter.custom:
        return _customRange ?? DateTimeRange(start: now, end: now);
    }
  }

  List<TransactionItem> _applyFilters(List<TransactionItem> all) {
    final range = _currentRange();
    final query = _queryController.text.trim().toLowerCase();

    var filtered = all.where((t) {
      final inRange =
          range == null ||
          (!t.date.isBefore(range.start) && !t.date.isAfter(range.end));
      final matchesType = _types == null || _types!.contains(t.type);
      final matchesCategory =
          _categories == null || _categories!.contains(t.category);
      final matchesAccount =
          _accountIds == null || _accountIds!.contains(t.accountId);
      final matchesQuery =
          query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          (t.note?.toLowerCase().contains(query) ?? false) ||
          t.category.toLowerCase().contains(query);
      return inRange &&
          matchesType &&
          matchesCategory &&
          matchesAccount &&
          matchesQuery;
    }).toList();

    // Apply sorting
    switch (_sortOption) {
      case SortOption.dateDesc:
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortOption.dateAsc:
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case SortOption.amountDesc:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case SortOption.amountAsc:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case SortOption.categoryAsc:
        filtered.sort((a, b) => a.category.compareTo(b.category));
        break;
    }

    return filtered;
  }

  void _openFilters() async {
    final provider = context.read<TransactionProvider>();
    final allTransactions = provider.getAllTransactions();

    // If period is null, set it to custom with date range from first to last transaction
    PeriodFilter? initialPeriod = _period;
    DateTimeRange? initialCustom = _customRange;

    if (initialPeriod == null && allTransactions.isNotEmpty) {
      // Sort transactions by date to find first and last
      final sortedTransactions = List<TransactionItem>.from(allTransactions)
        ..sort((a, b) => a.date.compareTo(b.date));

      final firstDate = sortedTransactions.first.date;
      final lastDate = sortedTransactions.last.date;

      initialPeriod = PeriodFilter.custom;
      initialCustom = DateTimeRange(
        start: DateTime(firstDate.year, firstDate.month, firstDate.day),
        end: DateTime(
          lastDate.year,
          lastDate.month,
          lastDate.day,
          23,
          59,
          59,
          999,
        ),
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _FilterSheet(
          initialTypes: _types,
          initialCategories: _categories,
          initialPeriod: initialPeriod,
          initialCustom: initialCustom,
          initialAccountIds: _accountIds,
          initialSort: _sortOption,
          onApply: (types, categories, period, custom, accountIds, sort) {
            setState(() {
              _types = types;
              _categories = categories;
              _period = period;
              _customRange = custom;
              _accountIds = accountIds;
              _sortOption = sort;
            });
          },
        );
      },
    );
  }

  Future<void> _deleteSelectedTransactions() async {
    if (_selectedTransactionIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Transactions'),
        content: Text(
          'Are you sure you want to delete ${_selectedTransactionIds.length} transaction${_selectedTransactionIds.length > 1 ? 's' : ''}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<TransactionProvider>();
      final count = _selectedTransactionIds.length;
      final idsToDelete = Set<String>.from(_selectedTransactionIds);

      for (final id in idsToDelete) {
        await provider.remove(id);
      }

      _deleteBarController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isSelectionMode = false;
            _selectedTransactionIds.clear();
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count transaction${count > 1 ? 's' : ''} deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _exportTransactions(List<TransactionItem> transactions) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')),
      );
      return;
    }

    final currencyProvider = Provider.of<CurrencyProvider>(
      context,
      listen: false,
    );
    final currencySymbol = currencyProvider.currencySymbol;

    final buffer = StringBuffer();
    buffer.writeln('Transaction Export');
    buffer.writeln(
      'Generated: ${DateFormat.yMMMd().add_Hms().format(DateTime.now())}',
    );
    buffer.writeln('');
    buffer.writeln('Date,Type,Category,Title,Amount,Account');

    for (final t in transactions) {
      final accountName =
          context.read<AccountProvider>().getAccount(t.accountId)?.name ??
          'Unknown';
      buffer.writeln(
        '${DateFormat.yMMMd().format(t.date)},'
        '${t.type == TransactionType.income ? "Income" : "Expense"},'
        '${t.category},'
        '"${t.title}",'
        '${CurrencyFormatter.format(amount: t.amount, symbol: currencySymbol)},'
        '$accountName',
      );
    }

    final exportText = buffer.toString();

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: exportText));

    // Show success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction data copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Try to share if available (optional)
    try {
      // Only import share_plus if you want to try sharing
      // For now, we'll just use clipboard which is more reliable
    } catch (e) {
      // Share failed, but clipboard already worked
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final currencySymbol = currencyProvider.currencySymbol;
    final accounts = accountProvider.accounts;

    final all = provider.getAllTransactions();
    final results = _applyFilters(all);

    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Search & Filter',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar and Filter Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        hintText: 'Search transactions...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.accentGreen,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _openFilters,
                    icon: Icon(Icons.tune, color: AppColors.accentGreen),
                    tooltip: 'Filter',
                  ),
                ),
              ],
            ),
          ),

          // Sort By Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  "Sort By:",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<SortOption>(
                      value: _sortOption,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.border.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.border.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.accentGreen,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: SortOption.dateDesc,
                          child: Text(
                            "Date (Newest First)",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        DropdownMenuItem(
                          value: SortOption.dateAsc,
                          child: Text(
                            "Date (Oldest First)",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        DropdownMenuItem(
                          value: SortOption.amountDesc,
                          child: Text(
                            "Amount (High to Low)",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        DropdownMenuItem(
                          value: SortOption.amountAsc,
                          child: Text(
                            "Amount (Low to High)",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        DropdownMenuItem(
                          value: SortOption.categoryAsc,
                          child: Text(
                            "Category (A-Z)",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _sortOption = v);
                        }
                      },
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Delete button when in selection mode
          if (_isSelectionMode &&
              _selectedTransactionIds.isNotEmpty &&
              _deleteBarAnimation != null)
            SizeTransition(
              sizeFactor: _deleteBarAnimation!,
              child: FadeTransition(
                opacity: _deleteBarAnimation!,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(_deleteBarAnimation!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedTransactionIds.length} selected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                _deleteBarController.reverse().then((_) {
                                  if (mounted) {
                                    setState(() {
                                      _isSelectionMode = false;
                                      _selectedTransactionIds.clear();
                                    });
                                  }
                                });
                              },
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Cancel'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _deleteSelectedTransactions(),
                              icon: const Icon(Icons.delete, size: 18),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Results Header with Count and Export
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${results.length} result${results.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                // if (results.isNotEmpty)
                //   TextButton.icon(
                //     onPressed: () => _exportTransactions(results),
                //     icon: Icon(Icons.share, size: 18, color: AppColors.accentGreen),
                //     label: Text(
                //       'Export',
                //       style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w600),
                //     ),
                //   ),
              ],
            ),
          ),

          // Results List
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matching transactions',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _ResultsList(
                    items: results,
                    currencySymbol: currencySymbol,
                    isSelectionMode: _isSelectionMode,
                    selectedTransactionIds: _selectedTransactionIds,
                    onSelectionModeChanged: (bool mode) {
                      setState(() {
                        _isSelectionMode = mode;
                        if (mode) {
                          _deleteBarController.forward();
                        } else {
                          _deleteBarController.reverse();
                          _selectedTransactionIds.clear();
                        }
                      });
                    },
                    onTransactionToggled: (String id) {
                      setState(() {
                        if (_selectedTransactionIds.contains(id)) {
                          _selectedTransactionIds.remove(id);
                          if (_selectedTransactionIds.isEmpty) {
                            _deleteBarController.reverse().then((_) {
                              if (mounted) {
                                setState(() {
                                  _isSelectionMode = false;
                                });
                              }
                            });
                          }
                        } else {
                          _selectedTransactionIds.add(id);
                        }
                      });
                    },
                    onDeleteSelected: () => _deleteSelectedTransactions(),
                  ),
          ),
        ],
      ),
    );
  }
}

enum SortOption { dateDesc, dateAsc, amountDesc, amountAsc, categoryAsc }

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.items,
    required this.currencySymbol,
    required this.isSelectionMode,
    required this.selectedTransactionIds,
    required this.onSelectionModeChanged,
    required this.onTransactionToggled,
    required this.onDeleteSelected,
  });

  final List<TransactionItem> items;
  final String currencySymbol;
  final bool isSelectionMode;
  final Set<String> selectedTransactionIds;
  final ValueChanged<bool> onSelectionModeChanged;
  final ValueChanged<String> onTransactionToggled;
  final VoidCallback onDeleteSelected;

  Future<void> _deleteTransaction(
    BuildContext context,
    TransactionItem transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text(
          'Are you sure you want to delete this transaction? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<TransactionProvider>();
      await provider.remove(transaction.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final t = items[index];
        final firestoreCategory = _getCategoryFromFirestore(t.category, t.type);
        final categoryColor =
            firestoreCategory?.color ??
            _getCategoryFromString(t.category).color;
        final iconPath =
            firestoreCategory?.iconPath ??
            _getIconPathFromCategoryName(t.category);
        final isSelected = selectedTransactionIds.contains(t.id);

        return StaggeredListAnimation(
          index: index,
          child: isSelectionMode
              ? Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: isSelected
                      ? AppColors.accentGreen.withOpacity(0.1)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.accentGreen
                          : AppColors.border.withOpacity(0.4),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => onTransactionToggled(t.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Checkbox instead of icon
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accentGreen
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accentGreen
                                    : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.category,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t.title.isEmpty ? 'Not Specified' : t.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${t.type == TransactionType.income ? '+' : '-'} ${CurrencyFormatter.format(amount: t.amount, symbol: currencySymbol, decimalDigits: 2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: t.type == TransactionType.income
                                      ? AppColors.accentGreen
                                      : AppColors.error,
                                ),
                              ),
                              Text(
                                DateFormat.yMMMd().format(t.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppColors.border.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: GestureDetector(
                    onLongPress: () {
                      onSelectionModeChanged(true);
                      onTransactionToggled(t.id);
                    },
                    child: _AnimatedCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          CustomPageRoute(
                            child: EditTransactionScreen(existing: t),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Hero(
                              tag: 'transaction_icon_${t.id}',
                              child: Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: categoryColor == Colors.white || categoryColor.value == Colors.white.value
                                      ? AppColors.accentGreen.withValues(alpha: 0.12)
                                      : categoryColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: SvgPicture.asset(
                                    iconPath,
                                    colorFilter: categoryColor == Colors.white || categoryColor.value == Colors.white.value
                                        ? null
                                        : ColorFilter.mode(
                                            categoryColor,
                                            BlendMode.srcIn,
                                          ),
                                    width: 24,
                                    height: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.category,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.title.isEmpty ? 'Not Specified' : t.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat.yMMMd().format(t.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${t.type == TransactionType.income ? '+' : '-'} ${CurrencyFormatter.format(amount: t.amount, symbol: currencySymbol, decimalDigits: 2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: t.type == TransactionType.income
                                        ? AppColors.accentGreen
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    super.key,
    required this.initialTypes,
    required this.initialCategories,
    required this.initialPeriod,
    required this.initialCustom,
    required this.initialAccountIds,
    required this.initialSort,
    required this.onApply,
  });

  final List<TransactionType>? initialTypes;
  final List<String>? initialCategories;
  final PeriodFilter? initialPeriod;
  final DateTimeRange? initialCustom;
  final List<String>? initialAccountIds;
  final SortOption initialSort;
  final void Function(
    List<TransactionType>?,
    List<String>?,
    PeriodFilter?,
    DateTimeRange?,
    List<String>?,
    SortOption,
  ) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  List<TransactionType>? _types;
  List<String>? _categories;
  PeriodFilter? _period;
  DateTimeRange? _customRange;
  List<String>? _accountIds;
  SortOption _sortOption = SortOption.dateDesc;

  int _selectedTabIndex = 0;
  final List<String> _tabs = ['Type', 'Category', 'Period', 'Account'];

  @override
  void initState() {
    super.initState();
    _types = widget.initialTypes != null ? List.from(widget.initialTypes!) : null;
    _categories = widget.initialCategories != null ? List.from(widget.initialCategories!) : null;
    _period = widget.initialPeriod;
    _customRange = widget.initialCustom;
    _accountIds = widget.initialAccountIds != null ? List.from(widget.initialAccountIds!) : null;
    _sortOption = widget.initialSort;
  }

  void _resetFilters() {
    setState(() {
      _types = null;
      _categories = null;
      _period = null;
      _customRange = null;
      _accountIds = null;
      _sortOption = SortOption.dateDesc;
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialDateRange: _customRange,
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
      setState(() => _customRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final transactions = provider.getAllTransactions();
    final categories = transactions.map((t) => t.category).toSet().toList()
      ..sort();
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;

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
                    child: Icon(Icons.close, color: AppColors.textPrimary),
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
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        final isSelected = _selectedTabIndex == index;
                        return InkWell(
                          onTap: () =>
                              setState(() => _selectedTabIndex = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            child: Text(
                              _tabs[index],
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
                      child: _buildRightPaneContent(categories, accounts),
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
                      onTap: _resetFilters,
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
                        widget.onApply(
                          _types,
                          _categories,
                          _period,
                          _customRange,
                          _accountIds,
                          _sortOption,
                        );
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
  }

  Widget _buildRightPaneContent(
    List<String> categories,
    List<dynamic> accounts,
  ) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildTypePane();
      case 1:
        return _buildCategoryPane(categories);
      case 2:
        return _buildPeriodPane();
      case 3:
        return _buildAccountPane(accounts);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTypePane() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildListOption(
          label: 'All Types',
          isSelected: _types == null,
          isIndeterminate: _types != null && _types!.isNotEmpty,
          onTap: () => setState(() => _types = null),
        ),
        const SizedBox(height: 8),
        _buildListOption(
          label: 'Income',
          isSelected:
              _types == null || _types!.contains(TransactionType.income),
          onTap: () => setState(() {
            if (_types == null) {
              _types = [TransactionType.expense];
            } else if (_types!.contains(TransactionType.income)) {
              _types!.remove(TransactionType.income);
            } else {
              _types!.add(TransactionType.income);
              if (_types!.length == 2) _types = null;
            }
          }),
        ),
        _buildListOption(
          label: 'Expense',
          isSelected:
              _types == null || _types!.contains(TransactionType.expense),
          onTap: () => setState(() {
            if (_types == null) {
              _types = [TransactionType.income];
            } else if (_types!.contains(TransactionType.expense)) {
              _types!.remove(TransactionType.expense);
            } else {
              _types!.add(TransactionType.expense);
              if (_types!.length == 2) _types = null;
            }
          }),
        ),
      ],
    );
  }

  Widget _buildCategoryPane(List<String> categories) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildListOption(
          label: 'All Categories',
          isSelected: _categories == null,
          isIndeterminate: _categories != null && _categories!.isNotEmpty,
          onTap: () => setState(() => _categories = null),
        ),
        const SizedBox(height: 8),
        ...categories.map(
          (c) => _buildListOption(
            label: c,
            isSelected: _categories == null || _categories!.contains(c),
            onTap: () => setState(() {
              if (_categories == null) {
                _categories = List.from(categories)..remove(c);
              } else if (_categories!.contains(c)) {
                _categories!.remove(c);
              } else {
                _categories!.add(c);
                if (_categories!.length == categories.length)
                  _categories = null;
              }
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodPane() {
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
          _buildListOption(
            label: _labelForFilter(p),
            isSelected: _period == p,
            onTap: () async {
              if (p == PeriodFilter.custom) {
                await _pickCustomRange();
              }
              setState(() => _period = p);
            },
          ),

        if (_period == PeriodFilter.custom && _customRange != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${DateFormat.yMMMd().format(_customRange!.start)} - ${DateFormat.yMMMd().format(_customRange!.end)}',
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

  Widget _buildAccountPane(List<dynamic> accounts) {
    if (accounts.isEmpty) {
      return Center(
        child: Text(
          'No accounts found',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildListOption(
          label: 'All Accounts',
          isSelected: _accountIds == null,
          isIndeterminate: _accountIds != null && _accountIds!.isNotEmpty,
          onTap: () => setState(() => _accountIds = null),
        ),
        const SizedBox(height: 8),
        ...accounts.map(
          (account) => _buildListOption(
            label: account.name,
            isSelected:
                _accountIds == null || _accountIds!.contains(account.id),
            onTap: () => setState(() {
              if (_accountIds == null) {
                _accountIds =
                    accounts.map<String>((a) => a.id as String).toList()
                      ..remove(account.id);
              } else if (_accountIds!.contains(account.id)) {
                _accountIds!.remove(account.id);
              } else {
                _accountIds!.add(account.id);
                if (_accountIds!.length == accounts.length) _accountIds = null;
              }
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildListOption({
    required String label,
    required bool isSelected,
    bool isIndeterminate = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border.withOpacity(0.2)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.accentGreen
                      : AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: (isSelected || isIndeterminate)
                      ? AppColors.accentGreen
                      : AppColors.border.withOpacity(0.5),
                  width: (isSelected || isIndeterminate) ? 2.0 : 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.accentGreen,
                    )
                  : isIndeterminate
                  ? const Icon(
                      Icons.remove,
                      size: 14,
                      color: AppColors.accentGreen,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated card with tap feedback
class _AnimatedCard extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius borderRadius;

  const _AnimatedCard({
    required this.onTap,
    required this.child,
    required this.borderRadius,
  });

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: AnimationUtils.fastDuration,
        curve: AnimationUtils.defaultCurve,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: widget.borderRadius,
          splashColor: AppColors.accentGreen.withOpacity(0.1),
          highlightColor: AppColors.accentGreen.withOpacity(0.05),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Pulsing icon widget for empty states
class _PulsingIcon extends StatefulWidget {
  final Widget child;

  const _PulsingIcon({required this.child});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(scale: _animation.value, child: widget.child);
      },
    );
  }
}

String _labelForFilter(PeriodFilter filter) {
  switch (filter) {
    case PeriodFilter.day:
      return 'Day';
    case PeriodFilter.week:
      return 'Week';
    case PeriodFilter.month:
      return 'Month';
    case PeriodFilter.year:
      return 'Year';
    case PeriodFilter.custom:
      return 'Custom';
  }
}

Category? _getCategoryFromFirestore(String categoryName, TransactionType type) {
  final setupData = HiveStorage.getSetupData();
  if (setupData == null) return null;

  final categories = type == TransactionType.expense
      ? setupData.expenseCategories
      : setupData.incomeCategories;

  try {
    return categories.firstWhere((category) => category.name == categoryName);
  } catch (e) {
    return null;
  }
}

TransactionCategory _getCategoryFromString(String categoryName) {
  return TransactionCategory.values.firstWhere(
    (e) => e.displayName == categoryName,
    orElse: () => TransactionCategory.others,
  );
}

String _getIconPathFromCategoryName(String categoryName) {
  const Map<String, String> iconMap = {
    'insurance': 'assets/images/new/ic_insurance.svg',
    'investment': 'assets/images/new/ic_investment.svg',
    'investments': 'assets/images/new/ic_investment.svg',
    'fuel and transportation': 'assets/images/new/ic_fuel.svg',
    'fuel & transportation': 'assets/images/new/ic_fuel.svg',
    'fuel': 'assets/images/new/ic_fuel.svg',
    'transportation': 'assets/images/new/ic_fuel.svg',
    'credit card bill': 'assets/images/new/ic_credit_card.svg',
    'credit card': 'assets/images/new/ic_credit_card.svg',
    'credit_card': 'assets/images/new/ic_credit_card.svg',
    'creditcard': 'assets/images/new/ic_credit_card.svg',
    'cash withdrawal': 'assets/images/new/ic_family_transfer.svg',
    'cash_withdrawal': 'assets/images/new/ic_family_transfer.svg',
    'family transfer': 'assets/images/new/ic_family_transfer.svg',
    'family_transfer': 'assets/images/new/ic_family_transfer.svg',
    'gifts': 'assets/images/new/ic_gift.svg',
    'gift': 'assets/images/new/ic_gift.svg',
    'personal care': 'assets/images/new/ic_personal_care.svg',
    'personal_care': 'assets/images/new/ic_personal_care.svg',
    'personalcare': 'assets/images/new/ic_personal_care.svg',
    'beauty': 'assets/images/new/ic_personal_care.svg',
    'repair': 'assets/images/new/ic_repairs.svg',
    'repairs': 'assets/images/new/ic_repairs.svg',
    'maintenance': 'assets/images/new/ic_repairs.svg',
    'maintenance & repairs': 'assets/images/new/ic_repairs.svg',
    'self care': 'assets/images/new/ic_mental_wellness.svg',
    'self_care': 'assets/images/new/ic_mental_wellness.svg',
    'mental wellness': 'assets/images/new/ic_mental_wellness.svg',
    'mental_wellness': 'assets/images/new/ic_mental_wellness.svg',
    'wellness': 'assets/images/new/ic_mental_wellness.svg',
    'birthdays': 'assets/images/new/ic_birthday.svg',
    'birthday': 'assets/images/new/ic_birthday.svg',
    'yoga & meditation': 'assets/images/new/ic_yoga.svg',
    'yoga and meditation': 'assets/images/new/ic_yoga.svg',
    'yoga': 'assets/images/new/ic_yoga.svg',
    'fitness': 'assets/images/new/ic_gym.svg',
    'gym': 'assets/images/new/ic_gym.svg',
    'renovation': 'assets/images/new/ic_renovation.svg',
    'renovations': 'assets/images/new/ic_renovation.svg',
    'home renovation': 'assets/images/new/ic_renovation.svg',
    'bills & utilities': 'assets/images/new/ic_bills_utilities.svg',
    'bills and utilities': 'assets/images/new/ic_bills_utilities.svg',
    'bills': 'assets/images/new/ic_bills_utilities.svg',
    'utilities': 'assets/images/new/ic_bills_utilities.svg',
    'groceries': 'assets/images/new/ic_groceries.svg',
    'grocery': 'assets/images/new/ic_groceries.svg',
    'food & dining': 'assets/images/new/ic_food.svg',
    'food and dining': 'assets/images/new/ic_food.svg',
    'food': 'assets/images/new/ic_food.svg',
    'dining': 'assets/images/new/ic_food.svg',
    'entertainment': 'assets/images/new/ic_entertainment.svg',
    'entertainments': 'assets/images/new/ic_entertainment.svg',
    'movie': 'assets/images/new/ic_entertainment.svg',
    'movies': 'assets/images/new/ic_entertainment.svg',
    'hospital': 'assets/images/new/ic_hospital.svg',
    'hospitals': 'assets/images/new/ic_hospital.svg',
    'medical': 'assets/images/new/ic_hospital.svg',
    'health': 'assets/images/new/ic_hospital.svg',
    'healthcare': 'assets/images/new/ic_hospital.svg',
    'charges': 'assets/images/new/ic_charges.svg',
    'charge': 'assets/images/new/ic_charges.svg',
    'fee': 'assets/images/new/ic_charges.svg',
    'fees': 'assets/images/new/ic_charges.svg',
    'tax': 'assets/images/new/ic_tax.svg',
    'taxes': 'assets/images/new/ic_tax.svg',
    'education': 'assets/images/new/ic_education.svg',
    'studies': 'assets/images/new/ic_education.svg',
    'study': 'assets/images/new/ic_education.svg',
    'college': 'assets/images/new/ic_education.svg',
    'school': 'assets/images/new/ic_education.svg',
    'tuition': 'assets/images/new/ic_education.svg',
    'loan': 'assets/images/new/ic_loan.svg',
    'loans': 'assets/images/new/ic_loan.svg',
    'emi': 'assets/images/new/ic_loan.svg',
    'debt': 'assets/images/new/ic_loan.svg',
    'shopping': 'assets/images/new/ic_shopping.svg',
    'clothes': 'assets/images/new/ic_shopping.svg',
    'clothing': 'assets/images/new/ic_shopping.svg',
    'store': 'assets/images/new/ic_shopping.svg',
    'subscription': 'assets/images/new/ic_subscription.svg',
    'subscriptions': 'assets/images/new/ic_subscription.svg',
    'membership': 'assets/images/new/ic_subscription.svg',
    'memberships': 'assets/images/new/ic_subscription.svg',
    'travel': 'assets/images/new/ic_travel.svg',
    'travels': 'assets/images/new/ic_travel.svg',
    'vacation': 'assets/images/new/ic_travel.svg',
    'flight': 'assets/images/new/ic_travel.svg',
    'trip': 'assets/images/new/ic_travel.svg',
    'holiday': 'assets/images/new/ic_travel.svg',
    'other': 'assets/images/new/ic_others.svg',
    'others': 'assets/images/new/ic_others.svg',
  };

  return iconMap[categoryName.toLowerCase().trim()] ?? 'assets/images/new/ic_others.svg';
}
