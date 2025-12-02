import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';

class SetupScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> options;
  final bool multiSelect;
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;
  final Function(dynamic selected) onNext; // <-- change type
  final VoidCallback onSkip;
  final dynamic previousSelection;

  const SetupScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.multiSelect,
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    this.previousSelection,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? selectedOption;
  List<String> selectedOptions = [];

  @override
  void initState() {
    super.initState();

    // Restore previously selected value
    if (!widget.multiSelect && widget.previousSelection != null) {
      selectedOption = widget.previousSelection;
    }

    if (widget.multiSelect && widget.previousSelection != null) {
      selectedOptions = List<String>.from(widget.previousSelection);
    }

    // Default for first step
    if (!widget.multiSelect &&
        selectedOption == null &&
        widget.options.contains("🇮🇳 INR (₹)")) {
      selectedOption = "🇮🇳 INR (₹)";
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: widget.currentStep > 1
            ? IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: widget.onBack,
        )
            : null,

      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              LinearProgressIndicator(
                value: widget.currentStep / widget.totalSteps,
                color: AppColors.accentGreen,
                backgroundColor: AppColors.backgroundLight,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 24),

              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Options Grid/List
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: widget.options.map((option) {
                      final isSelected = widget.multiSelect
                          ? selectedOptions.contains(option)
                          : selectedOption == option;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (widget.multiSelect) {
                              // Check max selection limit for expense/income categories (step 3 and 4)
                              // Step 3 = expense categories, Step 4 = income categories
                              final isCategoryStep = widget.currentStep == 3 || widget.currentStep == 4;
                              final maxSelections = 10; // Max 10 selections for categories
                              
                              if (isSelected) {
                                selectedOptions.remove(option);
                              } else {
                                if (isCategoryStep && selectedOptions.length >= maxSelections) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('You can select up to $maxSelections ${widget.currentStep == 3 ? 'expense' : 'income'} categories'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                selectedOptions.add(option);
                              }
                            } else {
                              selectedOption = option;
                            }
                          });
                        },
                        child: Container(
                          width: widget.multiSelect
                              ? (MediaQuery.of(context).size.width / 2) - 36
                              : double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 18),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.accentGreen : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentGreen
                                  : Colors.grey.shade300,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: AppColors.accentGreen.withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                            ],
                          ),
                          child: Text(
                            option,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              const Center(
                child: const Text(
                  "You can customize later in the app",
                  style: TextStyle(color: Colors.black45, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  // Expanded(
                  //   child: OutlinedButton(
                  //     onPressed: widget.onSkip,
                  //     style: OutlinedButton.styleFrom(
                  //       side: BorderSide(color: Colors.grey.shade400),
                  //       padding: const EdgeInsets.symmetric(vertical: 14),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10),
                  //       ),
                  //     ),
                  //     child: const Text("Skip",
                  //         style: TextStyle(color: Colors.black87)),
                  //   ),
                  // ),
                  // const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Check if anything is selected
                        if (widget.multiSelect) {
                          if (selectedOptions.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select at least one option')),
                            );
                            return;
                          }
                          widget.onNext(selectedOptions);

                        } else {
                          if (selectedOption == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select an option')),
                            );
                            return;
                          }
                          widget.onNext(selectedOption);
                        }

                        // If selection is valid, go to next step
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Next",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Center(
                child: Text(
                  "QUESTION ${widget.currentStep} OF ${widget.totalSteps}",
                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
