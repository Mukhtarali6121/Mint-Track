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

  void _resetFilters() {
    setState(() {
      _type = null;
      _category = null;
      _period = null;
      _customRange = null;
      _accountId = null;
      _sortOption = SortOption.dateDesc;
    });
    // Apply the reset and close the sheet
    widget.onApply(_type, _category, _period, _customRange, _accountId, _sortOption);
    Navigator.pop(context);
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

    return Container(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accentGreen.withOpacity(0.15),
                                AppColors.accentGreen.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: AppColors.accentGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                              Text(
                                'Refine your search',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundScaffold,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Type Filter - Compact
                    _buildCompactSection(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Type',
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildCompactChip(
                            label: 'All',
                            isSelected: _type == null,
                            onTap: () => setState(() => _type = null),
                          ),
                          _buildCompactChip(
                            label: 'Income',
                            isSelected: _type == TransactionType.income,
                            onTap: () => setState(() => _type = TransactionType.income),
                          ),
                          _buildCompactChip(
                            label: 'Expense',
                            isSelected: _type == TransactionType.expense,
                            onTap: () => setState(() => _type = TransactionType.expense),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Filter - Compact
                    _buildCompactSection(
                      icon: Icons.category_rounded,
                      title: 'Category',
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.border.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButtonFormField<String?>(
                          value: _category,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            hintText: 'All Categories',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text('All Categories', style: TextStyle(fontSize: 14))),
                            ...categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c, style: TextStyle(fontSize: 14)))).toList(),
                          ],
                          onChanged: (v) => setState(() => _category = v),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentGreen, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Period Filter - Compact
                    _buildCompactSection(
                      icon: Icons.calendar_today_rounded,
                      title: 'Period',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final p in [
                                PeriodFilter.day,
                                PeriodFilter.week,
                                PeriodFilter.month,
                                PeriodFilter.year,
                                PeriodFilter.custom,
                              ])
                                _buildCompactChip(
                                  label: _labelForFilter(p),
                                  isSelected: _period == p,
                                  onTap: () async {
                                    if (p == PeriodFilter.custom) {
                                      await _pickCustomRange();
                                    }
                                    setState(() => _period = p);
                                  },
                                ),
                            ],
                          ),
                          if (_period == PeriodFilter.custom && _customRange != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.accentGreen.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.date_range_rounded, size: 14, color: AppColors.accentGreen),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${DateFormat.yMMMd().format(_customRange!.start)} - ${DateFormat.yMMMd().format(_customRange!.end)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.accentGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account Filter - Compact
                    Builder(
                      builder: (context) {
                        final accountProvider = context.watch<AccountProvider>();
                        final accounts = accountProvider.accounts;
                        
                        if (accounts.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        return _buildCompactSection(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Account',
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildCompactChip(
                                label: 'All',
                                isSelected: _accountId == null,
                                onTap: () => setState(() => _accountId = null),
                              ),
                              ...accounts.map((account) {
                                final isSelected = _accountId == account.id;
                                return _buildCompactChip(
                                  label: account.name,
                                  isSelected: isSelected,
                                  onTap: () => setState(() => _accountId = account.id),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Apply Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentGreen,
                          AppColors.accentGreen.withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGreen.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          widget.onApply(_type, _category, _period, _customRange, _accountId, _sortOption);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Apply Filters',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Reset Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _resetFilters,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundScaffold,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundScaffold,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: AppColors.accentGreen),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildCompactChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.accentGreen,
                      AppColors.accentGreen.withOpacity(0.8),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.accentGreen : AppColors.border.withOpacity(0.3),
              width: isSelected ? 0 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accentGreen.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
