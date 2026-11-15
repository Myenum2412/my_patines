import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/patient_session.dart';
import '../widgets/apple_ui.dart';
import 'appointments_tab.dart';
import 'billing_tab.dart';
import 'home_tab.dart';
import 'medical_records_tab.dart';
import 'profile_tab.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({
    super.key,
    this.session,
    this.userName,
    this.email,
  });

  final PatientSession? session;
  final String? userName;
  final String? email;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  int _index = 0;

  final GlobalKey<HomeTabState> _homeKey = GlobalKey<HomeTabState>();
  final GlobalKey<AppointmentsTabState> _appointmentsKey =
      GlobalKey<AppointmentsTabState>();
  final GlobalKey<BillingTabState> _billingKey = GlobalKey<BillingTabState>();

  static const _titles = [
    'Home',
    'Appointments',
    'Medical Record',
    'Billing',
    'Profile',
  ];

  void _selectTab(int index) {
    if (index < 0 || index > 4 || index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final pages = <Widget>[
      if (session != null)
        HomeTab(
          key: _homeKey,
          session: session,
          onOpenTab: _selectTab,
        )
      else
        const _PlaceholderTab(
          icon: Icons.home_outlined,
          title: 'Home',
          description: 'Sign in again to see your dashboard.',
        ),
      if (session != null)
        AppointmentsTab(
          key: _appointmentsKey,
          session: session,
        )
      else
        const _PlaceholderTab(
          icon: Icons.calendar_month_outlined,
          title: 'Appointments',
          description: 'Sign in again to see your tokens.',
        ),
      if (session != null)
        MedicalRecordsTab(session: session)
      else
        const _PlaceholderTab(
          icon: Icons.folder_shared_outlined,
          title: 'Medical Record',
          description: 'Sign in again to load your medical records.',
        ),
      if (session != null)
        BillingTab(
          key: _billingKey,
          session: session,
        )
      else
        const _PlaceholderTab(
          icon: Icons.receipt_long_outlined,
          title: 'Billing',
          description: 'Sign in again to see your bills and payments.',
        ),
      if (session != null)
        ProfileTab(
          session: session,
          onProfileUpdated: () => _homeKey.currentState?.refresh(),
        )
      else
        const _PlaceholderTab(
          icon: Icons.person_outline,
          title: 'Profile',
          description: 'Sign in again to view your profile.',
        ),
    ];

    return Scaffold(
      backgroundColor: AppleColors.canvas,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              title: Text(
                _titles[_index],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppleColors.textPrimary,
                ),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0.8),
                child: Container(
                  color: AppleColors.border.withValues(alpha: 0.6),
                  height: 0.8,
                ),
              ),
              actions: [
                if (_index == 0 && session != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppleTapBounce(
                      onTap: () => _homeKey.currentState?.refresh(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppleColors.canvas,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppleColors.border,
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: AppleColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                if (_index == 1 && session != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppleTapBounce(
                      onTap: () => _appointmentsKey.currentState?.refresh(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppleColors.canvas,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppleColors.border,
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: AppleColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                if (_index == 3 && session != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppleTapBounce(
                      onTap: () => _billingKey.currentState?.refresh(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppleColors.canvas,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppleColors.border,
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 19,
                          color: AppleColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: pages,
        ),
      ),
      bottomNavigationBar: _AppleBottomNavBar(
        currentIndex: _index,
        onTap: _selectTab,
      ),
    );
  }
}

class _AppleBottomNavBar extends StatelessWidget {
  const _AppleBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        border: const Border(
          top: BorderSide(color: AppleColors.hairline, width: 0.8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  _NavBarItem(
                    index: 0,
                    currentIndex: currentIndex,
                    label: 'Home',
                    activeIcon: Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                    onTap: onTap,
                  ),
                  _NavBarItem(
                    index: 1,
                    currentIndex: currentIndex,
                    label: 'Appointments',
                    activeIcon: Icons.calendar_month_rounded,
                    inactiveIcon: Icons.calendar_month_outlined,
                    onTap: onTap,
                  ),
                  _NavBarItem(
                    index: 2,
                    currentIndex: currentIndex,
                    label: 'Records',
                    activeIcon: Icons.folder_shared_rounded,
                    inactiveIcon: Icons.folder_shared_outlined,
                    onTap: onTap,
                  ),
                  _NavBarItem(
                    index: 3,
                    currentIndex: currentIndex,
                    label: 'Billing',
                    activeIcon: Icons.receipt_long_rounded,
                    inactiveIcon: Icons.receipt_long_outlined,
                    onTap: onTap,
                  ),
                  _NavBarItem(
                    index: 4,
                    currentIndex: currentIndex,
                    label: 'Profile',
                    activeIcon: Icons.person_rounded,
                    inactiveIcon: Icons.person_outline,
                    onTap: onTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.index,
    required this.currentIndex,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: AppleTapBounce(
        onTap: () => onTap(index),
        shrinkScale: 0.94,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                size: 24,
                color: isSelected ? AppleColors.blue : AppleColors.textTertiary,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppleColors.blue : AppleColors.textTertiary,
                letterSpacing: -0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppleColors.blueLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 40, color: AppleColors.blue),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppleColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppleColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
