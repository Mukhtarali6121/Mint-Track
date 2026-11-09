import re

with open("lib/presentation/screens/search_screen.dart", "r") as f:
    c = f.read()

# _buildTypePane
old_type_pane = """  Widget _buildTypePane() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildListOption(
          label: 'All Types',
          isSelected: _type == null,
          isIndeterminate: _type != null,
          onTap: () => setState(() => _type = null),
        ),
        const SizedBox(height: 8),
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
  }"""
new_type_pane = """  Widget _buildTypePane() {
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
          isSelected: _types == null || _types!.contains(TransactionType.income),
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
          isSelected: _types == null || _types!.contains(TransactionType.expense),
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
  }"""
if old_type_pane in c: c = c.replace(old_type_pane, new_type_pane)
else: print("Could not find old_type_pane")

# _buildCategoryPane
old_cat_pane = """  Widget _buildCategoryPane(List<String> categories) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildListOption(
          label: 'All Categories',
          isSelected: _category == null,
          isIndeterminate: _category != null,
          onTap: () => setState(() => _category = null),
        ),
        const SizedBox(height: 8),
        ...categories.map(
          (c) => _buildListOption(
            label: c,
            isSelected: _category == c,
            onTap: () => setState(() => _category = c),
          ),
        ),
      ],
    );
  }"""
new_cat_pane = """  Widget _buildCategoryPane(List<String> categories) {
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
                if (_categories!.length == categories.length) _categories = null;
              }
            }),
          ),
        ),
      ],
    );
  }"""
if old_cat_pane in c: c = c.replace(old_cat_pane, new_cat_pane)
else: print("Could not find old_cat_pane")

# _buildAccountPane
old_acc_pane = """  Widget _buildAccountPane(List<Account> accounts) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildListOption(
          label: 'All Accounts',
          isSelected: _accountId == null,
          isIndeterminate: _accountId != null,
          onTap: () => setState(() => _accountId = null),
        ),
        const SizedBox(height: 8),
        ...accounts.map(
          (account) => _buildListOption(
            label: account.name,
            isSelected: _accountId == account.id,
            onTap: () => setState(() => _accountId = account.id),
          ),
        ),
      ],
    );
  }"""
new_acc_pane = """  Widget _buildAccountPane(List<Account> accounts) {
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
            isSelected: _accountIds == null || _accountIds!.contains(account.id),
            onTap: () => setState(() {
              if (_accountIds == null) {
                _accountIds = accounts.map((a) => a.id).toList()..remove(account.id);
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
  }"""
if old_acc_pane in c: c = c.replace(old_acc_pane, new_acc_pane)
else: print("Could not find old_acc_pane")

with open("lib/presentation/screens/search_screen.dart", "w") as f:
    f.write(c)
print("Phase 2 done")
