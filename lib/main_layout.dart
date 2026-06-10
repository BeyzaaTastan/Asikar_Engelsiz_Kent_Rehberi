import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'screens/home/disabled_home.dart';
import 'screens/home/volunteer_home.dart';
import 'screens/home/standard_home.dart';
import 'screens/map_screen.dart';
import 'screens/community_screen.dart';
import 'widgets/accessibility_drawer.dart';

class MainLayout extends StatefulWidget {
  final String userType;

  const MainLayout({super.key, required this.userType});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    Widget getHomeWidget() {
      if (widget.userType == "Engelli") return const DisabledHomeScreen();
      if (widget.userType == "Gönüllü") return const VolunteerHomeScreen();
      return const StandardHomeScreen();
    }

    final List<Widget> pages = [
      const CommunityScreen(),                        // İndeks 0 (Topluluk ekranı)
      getHomeWidget(),                                // İndeks 1 (Dinamik Ana Sayfa)
      const MapScreen(),                              // İndeks 2 (Harita)
    ];

    return Scaffold(
      drawer: const AccessibilityDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, "Topluluk", Icons.group),
          _buildNavItem(1, "Ana Sayfa", Icons.home),
          _buildNavItem(2, "Harita", Icons.map),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
      bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppColors.primary : Colors.grey.shade500,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? AppColors.primary : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
