import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'registration_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  static const List<_LandingPageData> _pages = [
    _LandingPageData(
      icon: Icons.travel_explore,
      title: 'Find Accessible Places',
      description: 'Search hospitals, restaurants, parks, banks, and other public places before you visit.',
    ),
    _LandingPageData(
      icon: Icons.accessible_forward,
      title: 'Check Accessibility Details',
      description: 'View wheelchair access, accessible toilets, parking, elevators, opening hours, and contact details.',
    ),
    _LandingPageData(
      icon: Icons.groups,
      title: 'Help the Community',
      description: 'Share ratings, reviews, photos, and corrections so others can make confident travel decisions.',
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _goToNextPage() {
    if (_isLastPage) {
      _openRegistration();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _openRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegistrationScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AccessLink',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 24),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _LandingPage(page: _pages[index]);
                  },
                ),
              ),
              Semantics(
                label: 'Landing page ${_currentPage + 1} of ${_pages.length}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) =>
                        _PageIndicator(isSelected: index == _currentPage),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _goToNextPage,
                  child: Text(
                    _isLastPage ? 'Get Started' : 'Next',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _openLogin,
                  child: const Text(
                    'I already have an account',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingPage extends StatelessWidget {
  const _LandingPage({required this.page});

  final _LandingPageData page;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 112,
              width: 112,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(page.icon, size: 58),
            ),
            const SizedBox(height: 28),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              page.description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 10,
      width: isSelected ? 28 : 10,
      decoration: BoxDecoration(
        color: isSelected ? Colors.black87 : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _LandingPageData {
  const _LandingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
