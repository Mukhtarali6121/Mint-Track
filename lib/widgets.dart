import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'models/dynamic_category.dart';
import 'providers/transaction_provider.dart';

class AmountTile extends StatelessWidget {
  const AmountTile({super.key, required this.label, required this.amount, required this.color});

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(
            currency.format(amount),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class TransactionList extends StatelessWidget {
  const TransactionList({super.key, required this.items});

  final List<TransactionItem> items;

  String _getCategoryIconPath(String categoryName) {
    final dynamicCategory = DynamicCategory(name: categoryName, iconName: categoryName);
    return dynamicCategory.iconPath;
  }

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
    if (items.isEmpty) {
      return const Center(child: Text('No transactions'));
    }
    final currency = NumberFormat.currency(symbol: '₹');
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final t = items[index];
        final isIncome = t.type == TransactionType.income;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: (isIncome ? Colors.teal : Colors.redAccent).withOpacity(0.15),
            child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.teal : Colors.redAccent),
          ),
          title: Text(t.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat.yMMMd().add_jm().format(t.date)),
              const SizedBox(height: 2),
              Row(
                children: [
                  SvgPicture.asset(
                    _getCategoryIconPath(t.category),
                    colorFilter: ColorFilter.mode(
                      Theme.of(context).colorScheme.onSurfaceVariant,
                      BlendMode.srcIn,
                    ),
                    width: 14,
                    height: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t.category,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
              (isIncome ? '+' : '-') + currency.format(t.amount),
              style: TextStyle(color: isIncome ? Colors.teal : Colors.redAccent, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}

