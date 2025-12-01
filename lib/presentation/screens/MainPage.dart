import 'package:expense_tracker/presentation/screens/dashboard.dart';
import 'package:expense_tracker/presentation/screens/more_screen.dart';
import 'package:expense_tracker/presentation/screens/charts_screen.dart';
import 'package:expense_tracker/presentation/screens/goals_screen_new.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../common/animation_utils.dart';

import '../../theme/app_colors.dart';


class MainPageWidget extends StatefulWidget {
  const MainPageWidget({super.key});

  @override
  State<MainPageWidget> createState() => _MainPageWidgetState();
}

class _MainPageWidgetState extends State<MainPageWidget> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<Widget> _pages = const [
    DashboardScreen(),
    ChartsScreen(),
    GoalsScreenNew(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    // Initialize providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().initialize();
      context.read<AccountProvider>().initialize();
      context.read<GoalProvider>().initialize();
      context.read<RecurringTransactionProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: AnimationUtils.normalDuration,
      curve: AnimationUtils.smoothCurve,
    );
  }

  void _onPageChanged(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), // Disable manual swiping
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics,
                  label: 'Analytics',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.track_changes_outlined,
                  activeIcon: Icons.track_changes,
                  label: 'Goals',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: AnimationUtils.fastDuration,
        curve: AnimationUtils.bounceCurve,
        child: AnimatedContainer(
          duration: AnimationUtils.normalDuration,
          curve: AnimationUtils.smoothCurve,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 20 : 16,
            vertical: isSelected ? 12 : 8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppColors.accentGreen.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: AnimationUtils.fastDuration,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey(isSelected ? 'active_$index' : 'inactive_$index'),
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  size: 22,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: AnimationUtils.fastDuration,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

