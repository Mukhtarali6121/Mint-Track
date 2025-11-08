import 'package:expense_tracker/models.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/common/hive_storage.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/edit_transaction.dart';
import 'package:expense_tracker/account_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'transaction_provider.dart';

class SearchScreen extends StatefulWidget {
  final PeriodFilter? initialPeriod;
  final String? initialAccountId;
  final DateTimeRange? initialCustomRange;

  const SearchScreen({
    super.key,
    this.initialPeriod,
    this.initialAccountId,
    this.initialCustomRange,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();

  TransactionType? _type; // null = all
  String? _category; // null = all
  String? _accountId; // null = all
  PeriodFilter? _period; // null = all transactions
  DateTimeRange? _customRange;
  SortOption _sortOption = SortOption.dateDesc;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    _accountId = widget.initialAccountId;
    _customRange = widget.initialCustomRange;
  }

  @override
  void dispose() {
    _queryController.dispose();
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
      final inRange = range == null || (!t.date.isBefore(range.start) && !t.date.isAfter(range.end));
      final matchesType = _type == null || t.type == _type;
      final matchesCategory = _category == null || t.category == _category;
      final matchesAccount = _accountId == null || t.accountId == _accountId;
      final matchesQuery = query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          (t.note?.toLowerCase().contains(query) ?? false) ||
          t.category.toLowerCase().contains(query);
      return inRange && matchesType && matchesCategory && matchesAccount && matchesQuery;
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
        end: DateTime(lastDate.year, lastDate.month, lastDate.day, 23, 59, 59, 999),
      );
    }
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _FilterSheet(
          initialType: _type,
          initialCategory: _category,
          initialPeriod: initialPeriod,
          initialCustom: initialCustom,
          initialAccountId: _accountId,
          initialSort: _sortOption,
          onApply: (type, category, period, custom, accountId, sort) {
            setState(() {
              _type = type;
              _category = category;
              _period = period;
              _customRange = custom;
              _accountId = accountId;
              _sortOption = sort;
            });
          },
        );
      },
    );
  }

  void _exportTransactions(List<TransactionItem> transactions) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')),
      );
      return;
    }

    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final currencySymbol = currencyProvider.currencySymbol;

    final buffer = StringBuffer();
    buffer.writeln('Transaction Export');
    buffer.writeln('Generated: ${DateFormat.yMMMd().add_Hms().format(DateTime.now())}');
    buffer.writeln('');
    buffer.writeln('Date,Type,Category,Title,Amount,Account');
    
    for (final t in transactions) {
      final accountName = context.read<AccountProvider>().getAccount(t.accountId)?.name ?? 'Unknown';
      buffer.writeln(
        '${DateFormat.yMMMd().format(t.date)},'
        '${t.type == TransactionType.income ? "Income" : "Expense"},'
        '${t.category},'
        '"${t.title}",'
        '${CurrencyFormatter.format(amount: t.amount, symbol: currencySymbol)},'
        '$accountName'
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
                        prefixIcon: Icon(Icons.search, color: AppColors.accentGreen),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        Icon(Icons.search_off, size: 64, color: AppColors.textSecondary),
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
                : _ResultsList(items: results, currencySymbol: currencySymbol),
          ),
        ],
      ),
    );
  }
}

enum SortOption {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc,
  categoryAsc,
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.items, required this.currencySymbol});

  final List<TransactionItem> items;
  final String currencySymbol;

  Future<void> _deleteTransaction(BuildContext context, TransactionItem transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction? This action cannot be undone.'),
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
        final categoryColor = firestoreCategory?.color ?? _getCategoryFromString(t.category).color;
        final iconPath = firestoreCategory?.iconPath ?? _getIconPathFromCategoryName(t.category);

        return Card(
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
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTransactionScreen(existing: t),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: SvgPicture.asset(
                        iconPath,
                        colorFilter: ColorFilter.mode(
                          categoryColor,
                          BlendMode.srcIn,
                        ),
                        width: 24,
                        height: 24,
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
            //           PopupMenuButton<String>(
            //             icon: Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
            // onSelected: (value) async {
            //   if (value == 'delete') {
            //     await _deleteTransaction(context, t);
            //               } else if (value == 'edit') {
            //                 Navigator.push(
            //                   context,
            //                   MaterialPageRoute(
            //                     builder: (context) => EditTransactionScreen(existing: t),
            //                   ),
            //                 );
            //   }
            // },
            // itemBuilder: (context) => [
            //               PopupMenuItem<String>(
            //                 value: 'edit',
            //                 child: Row(
            //                   children: [
            //                     Icon(Icons.edit, size: 18, color: AppColors.textPrimary),
            //                     const SizedBox(width: 8),
            //                     Text('Edit'),
            //                   ],
            //                 ),
            //               ),
            //               PopupMenuItem<String>(
            //     value: 'delete',
            //     child: Row(
            //       children: [
            //                     Icon(Icons.delete, size: 18, color: Colors.red),
            //                     const SizedBox(width: 8),
            //                     Text('Delete', style: TextStyle(color: Colors.red)),
            //       ],
            //     ),
            //   ),
            // ],
            //           ),
            //
                    ],
                  ),
                ],
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
    required this.initialType,
    required this.initialCategory,
    required this.initialPeriod,
    required this.initialCustom,
    required this.initialAccountId,
    required this.initialSort,
    required this.onApply,
  });

  final TransactionType? initialType;
  final String? initialCategory;
  final PeriodFilter? initialPeriod;
  final DateTimeRange? initialCustom;
  final String? initialAccountId;
  final SortOption initialSort;
  final void Function(TransactionType?, String?, PeriodFilter?, DateTimeRange?, String?, SortOption) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  TransactionType? _type;
  String? _category;
  PeriodFilter? _period;
  DateTimeRange? _customRange;
  String? _accountId;
  SortOption _sortOption = SortOption.dateDesc;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = widget.initialCategory;
    _period = widget.initialPeriod;
    _customRange = widget.initialCustom;
    _accountId = widget.initialAccountId;
    _sortOption = widget.initialSort;
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
    final categories = transactions.map((t) => t.category).toSet().toList()..sort();

    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type Filter
                    Text('Type', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _type == null,
                  onSelected: (_) => setState(() => _type = null),
                  selectedColor: AppColors.accentGreen.withOpacity(0.2),
                  labelStyle: const TextStyle(
                    color: AppColors.textPrimary,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Income'),
                  selected: _type == TransactionType.income,
                  onSelected: (_) => setState(() => _type = TransactionType.income),
                  selectedColor: AppColors.accentGreen.withOpacity(0.2),
                  labelStyle: const TextStyle(
                    color: AppColors.textPrimary,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Expense'),
                  selected: _type == TransactionType.expense,
                  onSelected: (_) => setState(() => _type = TransactionType.expense),
                  selectedColor: AppColors.error.withOpacity(0.2),
                  labelStyle: const TextStyle(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
                    const SizedBox(height: 20),
                    
                    // Category Filter
                    Text('Category', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
              value: _category,
              isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.accentGreen, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
              items: [
                        DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
                ...categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))).toList(),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
                    const SizedBox(height: 20),
                    
                    // Sort Option
                    Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<SortOption>(
                      value: _sortOption,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.accentGreen, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: [
                        DropdownMenuItem(value: SortOption.dateDesc, child: Text('Date (Newest First)')),
                        DropdownMenuItem(value: SortOption.dateAsc, child: Text('Date (Oldest First)')),
                        DropdownMenuItem(value: SortOption.amountDesc, child: Text('Amount (High to Low)')),
                        DropdownMenuItem(value: SortOption.amountAsc, child: Text('Amount (Low to High)')),
                        DropdownMenuItem(value: SortOption.categoryAsc, child: Text('Category (A-Z)')),
                      ],
                      onChanged: (v) => setState(() => _sortOption = v ?? SortOption.dateDesc),
                    ),
                    const SizedBox(height: 20),
                    
                    // Period Filter
                    Text('Period', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final p in [
                  PeriodFilter.day,
                  PeriodFilter.week,
                  PeriodFilter.month,
                  PeriodFilter.year,
                  PeriodFilter.custom,
                ])
                          InkWell(
                            onTap: () async {
                      if (p == PeriodFilter.custom) {
                        await _pickCustomRange();
                      }
                      setState(() => _period = p);
                    },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: _period == p
                                    ? AppColors.accentGreen.withOpacity(0.1)
                                    : AppColors.backgroundScaffold,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _period == p
                                      ? AppColors.accentGreen
                                      : AppColors.border.withOpacity(0.5),
                                  width: _period == p ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                _labelForFilter(p),
                                style: TextStyle(
                                  color: _period == p
                                      ? AppColors.accentGreen
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                  ),
              ],
            ),
                    if (_period == PeriodFilter.custom && _customRange != null) ...[
                      const SizedBox(height: 8),
              Text(
                '${DateFormat.yMMMd().format(_customRange!.start)} - ${DateFormat.yMMMd().format(_customRange!.end)}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 20),
                    
                    // Account Filter
                    Text('Account', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final accountProvider = context.watch<AccountProvider>();
                        final accounts = accountProvider.accounts;
                        
                        if (accounts.isEmpty) {
                          return Text(
                            'No accounts available',
                            style: TextStyle(color: AppColors.textSecondary),
                          );
                        }
                        
                        return Wrap(
                          spacing: 8,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _accountId = null),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _accountId == null
                                      ? AppColors.accentGreen.withOpacity(0.1)
                                      : AppColors.backgroundScaffold,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _accountId == null
                                        ? AppColors.accentGreen
                                        : AppColors.border.withOpacity(0.5),
                                    width: _accountId == null ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  'All Accounts',
                                  style: TextStyle(
                                    color: _accountId == null
                                        ? AppColors.accentGreen
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            ...accounts.map((account) {
                              final isSelected = _accountId == account.id;
                              return InkWell(
                                onTap: () => setState(() => _accountId = account.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accentGreen.withOpacity(0.1)
                                        : AppColors.backgroundScaffold,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accentGreen
                                          : AppColors.border.withOpacity(0.5),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    account.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.accentGreen
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_type, _category, _period, _customRange, _accountId, _sortOption);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
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
    'Food': 'assets/images/ic_vector_food.svg',
    'Drinks': 'assets/images/ic_vector_drink.svg',
    'Transportation': 'assets/images/ic_vector_transportation.svg',
    'Housing': 'assets/images/ic_vector_home.svg',
    'Shopping': 'assets/images/ic_vector_shopping_bag.svg',
    'Health': 'assets/images/ic_vector_health.svg',
    'Fitness': 'assets/images/ic_vector_fitness.svg',
    'Entertainment': 'assets/images/ic_vector_entertainment.svg',
    'Games': 'assets/images/ic_vector_game.svg',
    'Education': 'assets/images/ic_vector_education.svg',
    'Loans': 'assets/images/ic_vector_loan.svg',
    'Savings': 'assets/images/ic_vector_investment.svg',
    'Investments': 'assets/images/ic_vector_investment.svg',
    'Travel': 'assets/images/ic_vector_travel.svg',
    'Gifts': 'assets/images/ic_vector_gifts.svg',
    'Donations': 'assets/images/ic_vector_donate.svg',
    'Beauty': 'assets/images/ic_vector_beauty.svg',
    'Taxes': 'assets/images/ic_vector_tax.svg',
    'Others': 'assets/images/ic_vector_other.svg',
    'Salary': 'assets/images/ic_vector_salary.svg',
    'Business': 'assets/images/ic_vector_business.svg',
    'Interest Income': 'assets/images/ic_vector_interest_income.svg',
    'Rental Income': 'assets/images/ic_vector_rental_income.svg',
  };

  return iconMap[categoryName] ?? 'assets/images/ic_vector_other.svg';
}
