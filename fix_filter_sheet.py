import re

with open("lib/presentation/screens/search_screen.dart", "r") as f:
    c = f.read()

# Fix widget constructor and fields
pattern1 = r"class _FilterSheet extends StatefulWidget \{.*?onApply;"
replacement1 = """class _FilterSheet extends StatefulWidget {
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
  ) onApply;"""

c = re.sub(pattern1, replacement1, c, flags=re.DOTALL)

# Fix initState
old_init = """  void initState() {
    super.initState();
    _type = widget.initialType;
    _category = widget.initialCategory;
    _period = widget.initialPeriod;
    _customRange = widget.initialCustom;
    _accountId = widget.initialAccountId;
    _sortOption = widget.initialSort;
  }"""
new_init = """  void initState() {
    super.initState();
    _types = widget.initialTypes != null ? List.from(widget.initialTypes!) : null;
    _categories = widget.initialCategories != null ? List.from(widget.initialCategories!) : null;
    _period = widget.initialPeriod;
    _customRange = widget.initialCustom;
    _accountIds = widget.initialAccountIds != null ? List.from(widget.initialAccountIds!) : null;
    _sortOption = widget.initialSort;
  }"""
c = c.replace(old_init, new_init)

with open("lib/presentation/screens/search_screen.dart", "w") as f:
    f.write(c)
