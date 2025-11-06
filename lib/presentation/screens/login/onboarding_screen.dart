import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_fonts.dart';
import 'login_Screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _animationKey = 0; // Counter to force GIF rebuild
  
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Track Your Income & Expenses',
      subtitle: 'Stay on top of your finances by logging every earning and expense in one simple app.',
      imagePath: 'assets/gif/onBoard_1.gif',
    ),
    OnboardingPage(
      title: 'Understand Where Your Money Goes',
      subtitle: 'Get clear visual analytics to see your spending habits and make better financial decisions.',
      imagePath: 'assets/gif/onBoard_2.gif',
    ),
    OnboardingPage(
      title: 'Save More, Reach Your Goals',
      subtitle: 'Set goals and start saving smarter. Every transaction brings you closer to financial freedom.',
      imagePath: 'assets/gif/onBoard_3.gif',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize progress animation controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Calculate initial progress: 33.33% for first page (page 0)
    final initialProgress = (_currentPage + 1) / _pages.length; // 1/3 = 33.33%
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: initialProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    // Start with initial progress at 33.33%
    _progressController.value = 1.0; // Set to 1.0 so animation shows initialProgress
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    // Calculate progress values evenly divided across 3 pages
                    // Page 0: 33.33%, Page 1: 66.67%, Page 2: 100%
                    final oldProgress = (_currentPage + 1) / _pages.length;
                    final newProgress = (index + 1) / _pages.length;
                    
                    setState(() {
                      _currentPage = index;
                      _animationKey++; // Increment to force GIF rebuild and restart animation
                    });
                    
                    // Animate progress smoothly
                    _progressAnimation = Tween<double>(
                      begin: oldProgress,
                      end: newProgress,
                    ).animate(CurvedAnimation(
                      parent: _progressController,
                      curve: Curves.easeInOut,
                    ));
                    
                    _progressController.forward(from: 0.0);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], index);
                  },
                ),
              ),

              // Bottom Navigation Bar with Skip, Indicators, and Next Button
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Skip Button (Bottom Left)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Page Indicators (Center)
                    _buildPageIndicators(),

                    // Next Button with Progress Bar (Bottom Right)
                    _buildNextButtonWithProgress(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int index) {
    final isVisible = index == _currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // GIF Image - Uses AnimatedGifWidget to restart animation when page becomes visible
          Expanded(
            flex: 3,
            child: Center(
              child: AnimatedGifWidget(
                key: ValueKey('${page.imagePath}_${_animationKey}_${isVisible}'), // Unique key that changes on page change
                imagePath: page.imagePath,
                isVisible: isVisible,
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: AppFonts.titleLarge.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: AppFonts.bodyLarge.copyWith(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.accentGreen
                : AppColors.accentGreen.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildNextButtonWithProgress() {
    final isLastPage = _currentPage == _pages.length - 1;
    
    return GestureDetector(
      onTap: _nextPage,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular Progress Indicator with smooth animation
            SizedBox(
              width: 64,
              height: 64,
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return CircularProgressIndicator(
                    value: _progressAnimation.value,
                    strokeWidth: 3,
                    backgroundColor: AppColors.accentGreen.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
                  );
                },
              ),
            ),
            // Arrow Button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accentGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isLastPage ? Icons.check : Icons.arrow_forward,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedGifWidget extends StatefulWidget {
  final String imagePath;
  final bool isVisible;

  const AnimatedGifWidget({
    super.key,
    required this.imagePath,
    required this.isVisible,
  });

  @override
  State<AnimatedGifWidget> createState() => _AnimatedGifWidgetState();
}

class _AnimatedGifWidgetState extends State<AnimatedGifWidget> {
  @override
  void initState() {
    super.initState();
    // Force rebuild when widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isVisible) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedGifWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When visibility changes from false to true, restart animation
    if (!oldWidget.isVisible && widget.isVisible) {
      setState(() {
        // Force rebuild to restart GIF animation
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use a unique key that changes when page becomes visible to restart animation
    return Image.asset(
      widget.imagePath,
      key: ValueKey('${widget.imagePath}_${widget.isVisible}'),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.image_not_supported,
            size: 64,
            color: AppColors.accentGreen.withOpacity(0.5),
          ),
        );
      },
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final String imagePath;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });
}
