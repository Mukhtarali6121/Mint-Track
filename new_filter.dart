class _FilterSheetState extends State<_FilterSheet> {
  TransactionType? _type;
  String? _category;
  PeriodFilter? _period;
  DateTimeRange? _customRange;
  String? _accountId;
  SortOption _sortOption = SortOption.dateDesc;

  int _selectedTabIndex = 0;
  final List<String> _tabs = ['Sort', 'Type', 'Category', 'Period', 'Account'];

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
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                    'Filter & sort',
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
                          onTap: () => setState(() => _selectedTabIndex = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            color: isSelected ? Colors.white : Colors.transparent,
                            child: Text(
                              _tabs[index],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? AppColors.accentGreen : AppColors.textPrimary,
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
                        widget.onApply(_type, _category, _period, _customRange, _accountId, _sortOption);
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

  Widget _buildRightPaneContent(List<String> categories, List<dynamic> accounts) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildSortPane();
      case 1:
        return _buildTypePane();
      case 2:
        return _buildCategoryPane(categories);
      case 3:
        return _buildPeriodPane();
      case 4:
        return _buildAccountPane(accounts);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSortPane() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildListOption(
          label: 'Date (Newest first)',
          isSelected: _sortOption == SortOption.dateDesc,
          onTap: () => setState(() => _sortOption = SortOption.dateDesc),
        ),
        _buildListOption(
          label: 'Date (Oldest first)',
          isSelected: _sortOption == SortOption.dateAsc,
          onTap: () => setState(() => _sortOption = SortOption.dateAsc),
        ),
        _buildListOption(
          label: 'Amount (High to low)',
          isSelected: _sortOption == SortOption.amountDesc,
          onTap: () => setState(() => _sortOption = SortOption.amountDesc),
        ),
        _buildListOption(
          label: 'Amount (Low to high)',
          isSelected: _sortOption == SortOption.amountAsc,
          onTap: () => setState(() => _sortOption = SortOption.amountAsc),
        ),
        _buildListOption(
          label: 'Category (A to Z)',
          isSelected: _sortOption == SortOption.categoryAsc,
          onTap: () => setState(() => _sortOption = SortOption.categoryAsc),
        ),
      ],
    );
  }

  Widget _buildTypePane() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildListOption(
          label: 'All Types',
          isSelected: _type == null,
          onTap: () => setState(() => _type = null),
        ),
        _buildListOption(
          label: 'Income',
          isSelected: _type == TransactionType.income,
          onTap: () => setState(() => _type = TransactionType.income),
        ),
        _buildListOption(
          label: 'Expense',
          isSelected: _type == TransactionType.expense,
          onTap: () => setState(() => _type = TransactionType.expense),
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
          isSelected: _category == null,
          onTap: () => setState(() => _category = null),
        ),
        ...categories.map((c) => _buildListOption(
          label: c,
          isSelected: _category == c,
          onTap: () => setState(() => _category = c),
        )),
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
        child: Text('No accounts found', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildListOption(
          label: 'All Accounts',
          isSelected: _accountId == null,
          onTap: () => setState(() => _accountId = null),
        ),
        ...accounts.map((account) => _buildListOption(
          label: account.name,
          isSelected: _accountId == account.id,
          onTap: () => setState(() => _accountId = account.id),
        )),
      ],
    );
  }

  Widget _buildListOption({
    required String label,
    required bool isSelected,
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
                  color: isSelected ? AppColors.accentGreen : AppColors.textPrimary,
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
}
