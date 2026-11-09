import re

def fix_file(filepath):
    with open(filepath, "r") as f:
        content = f.read()
    
    # We want to find the Container that has width 20 and height 20
    # and replace its decoration and child
    
    pattern = r"width:\s*20,\s*height:\s*20,\s*decoration:\s*BoxDecoration\([\s\S]*?child:\s*isSelected[\s\S]*?null,\s*\),"
    
    replacement = """width: 20,
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
    
    new_content, count = re.subn(pattern, replacement, content)
    
    with open(filepath, "w") as f:
        f.write(new_content)
    
    print(f"Fixed {filepath}: {count} replacements")

fix_file("lib/presentation/screens/dashboard.dart")
fix_file("lib/presentation/screens/search_screen.dart")
