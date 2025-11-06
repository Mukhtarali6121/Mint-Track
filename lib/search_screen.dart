import 'package:expense_tracker/models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'transaction_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();

  TransactionType? _type; // null = all
  String? _category; // null = all
  PeriodFilter _period = PeriodFilter.month;
  DateTimeRange? _customRange;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  DateTimeRange _currentRange() {
    final now = DateTime.now();
    switch (_period) {
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

    return all.where((t) {
      final inRange = !t.date.isBefore(range.start) && !t.date.isAfter(range.end);
      final matchesType = _type == null || t.type == _type;
      final matchesCategory = _category == null || t.category == _category;
      final matchesQuery = query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          (t.note?.toLowerCase().contains(query) ?? false) ||
          t.category.toLowerCase().contains(query);
      return inRange && matchesType && matchesCategory && matchesQuery;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _openFilters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _FilterSheet(
          initialType: _type,
          initialCategory: _category,
          initialPeriod: _period,
          initialCustom: _customRange,
          onApply: (type, category, period, custom) {
            setState(() {
              _type = type;
              _category = category;
              _period = period;
              _customRange = custom;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final all = provider.getAllTransactions();
    final results = _applyFilters(all);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      hintText: 'Search by title, note, or category',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune),
                  tooltip: 'Filter',
                )
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${results.length} result${results.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No matching transactions'))
                  : _ResultsList(items: results),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.items});

  final List<TransactionItem> items;

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
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final t = items[index];
        final color = t.type == TransactionType.income ? Colors.teal : Colors.redAccent;
        final sign = t.type == TransactionType.income ? '+' : '-';
        return ListTile(
          title: Text(t.title.isNotEmpty ? t.title : t.category),
          subtitle: Text('${t.category} • ${DateFormat.yMMMd().format(t.date)}'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                await _deleteTransaction(context, t);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
            child: Text(
              '$sign${t.amount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
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
    required this.onApply,
  });

  final TransactionType? initialType;
  final String? initialCategory;
  final PeriodFilter initialPeriod;
  final DateTimeRange? initialCustom;
  final void Function(TransactionType?, String?, PeriodFilter, DateTimeRange?) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  TransactionType? _type;
  String? _category;
  PeriodFilter _period = PeriodFilter.month;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = widget.initialCategory;
    _period = widget.initialPeriod;
    _customRange = widget.initialCustom;
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialDateRange: _customRange,
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Type', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _type == null,
                  onSelected: (_) => setState(() => _type = null),
                ),
                ChoiceChip(
                  label: const Text('Income'),
                  selected: _type == TransactionType.income,
                  onSelected: (_) => setState(() => _type = TransactionType.income),
                ),
                ChoiceChip(
                  label: const Text('Expense'),
                  selected: _type == TransactionType.expense,
                  onSelected: (_) => setState(() => _type = TransactionType.expense),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>
              (
              value: _category,
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All Categories')),
                ...categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))).toList(),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 16),
            const Text('Period', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  ChoiceChip(
                    label: Text(_labelForFilter(p)),
                    selected: _period == p,
                    onSelected: (_) async {
                      if (p == PeriodFilter.custom) {
                        await _pickCustomRange();
                      }
                      setState(() => _period = p);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_period == PeriodFilter.custom && _customRange != null)
              Text(
                '${DateFormat.yMMMd().format(_customRange!.start)} - ${DateFormat.yMMMd().format(_customRange!.end)}',
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onApply(_type, _category, _period, _customRange);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('Apply Filters'),
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


