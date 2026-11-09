with open("lib/presentation/screens/search_screen.dart", "r") as f:
    c = f.read()

old_reset = """  void _resetFilters() {
    setState(() {
      _type = null;
      _category = null;
      _period = null;
      _customRange = null;
      _accountId = null;
      _sortOption = SortOption.dateDesc;
    });
  }"""

new_reset = """  void _resetFilters() {
    setState(() {
      _types = null;
      _categories = null;
      _period = null;
      _customRange = null;
      _accountIds = null;
      _sortOption = SortOption.dateDesc;
    });
  }"""

c = c.replace(old_reset, new_reset)

# also fix line 1227 where it's probably passing _types to a function that wants type
# wait, what's at 1227?

with open("lib/presentation/screens/search_screen.dart", "w") as f:
    f.write(c)
