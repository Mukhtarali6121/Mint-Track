import sys

with open("lib/presentation/screens/dashboard.dart", "r") as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if "void _showFilterBottomSheet(BuildContext context) {" in line:
        start_idx = i
        break

for i in range(start_idx, len(lines)):
    if "Category? _getCategoryFromFirestore" in lines[i]:
        # Backtrack to the first `  }`
        for j in range(i-1, start_idx, -1):
            if lines[j] == "  }\n" or lines[j] == "  }":
                end_idx = j
                break
        break

print(f"Replacing from {start_idx} to {end_idx}")

with open("new_dashboard_filter.dart", "r") as f:
    new_lines = f.readlines()

m_start = -1
for i, l in enumerate(new_lines):
    if "void _showFilterBottomSheet(BuildContext context) {" in l:
        m_start = i
        break

new_method = new_lines[m_start:-2] # skip closing brace of Dummy class

lines = lines[:start_idx] + new_method + ["\n"] + lines[end_idx+1:]
with open("lib/presentation/screens/dashboard.dart", "w") as f:
    f.writelines(lines)
