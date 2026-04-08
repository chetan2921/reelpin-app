import re
import os

file_path = "lib/screens/reel_detail_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

# backgroundColor to bg(context)
content = content.replace("backgroundColor: AppTheme.white", "backgroundColor: AppTheme.bg(context)")

# Text/Icon/Border Black to fg(context) wherever safe
# Safe to just replace all `AppTheme.black` to `AppTheme.fg(context)` EXCEPT in `computeLuminance() > 0.5 ? AppTheme.black : AppTheme.white;`
content = content.replace("? AppTheme.black : AppTheme.white", "? AppTheme.__BLACK__ : AppTheme.__WHITE__")
# And the snackbar background
content = content.replace("backgroundColor: AppTheme.black,", "backgroundColor: AppTheme.__BLACK__,")

content = content.replace("color: AppTheme.black,", "color: AppTheme.fg(context),")
content = content.replace("color: AppTheme.black", "color: AppTheme.fg(context)")

# The subcategory badge uses `color: AppTheme.white` at line 149/150 for its background.
# I'll replace it but restore the specific ones that need to stay AppTheme.white.
content = content.replace("decoration: BoxDecoration(\n                                  color: AppTheme.white,", "decoration: BoxDecoration(\n                                  color: AppTheme.bg(context),")

# Restore the protected terms
content = content.replace("AppTheme.__BLACK__", "AppTheme.black")
content = content.replace("AppTheme.__WHITE__", "AppTheme.white")

with open(file_path, "w") as f:
    f.write(content)
print("Updated reel_detail_screen.dart")
