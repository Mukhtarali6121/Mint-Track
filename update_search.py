import re

with open("lib/presentation/screens/search_screen.dart", "r") as f:
    content = f.read()

# 1. Update _buildListOption signature and UI
old_build_option = """  Widget _buildListOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {"""

new_build_option = """  Widget _buildListOption({
    required String label,
    required bool isSelected,
    bool isIndeterminate = false,
    required VoidCallback onTap,
  }) {"""

content = content.replace(old_build_option, new_build_option)

old_container = """            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accentGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? AppColors.accentGreen : AppColors.border.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),"""

new_container = """            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: (isSelected || isIndeterminate) 
                      ? AppColors.accentGreen 
                      : AppColors.border.withOpacity(0.5),
                  width: (isSelected || isIndeterminate) ? 2.0 : 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: AppColors.accentGreen)
                  : isIndeterminate
                      ? const Icon(Icons.remove, size: 14, color: AppColors.accentGreen)
                      : null,
            ),"""

content = content.replace(old_container, new_container)

# 2. Update All Accounts in search_screen.dart
old_all_accounts = """        _buildListOption(
          label: 'All Accounts',
          isSelected: _accountId == null,
          onTap: () => setState(() => _accountId = null),
        ),"""

new_all_accounts = """        _buildListOption(
          label: 'All Accounts',
          isSelected: _accountId == null,
          isIndeterminate: _accountId != null,
          onTap: () => setState(() => _accountId = null),
        ),
        Container(height: 8, color: Colors.grey.shade100),"""

content = content.replace(old_all_accounts, new_all_accounts)

# 3. Update All Categories
old_all_categories = """        _buildListOption(
          label: 'All Categories',
          isSelected: _category == null,
          onTap: () => setState(() => _category = null),
        ),"""

new_all_categories = """        _buildListOption(
          label: 'All Categories',
          isSelected: _category == null,
          isIndeterminate: _category != null,
          onTap: () => setState(() => _category = null),
        ),
        Container(height: 8, color: Colors.grey.shade100),"""

content = content.replace(old_all_categories, new_all_categories)

# 4. Update All Types
old_all_types = """        _buildListOption(
          label: 'All Types',
          isSelected: _type == null,
          onTap: () => setState(() => _type = null),
        ),"""

new_all_types = """        _buildListOption(
          label: 'All Types',
          isSelected: _type == null,
          isIndeterminate: _type != null,
          onTap: () => setState(() => _type = null),
        ),
        Container(height: 8, color: Colors.grey.shade100),"""

content = content.replace(old_all_types, new_all_types)

with open("lib/presentation/screens/search_screen.dart", "w") as f:
    f.write(content)
print("Updated search_screen.dart")
