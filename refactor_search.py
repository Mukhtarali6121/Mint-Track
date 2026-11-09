import re

with open("lib/presentation/screens/search_screen.dart", "r") as f:
    c = f.read()

# 1. State variables in _SearchScreenState
c = re.sub(r'TransactionType\? _type; // null = all', r'List<TransactionType>? _types;', c)
c = re.sub(r'String\? _category; // null = all', r'List<String>? _categories;', c)
c = re.sub(r'String\? _accountId; // null = all', r'List<String>? _accountIds;', c)

# 2. _applyFilters method
c = c.replace(
    'final matchesType = _type == null || t.type == _type;',
    'final matchesType = _types == null || _types!.contains(t.type);'
)
c = c.replace(
    'final matchesCategory = _category == null || t.category == _category;',
    'final matchesCategory = _categories == null || _categories!.contains(t.category);'
)
c = c.replace(
    'final matchesAccount = _accountId == null || t.accountId == _accountId;',
    'final matchesAccount = _accountIds == null || _accountIds!.contains(t.accountId);'
)

# 3. _openFilters call
c = c.replace('initialType: _type,', 'initialTypes: _types,')
c = c.replace('initialCategory: _category,', 'initialCategories: _categories,')
c = c.replace('initialAccountId: _accountId,', 'initialAccountIds: _accountIds,')

# Wait, the onApply callback
old_onapply = """          onApply: (type, category, period, custom, accountId, sort) {
            setState(() {
              _type = type;
              _category = category;
              _period = period;
              _customRange = custom;
              _accountId = accountId;
              _sortOption = sort;
            });"""
new_onapply = """          onApply: (types, categories, period, custom, accountIds, sort) {
            setState(() {
              _types = types;
              _categories = categories;
              _period = period;
              _customRange = custom;
              _accountIds = accountIds;
              _sortOption = sort;
            });"""
c = c.replace(old_onapply, new_onapply)

# 4. _FilterSheet class definition
old_filtersheet_def = """class _FilterSheet extends StatefulWidget {
  final TransactionType? initialType;
  final String? initialCategory;
  final PeriodFilter? initialPeriod;
  final DateTimeRange? initialCustom;
  final String? initialAccountId;
  final SortOption initialSort;
  final Function(
    TransactionType? type,
    String? category,
    PeriodFilter? period,
    DateTimeRange? custom,
    String? accountId,
    SortOption sort,
  ) onApply;

  const _FilterSheet({
    this.initialType,
    this.initialCategory,
    this.initialPeriod,
    this.initialCustom,
    this.initialAccountId,"""

new_filtersheet_def = """class _FilterSheet extends StatefulWidget {
  final List<TransactionType>? initialTypes;
  final List<String>? initialCategories;
  final PeriodFilter? initialPeriod;
  final DateTimeRange? initialCustom;
  final List<String>? initialAccountIds;
  final SortOption initialSort;
  final Function(
    List<TransactionType>? types,
    List<String>? categories,
    PeriodFilter? period,
    DateTimeRange? custom,
    List<String>? accountIds,
    SortOption sort,
  ) onApply;

  const _FilterSheet({
    this.initialTypes,
    this.initialCategories,
    this.initialPeriod,
    this.initialCustom,
    this.initialAccountIds,"""
c = c.replace(old_filtersheet_def, new_filtersheet_def)

# 5. _FilterSheetState variables
c = re.sub(r'TransactionType\? _type;\n', r'List<TransactionType>? _types;\n', c)
c = re.sub(r'String\? _category;\n', r'List<String>? _categories;\n', c)
c = re.sub(r'String\? _accountId;\n', r'List<String>? _accountIds;\n', c)

old_initstate = """  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = widget.initialCategory;
    _period = widget.initialPeriod ?? PeriodFilter.month;
    _customRange = widget.initialCustom;
    _accountId = widget.initialAccountId;
    _sortOption = widget.initialSort;
  }"""
new_initstate = """  void initState() {
    super.initState();
    _types = widget.initialTypes != null ? List.from(widget.initialTypes!) : null;
    _categories = widget.initialCategories != null ? List.from(widget.initialCategories!) : null;
    _period = widget.initialPeriod ?? PeriodFilter.month;
    _customRange = widget.initialCustom;
    _accountIds = widget.initialAccountIds != null ? List.from(widget.initialAccountIds!) : null;
    _sortOption = widget.initialSort;
  }"""
c = c.replace(old_initstate, new_initstate)

old_reset = """  void _resetFilters() {
    setState(() {
      _type = null;
      _category = null;
      _period = PeriodFilter.month;
      _customRange = null;
      _accountId = null;
      _sortOption = SortOption.dateDesc;
    });
  }"""
new_reset = """  void _resetFilters() {
    setState(() {
      _types = null;
      _categories = null;
      _period = PeriodFilter.month;
      _customRange = null;
      _accountIds = null;
      _sortOption = SortOption.dateDesc;
    });
  }"""
c = c.replace(old_reset, new_reset)

old_apply_btn = """widget.onApply(
                          _type,
                          _category,
                          _period,
                          _customRange,
                          _accountId,
                          _sortOption,
                        );"""
new_apply_btn = """widget.onApply(
                          _types,
                          _categories,
                          _period,
                          _customRange,
                          _accountIds,
                          _sortOption,
                        );"""
c = c.replace(old_apply_btn, new_apply_btn)


with open("lib/presentation/screens/search_screen.dart", "w") as f:
    f.write(c)
print("Phase 1 done")
