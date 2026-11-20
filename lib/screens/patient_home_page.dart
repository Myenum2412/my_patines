import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/patient_session.dart';
import '../services/patient_portal_service.dart';
import '../services/records_service.dart';
import '../widgets/app_animations.dart';
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
    this.portalService,
    this.recordsService,
  });

  final PatientSession? session;
  final String? userName;
  final String? email;

  /// Optional injected services (used by tests and screenshots). When omitted
  /// each tab creates its own client for [session].
  final PatientPortalService? portalService;
  final RecordsService? recordsService;

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
        HomeTab(
          key: _homeKey,
          session: session,
          onOpenTab: _selectTab,
          service: widget.portalService,
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
          service: widget.portalService,
        )
      else
        const _PlaceholderTab(
          icon: Icons.calendar_month_outlined,
          title: 'Appointments',
          description: 'Sign in again to see your tokens.',
        ),
      if (session != null)
        MedicalRecordsTab(session: session, service: widget.recordsService)
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
          service: widget.portalService,
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
          service: widget.portalService,
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
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        backgroundColor: AppleColors.canvas,
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
          child: _index == 0
              ? Semantics(
                  key: const ValueKey<int>(0),
                  header: true,
                  label: 'MyClinic home',
                  child: Image.asset(
                    'assets/images/logo-wordmark.png',
                    height: 30,
                    excludeFromSemantics: true,
                  ),
                )
              : Text(
                  _titles[_index],
                  key: ValueKey<int>(_index),
                  style: AppType.title.copyWith(fontSize: 28),
                ),
        ),
        actions: [
          if (session != null && _refreshers[_index] != null)
            _RefreshAction(
              key: ValueKey<int>(_index),
              onTap: _refreshers[_index]!,
            ),
          const SizedBox(width: 12),
        ],
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
    return Tooltip(
      message: 'Refresh',
      child: AppleTapBounce(
        onTap: onTap,
        shrinkScale: 0.96,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppleColors.hairline),
          ),
          child: const Icon(
            Icons.refresh_rounded,
            size: 20,
            color: AppleColors.textPrimary,
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

/// Bottom navigation: a floating white bar whose blue pill, painted in the
/// logo's gradient, slides to the chosen tab.
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

  static const _height = 64.0;

  @override
  Widget build(BuildContext context) {
    final count = _destinations.length;
    final reduceMotion = reduceMotionOf(context);
    return ColoredBox(
      color: AppleColors.canvas,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_height / 2),
              border: Border.all(color: AppleColors.hairline),
              boxShadow: AppleColors.elevatedShadow,
            ),
            padding: const EdgeInsets.all(6),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedAlign(
                    alignment: Alignment(
                      -1 + 2 * currentIndex / (count - 1),
                      0,
                    ),
                    duration: reduceMotion ? Duration.zero : Motion.slide,
                    curve: Motion.easeTravel,
                    child: FractionallySizedBox(
                      widthFactor: 1 / count,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppleColors.brandGradient,
                          borderRadius: BorderRadius.circular(_height / 2),
                          boxShadow: AppleColors.brandShadow,
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
    final color = selected ? Colors.white : AppleColors.textTertiary;
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Motion.hoverIn,
                reverseDuration: Motion.release,
                switchInCurve: Motion.ease,
                switchOutCurve: Motion.ease,
                child: Icon(
                  selected ? destination.activeIcon : destination.inactiveIcon,
                  key: ValueKey<bool>(selected),
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              // Merge with the inherited style so the label keeps the app's
              // font; a bare TextStyle would fall back to the platform face.
              AnimatedDefaultTextStyle(
                duration: Motion.hoverIn,
                curve: Motion.ease,
                style: DefaultTextStyle.of(context).style.merge(
                  TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                    letterSpacing: 0,
                  ),
                ),
                // Long labels shrink to fit their slot so they stay inside
                // the selected pill.
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
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
                color: AppleColors.brandLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 40, color: AppleColors.brand),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
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
