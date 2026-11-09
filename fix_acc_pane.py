import re

with open("lib/presentation/screens/search_screen.dart", "r") as f:
    c = f.read()

old_acc_pane = """  Widget _buildAccountPane(List<dynamic> accounts) {
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

new_acc_pane = """  Widget _buildAccountPane(List<dynamic> accounts) {
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
            isSelected: _accountIds == null || _accountIds!.contains(account.id),
            onTap: () => setState(() {
              if (_accountIds == null) {
                _accountIds = accounts.map<String>((a) => a.id as String).toList()..remove(account.id);
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

if old_acc_pane in c:
    c = c.replace(old_acc_pane, new_acc_pane)
    print("Replaced old_acc_pane")
else:
    print("old_acc_pane not found exactly. Using regex.")
    pattern = r"Widget _buildAccountPane\(List<dynamic> accounts\) \{.*?return ListView\(.*?\];\n  \}"
    c, count = re.subn(pattern, new_acc_pane, c, flags=re.DOTALL)
    print(f"Regex replaced {count} times")

with open("lib/presentation/screens/search_screen.dart", "w") as f:
    f.write(c)
