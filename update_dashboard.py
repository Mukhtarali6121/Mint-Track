import re

with open("lib/presentation/screens/dashboard.dart", "r") as f:
    content = f.read()

# 1. Update buildListOption signature and UI
old_build_option = """          Widget buildListOption({
            required String label,
            required bool isSelected,
            required VoidCallback onTap,
          }) {"""

new_build_option = """          Widget buildListOption({
            required String label,
            required bool isSelected,
            bool isIndeterminate = false,
            required VoidCallback onTap,
          }) {"""

content = content.replace(old_build_option, new_build_option)

old_container = """                    Container(
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

new_container = """                    Container(
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

# 2. Update All Accounts in dashboard.dart
old_all_accounts = """                buildListOption(
                  label: 'All Accounts',
                  isSelected: tempAccountId == null,
                  onTap: () => setState(() => tempAccountId = null),
                ),"""

new_all_accounts = """                buildListOption(
                  label: 'All Accounts',
                  isSelected: tempAccountId == null,
                  isIndeterminate: tempAccountId != null,
                  onTap: () => setState(() => tempAccountId = null),
                ),
                Container(height: 8, color: Colors.grey.shade100),"""

content = content.replace(old_all_accounts, new_all_accounts)

with open("lib/presentation/screens/dashboard.dart", "w") as f:
    f.write(content)
print("Updated dashboard.dart")
