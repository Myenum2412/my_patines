import 'package:flutter/material.dart';

import '../models/patient_session.dart';
import '../services/patient_portal_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_animations.dart';
import '../widgets/apple_ui.dart';
import 'book_appointment_page.dart';

enum _AppointmentDateScope { today, upcoming, all }
enum _AppointmentStatusFilter { all, incompleted, completed }

/// Dedicated Appointments Tab showing token list, today's schedule,
/// and clear completed vs incompleted status indicators.
class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({
    super.key,
    required this.session,
    this.onOpenBookAppointment,
    this.service,
  });

  final PatientSession session;
  final VoidCallback? onOpenBookAppointment;
  final PatientPortalService? service;

  @override
  State<AppointmentsTab> createState() => AppointmentsTabState();
}

class AppointmentsTabState extends State<AppointmentsTab> {
  late final PatientPortalService _service;
  late final bool _ownsService;

  List<AppointmentEntry>? _appointments;
  bool _loading = true;
  String? _error;

  _AppointmentDateScope _dateScope = _AppointmentDateScope.today;
  _AppointmentStatusFilter _statusFilter = _AppointmentStatusFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PatientPortalService(session: widget.session);
    _ownsService = widget.service == null;
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  Future<void> refresh() => _load(showSpinner: false);

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && _appointments == null) {
      setState(() => _loading = true);
    }
    try {
      final list = await _service.fetchAppointments();
      if (!mounted) return;
      setState(() {
        _appointments = list;
        _error = null;
        _loading = false;
      });
    } on PortalException catch (error) {
      if (!mounted) return;
      if (_appointments == null) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _showMessage(error.message);
      }
    } catch (_) {
      if (!mounted) return;
      const message = 'Could not load your appointments. Please try again.';
      if (_appointments == null) {
        setState(() {
          _error = message;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _showMessage(message);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openBooking() {
    if (widget.onOpenBookAppointment != null) {
      widget.onOpenBookAppointment!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookAppointmentPage(
          session: widget.session,
          onAppointmentBooked: refresh,
        ),
      ),
    );
  }

  bool _isToday(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (dateStr.startsWith(todayStr)) return true;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return false;
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  bool _isUpcoming(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return false;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return parsed.isAfter(todayStart);
  }

  void _resetFilters() {
    setState(() {
      _dateScope = _AppointmentDateScope.today;
      _statusFilter = _AppointmentStatusFilter.all;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _appointments == null) {
      return const SkeletonLoader();
    }
    if (_error != null && _appointments == null) {
      return _AppointmentsError(message: _error!, onRetry: _load);
    }

    final all = _appointments ?? const <AppointmentEntry>[];
    final todayList = all.where((a) => _isToday(a.date)).toList();
    final todayCompleted = todayList.where((a) => a.isCompleted).length;
    final todayIncompleted = todayList.where((a) => a.isIncompleted).length;

    // Apply Date Scope
    var list = switch (_dateScope) {
      _AppointmentDateScope.today => todayList,
      _AppointmentDateScope.upcoming =>
        all.where((a) => _isUpcoming(a.date)).toList(),
      _AppointmentDateScope.all => all,
    };

    // Apply Status Filter
    list = switch (_statusFilter) {
      _AppointmentStatusFilter.all => list,
      _AppointmentStatusFilter.completed =>
        list.where((a) => a.isCompleted).toList(),
      _AppointmentStatusFilter.incompleted =>
        list.where((a) => a.isIncompleted).toList(),
    };

    // Apply Search Query
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((a) {
        if (a.doctorName?.toLowerCase().contains(query) ?? false) return true;
        if (a.department?.toLowerCase().contains(query) ?? false) return true;
        if (a.reason?.toLowerCase().contains(query) ?? false) return true;
        if (a.tokenNumber?.toString().contains(query) ?? false) return true;
        return false;
      }).toList();
    }

    // Sort: Today's tokens by token number, others by date
    list.sort((a, b) {
      if (_dateScope == _AppointmentDateScope.today) {
        final ta = a.tokenNumber ?? 999;
        final tb = b.tokenNumber ?? 999;
        return ta.compareTo(tb);
      }
      final da = DateTime.tryParse(a.date ?? '');
      final db = DateTime.tryParse(b.date ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    final isFilterActive = _dateScope != _AppointmentDateScope.today ||
        _statusFilter != _AppointmentStatusFilter.all ||
        query.isNotEmpty;

    final content = RefreshIndicator(
      onRefresh: refresh,
      color: const Color(0xFF2196F3),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1. Hero Token Summary Card
          _TokenHeroCard(
            todayCount: todayList.length,
            completedCount: todayCompleted,
            incompletedCount: todayIncompleted,
            onBookAppointment: _openBooking,
          ),
          const SizedBox(height: 18),

          // 2. Section Header with Counter & Reset
          Row(
            children: [
              Expanded(
                child: Text(
                  _dateScope == _AppointmentDateScope.today
                      ? "Today's Tokens (${list.length})"
                      : 'Appointments (${list.length})',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (isFilterActive) ...[
                AppleTapBounce(
                  onTap: _resetFilters,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppleColors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${list.length} of ${all.length}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Search Field
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search token #, doctor, or department...',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 4. Filter Chips (Date Scope & Status)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                  label: "Today's Tokens",
                  icon: Icons.today_rounded,
                  selected: _dateScope == _AppointmentDateScope.today,
                  onTap: () => setState(
                      () => _dateScope = _AppointmentDateScope.today),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Upcoming',
                  icon: Icons.event_available_rounded,
                  selected: _dateScope == _AppointmentDateScope.upcoming,
                  onTap: () => setState(
                      () => _dateScope = _AppointmentDateScope.upcoming),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'All Visits',
                  icon: Icons.calendar_month_rounded,
                  selected: _dateScope == _AppointmentDateScope.all,
                  onTap: () =>
                      setState(() => _dateScope = _AppointmentDateScope.all),
                ),
                Container(
                  height: 20,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: const Color(0xFFCBD5E1),
                ),
                _FilterPill(
                  label: 'All Status',
                  selected: _statusFilter == _AppointmentStatusFilter.all,
                  onTap: () => setState(
                      () => _statusFilter = _AppointmentStatusFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Incompleted',
                  icon: Icons.hourglass_top_rounded,
                  accentColor: AppleColors.blue,
                  selected:
                      _statusFilter == _AppointmentStatusFilter.incompleted,
                  onTap: () => setState(() =>
                      _statusFilter = _AppointmentStatusFilter.incompleted),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Completed',
                  icon: Icons.check_circle_rounded,
                  accentColor: AppleColors.green,
                  selected: _statusFilter == _AppointmentStatusFilter.completed,
                  onTap: () => setState(
                      () => _statusFilter = _AppointmentStatusFilter.completed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. Token Cards List or Empty State
          if (list.isEmpty)
            _TokensEmptyState(
              dateScope: _dateScope,
              onResetFilters: _resetFilters,
              onBookAppointment: _openBooking,
            )
          else
            for (final (index, apt) in list.indexed) ...[
              RevealItem(
                index: index,
                child: _TokenCard(
                  appointment: apt,
                  isToday: _isToday(apt.date),
                  onTap: () => _showTokenDetailsModal(context, apt),
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
    return FadeSlideIn(
      child: RevealScope(
        replayKey: (_dateScope, _statusFilter),
        child: content,
      ),
    );
  }

  void _showTokenDetailsModal(BuildContext context, AppointmentEntry apt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TokenSlipModal(
        appointment: apt,
        clinicName: widget.session.clinicName ?? 'Healthcare Clinic',
        isToday: _isToday(apt.date),
      ),
    );
  }
}

class _TokenHeroCard extends StatelessWidget {
  const _TokenHeroCard({
    required this.todayCount,
    required this.completedCount,
    required this.incompletedCount,
    required this.onBookAppointment,
  });

  final int todayCount;
  final int completedCount;
  final int incompletedCount;
  final VoidCallback onBookAppointment;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayFormatted = formatDate(now);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF1D1D1F),
        boxShadow: AppleColors.elevatedShadow,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'TOKEN DISPATCH & QUEUE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        todayFormatted,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Today's Clinic Tokens",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  todayCount == 0
                      ? 'No tokens scheduled for today yet.'
                      : '$todayCount token${todayCount == 1 ? '' : 's'} assigned for today’s consultation.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStatBox(
                        label: 'Incompleted',
                        count: incompletedCount,
                        color: const Color(0xFF60A5FA),
                        icon: Icons.hourglass_top_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroStatBox(
                        label: 'Completed',
                        count: completedCount,
                        color: const Color(0xFF34D399),
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onBookAppointment,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppleColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                    label: const Text(
                      'Book New Token',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatBox extends StatelessWidget {
  const _HeroStatBox({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard({
    required this.appointment,
    required this.isToday,
    required this.onTap,
  });

  final AppointmentEntry appointment;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = appointment.isCompleted;
    final token = appointment.tokenNumber;

    return AppleTapBounce(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: completed ? const Color(0xFFE2E8F0) : AppleColors.blue.withValues(alpha: 0.3),
            width: completed ? 0.8 : 1.2,
          ),
          boxShadow: AppleColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Ticket Token Stub
              Container(
                width: 78,
                decoration: BoxDecoration(
                  color: completed
                      ? const Color(0xFF248A3D)
                      : AppleColors.blue,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'TOKEN',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      token != null ? '#$token' : '--',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        appointment.session?.toUpperCase() ?? 'SLOT',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Right Card Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header Row: Doctor + Status Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (appointment.doctorName ?? '').trim().isNotEmpty
                                      ? appointment.doctorName!.trim()
                                      : 'Doctor not specified',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppleColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  appointment.department ?? 'General Healthcare',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppleColors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Completed vs Incompleted Badge
                          _StatusBadge(completed: completed),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Time & Date pill
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 13, color: AppleColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            appointment.time ?? '10:00 AM',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppleColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? AppleColors.blueLight
                                  : AppleColors.groupedBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isToday ? 'Today' : formatDate(appointment.date),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isToday
                                    ? AppleColors.blue
                                    : AppleColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (appointment.reason != null &&
                          appointment.reason!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          appointment.reason!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppleColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppleColors.greenLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 12, color: AppleColors.green),
            SizedBox(width: 4),
            Text(
              'Completed',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppleColors.green,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppleColors.blueLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top_rounded, size: 12, color: AppleColors.blue),
          SizedBox(width: 4),
          Text(
            'Incompleted',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppleColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final activeBg = accentColor ?? AppleColors.blue;

    return AppleTapBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.hoverIn,
        curve: Motion.ease,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeBg : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? activeBg : AppleColors.border,
            width: 0.8,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeBg.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : AppleColors.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : AppleColors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : AppleColors.textPrimary,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenSlipModal extends StatelessWidget {
  const _TokenSlipModal({
    required this.appointment,
    required this.clinicName,
    required this.isToday,
  });

  final AppointmentEntry appointment;
  final String clinicName;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final completed = appointment.isCompleted;
    final token = appointment.tokenNumber;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointment Token Slip',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppleColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Present this token number at the reception desk',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppleColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Token Slip Ticket
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppleColors.canvas,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppleColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ASSIGNED TOKEN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: AppleColors.textSecondary,
                            ),
                          ),
                          Text(
                            token != null ? '#$token' : '--',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: completed
                                  ? AppleColors.green
                                  : AppleColors.blue,
                            ),
                          ),
                        ],
                      ),
                      _StatusBadge(completed: completed),
                    ],
                  ),
                  const Divider(height: 24, color: AppleColors.border),
                  _slipDetailRow('Doctor', appointment.doctorName ?? 'Physician'),
                  const SizedBox(height: 8),
                  _slipDetailRow('Department', appointment.department ?? 'General'),
                  const SizedBox(height: 8),
                  _slipDetailRow('Scheduled Time', appointment.time ?? '10:00 AM'),
                  const SizedBox(height: 8),
                  _slipDetailRow('Date', isToday ? 'Today (${formatDate(appointment.date)})' : formatDate(appointment.date)),
                  const SizedBox(height: 8),
                  _slipDetailRow('Clinic', clinicName),
                  if (appointment.reason != null &&
                      appointment.reason!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _slipDetailRow('Visit Reason', appointment.reason!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppleColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slipDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppleColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppleColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TokensEmptyState extends StatelessWidget {
  const _TokensEmptyState({
    required this.dateScope,
    required this.onResetFilters,
    required this.onBookAppointment,
  });

  final _AppointmentDateScope dateScope;
  final VoidCallback onResetFilters;
  final VoidCallback onBookAppointment;

  @override
  Widget build(BuildContext context) {
    final title = dateScope == _AppointmentDateScope.today
        ? 'No tokens for today'
        : 'No appointments found';
    final desc = dateScope == _AppointmentDateScope.today
        ? 'You have no scheduled tokens or consultation visits for today.'
        : 'No appointments match your active search or status filters.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppleColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppleColors.blueLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 30, color: AppleColors.blue),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppleColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppleColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onResetFilters,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Reset Filters'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onBookAppointment,
                style: FilledButton.styleFrom(
                  backgroundColor: AppleColors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Book Appointment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppointmentsError extends StatelessWidget {
  const _AppointmentsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 44, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppleColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppleColors.blue),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
