import sys

with open("lib/presentation/screens/dashboard.dart", "r") as f:
    lines = f.readlines()

start_idx = 1592 # line 1593
end_idx = 2244 # line 2245

with open("new_dashboard_filter.dart", "r") as f:
    new_lines = f.readlines()

m_start = -1
for i, l in enumerate(new_lines):
    if "void _showFilterBottomSheet(BuildContext context) {" in l:
        m_start = i
        break

# include up to -1 to capture `  }`
new_method = new_lines[m_start:-1]

lines = lines[:start_idx] + new_method + ["\n"] + lines[end_idx+1:]
with open("lib/presentation/screens/dashboard.dart", "w") as f:
    f.writelines(lines)
print("Replaced successfully with correct braces")
