import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/patient_session.dart';
import '../widgets/app_animations.dart';
import '../widgets/apple_ui.dart';
import 'appointments_tab.dart';
import 'billing_tab.dart';
import 'home_tab.dart';
import 'medical_records_tab.dart';
import 'profile_tab.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key, this.session, this.userName, this.email});

  final PatientSession? session;
  final String? userName;
  final String? email;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  double _slideDirection = 1;

  late final AnimationController _tabController = AnimationController(
    vsync: this,
    duration: Motion.panel,
    value: 1,
  );
  late final Animation<double> _tabProgress = CurvedAnimation(
    parent: _tabController,
    curve: Motion.ease,
  );

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
    setState(() {
      _slideDirection = index > _index ? 1 : -1;
      _index = index;
    });
    HapticFeedback.selectionClick();
    if (!reduceMotionOf(context)) _tabController.forward(from: 0);
  }

  /// The refresh handler for each tab, or null where the tab has none.
  late final List<VoidCallback?> _refreshers = [
    () => _homeKey.currentState?.refresh(),
    () => _appointmentsKey.currentState?.refresh(),
    null,
    () => _billingKey.currentState?.refresh(),
    null,
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final pages = <Widget>[
      if (session != null)
        HomeTab(key: _homeKey, session: session, onOpenTab: _selectTab)
      else
        const _PlaceholderTab(
          icon: Icons.home_outlined,
          title: 'Home',
          description: 'Sign in again to see your dashboard.',
        ),
      if (session != null)
        AppointmentsTab(key: _appointmentsKey, session: session)
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
        BillingTab(key: _billingKey, session: session)
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
              title: AnimatedSwitcher(
                duration: Motion.panel,
                reverseDuration: Motion.release,
                switchInCurve: Motion.ease,
                switchOutCurve: Motion.ease,
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: [...previousChildren, ?currentChild],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  _titles[_index],
                  key: ValueKey<int>(_index),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppleColors.textPrimary,
                  ),
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
                if (session != null && _refreshers[_index] != null)
                  _RefreshAction(
                    key: ValueKey<int>(_index),
                    onTap: _refreshers[_index]!,
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _tabProgress,
          builder: (context, child) => Opacity(
            opacity: _tabProgress.value,
            child: Transform.translate(
              offset: Offset(_slideDirection * 8 * (1 - _tabProgress.value), 0),
              child: child,
            ),
          ),
          child: IndexedStack(index: _index, children: pages),
        ),
      ),
      bottomNavigationBar: _AppleBottomNavBar(
        currentIndex: _index,
        onTap: _selectTab,
      ),
    );
  }
}

class _RefreshAction extends StatelessWidget {
  const _RefreshAction({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Refresh',
        child: AppleTapBounce(
          onTap: onTap,
          shrinkScale: 0.96,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppleColors.canvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppleColors.border, width: 0.8),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              size: 19,
              color: AppleColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.label, this.activeIcon, this.inactiveIcon);

  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
}

/// Bottom navigation: one tinted pill slides to the chosen tab.
class _AppleBottomNavBar extends StatelessWidget {
  const _AppleBottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _destinations = [
    _NavDestination('Home', Icons.home_rounded, Icons.home_outlined),
    _NavDestination(
      'Appointments',
      Icons.calendar_month_rounded,
      Icons.calendar_month_outlined,
    ),
    _NavDestination(
      'Records',
      Icons.folder_shared_rounded,
      Icons.folder_shared_outlined,
    ),
    _NavDestination(
      'Billing',
      Icons.receipt_long_rounded,
      Icons.receipt_long_outlined,
    ),
    _NavDestination('Profile', Icons.person_rounded, Icons.person_outline),
  ];

  static const _pillTop = 8.0;
  static const _pillHeight = 30.0;

  @override
  Widget build(BuildContext context) {
    final count = _destinations.length;
    final reduceMotion = reduceMotionOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: const Border(
          top: BorderSide(color: AppleColors.hairline, width: 0.8),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Stack(
                children: [
                  Positioned(
                    top: _pillTop,
                    left: 0,
                    right: 0,
                    height: _pillHeight,
                    child: AnimatedAlign(
                      alignment: Alignment(
                        -1 + 2 * currentIndex / (count - 1),
                        0,
                      ),
                      duration: reduceMotion ? Duration.zero : Motion.slide,
                      curve: Motion.easeTravel,
                      child: FractionallySizedBox(
                        widthFactor: 1 / count,
                        child: Center(
                          child: Container(
                            width: 54,
                            height: _pillHeight,
                            decoration: BoxDecoration(
                              color: AppleColors.blueLight,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < count; i++)
                        _NavBarItem(
                          destination: _destinations[i],
                          selected: i == currentIndex,
                          onTap: () => onTap(i),
                        ),
                    ],
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
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppleColors.blue : AppleColors.textSecondary;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: destination.label,
        excludeSemantics: true,
        child: AppleTapBounce(
          onTap: onTap,
          shrinkScale: 0.96,
          child: Column(
            children: [
              SizedBox(
                height:
                    _AppleBottomNavBar._pillTop +
                    _AppleBottomNavBar._pillHeight,
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: _AppleBottomNavBar._pillTop,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: Motion.hoverIn,
                      reverseDuration: Motion.release,
                      switchInCurve: Motion.ease,
                      switchOutCurve: Motion.ease,
                      child: Icon(
                        selected
                            ? destination.activeIcon
                            : destination.inactiveIcon,
                        key: ValueKey<bool>(selected),
                        size: 22,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: Motion.hoverIn,
                curve: Motion.ease,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: -0.1,
                ),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
            ],
          ),
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
