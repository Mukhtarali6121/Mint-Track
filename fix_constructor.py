with open("lib/presentation/screens/search_screen.dart", "r") as f:
    c = f.read()

c = c.replace("final String? initialAccountId;", "final List<String>? initialAccountIds;")
c = c.replace("this.initialAccountId,", "this.initialAccountIds,")

with open("lib/presentation/screens/search_screen.dart", "w") as f:
    f.write(c)
