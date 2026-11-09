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

new_method = new_lines[m_start:-2] # skip closing brace of Dummy class

# Sanity check: verify start_idx is actually the start
if "void _showFilterBottomSheet(BuildContext context) {" not in lines[start_idx]:
    print("Error: start_idx is wrong: " + lines[start_idx])
    sys.exit(1)

# Sanity check: verify end_idx is actually the end of the method
if lines[end_idx].strip() != "}":
    print("Error: end_idx is wrong: " + lines[end_idx])
    sys.exit(1)

# Ensure line 2246 is the class closing brace
if lines[end_idx + 1].strip() != "}":
    print("Error: line after end_idx is not class closing brace: " + lines[end_idx+1])
    sys.exit(1)

lines = lines[:start_idx] + new_method + ["\n"] + lines[end_idx+1:]
with open("lib/presentation/screens/dashboard.dart", "w") as f:
    f.writelines(lines)
print("Replaced successfully")
