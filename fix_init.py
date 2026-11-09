with open("lib/presentation/screens/search_screen.dart", "r") as f:
    c = f.read()

c = c.replace("_accountId = widget.initialAccountId;", "_accountIds = widget.initialAccountIds;")

with open("lib/presentation/screens/search_screen.dart", "w") as f:
    f.write(c)
