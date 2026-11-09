with open("lib/widgets/custom_donut_chart.dart", "r") as f:
    text = f.read()

text = text.replace("Key? key,", "")
text = text.replace(": super(key: key);", ": super(key: key);")
text = text.replace("const CustomDonutChart({\n    Key? key,", "const CustomDonutChart({\n    super.key,")
text = text.replace(".withOpacity(", ".withValues(alpha: ")

with open("lib/widgets/custom_donut_chart.dart", "w") as f:
    f.write(text)
