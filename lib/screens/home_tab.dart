import 'package:flutter/material.dart';

import '../models/patient_session.dart';
import '../services/patient_portal_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_animations.dart';
import '../widgets/apple_ui.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/details_sheet.dart';
import '../widgets/patient_avatar_view.dart';
import 'book_appointment_page.dart';
import 'doctors_sheet.dart';

/// Dashboard-style home tab for the patient portal.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.session,
    required this.onOpenTab,
    this.service,
  });

  final PatientSession session;

  /// Switches the outer navigation: 0 home, 1 records, 2 billing, 3 profile.
  final ValueChanged<int> onOpenTab;

  /// Optional injected service (used by tests). When omitted the tab creates
  /// its own client for [session].
  final PatientPortalService? service;

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _bookButtonIn = CurvedAnimation(
    parent: _reveal,
    curve: const Interval(0.5, 1, curve: Motion.easeEnter),
  );

  late final PatientPortalService _service;
  late final bool _ownsService;
  late final Animation<double> _statCount = CurvedAnimation(
    parent: _reveal,
    curve: const Interval(0.15, 1, curve: Motion.ease),
  );

  PortalDashboardData? _data;
  List<DoctorEntry> _doctors = const <DoctorEntry>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PatientPortalService(session: widget.session);
    _ownsService = widget.service == null;
    _load();
  }

  @override
  void dispose() {
    _reveal.dispose();
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  Future<void> refresh() => _load(showSpinner: false);

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && _data == null) {
      setState(() => _loading = true);
    }
    try {
      final dashboard = await _service.fetchDashboard();
      List<DoctorEntry> doctors = const [];
      try {
        doctors = await _service.fetchDoctors(activeOnly: true);
      } catch (_) {
        // Doctors are supplementary; keep the dashboard usable if that
        // secondary endpoint is unavailable.
      }
      if (!mounted) return;
      setState(() {
        _data = dashboard;
        _doctors = doctors;
        _error = null;
        _loading = false;
      });
      if (reduceMotionOf(context)) {
        _reveal.value = 1;
      } else {
        _reveal.forward();
      }
    } on PortalException catch (error) {
      if (!mounted) return;
      if (_data == null) {
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
      const message = 'Could not load your dashboard. Please try again.';
      if (_data == null) {
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const SkeletonLoader();
    }
    if (_error != null && _data == null) {
      return _DashboardError(message: _error!, onRetry: () => _load());
    }

    final data = _data;
    if (data == null) {
      return _DashboardError(
        message: 'Could not load your dashboard. Please try again.',
        onRetry: () => _load(),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: refresh,
          color: AppleColors.blue,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
            children: _staggered([
              _WelcomeCard(
                firstName: firstNameOf(data.patient.fullName),
                clinicName: widget.session.clinicName ?? '',
                patientId: data.patient.patientId,
                fullName: data.patient.fullName,
                onTapAvatar: () => showAvatarPickerSheet(
                  context: context,
                  patientId: data.patient.patientId,
                  fullName: data.patient.fullName,
                ),
              ),
              const SizedBox(height: 16),
              // PRIMARY HERO ACTION: BOOK APPOINTMENT
              _BookAppointmentHeroBanner(
                onBookAppointment: _openBookAppointment,
                onOpenDoctors: _openDoctorsSheet,
              ),
              const SizedBox(height: 20),
              // CARE STATS GRID
              _StatsGrid(
                data: data,
                countProgress: _statCount,
                onOpenAppointments: _showAppointmentsSheet,
                onOpenPrescriptions: _showPrescriptionsSheet,
                onOpenTab: widget.onOpenTab,
              ),
              const SizedBox(height: 22),
              // NEXT APPOINTMENT
              _SectionHeader(
                title: 'Next appointment',
                actionLabel: 'Book Visit',
                onAction: _openBookAppointment,
              ),
              const SizedBox(height: 10),
              if (data.upcomingAppointments.isNotEmpty)
                _NextAppointmentCard(
                  appointment: data.upcomingAppointments.first,
                  onTap: () => _showAppointmentDetails(
                    data.upcomingAppointments.first,
                  ),
                  onBookAnother: _openBookAppointment,
                )
              else
                _SoftEmptyCard(
                  icon: Icons.event_available_rounded,
                  title: 'No upcoming appointments',
                  message:
                      'Schedule a consultation with our verified clinic doctors at your convenient time.',
                  actionLabel: 'Book Appointment',
                  onAction: _openBookAppointment,
                ),
              if (data.outstandingTotal > 0) ...[
                const SizedBox(height: 14),
                _OutstandingBanner(
                  amount: data.outstandingTotal,
                  billCount: data.unpaidBillCount,
                  onViewBills: () => widget.onOpenTab(3),
                ),
              ],
              if (_doctors.isNotEmpty) ...[
                const SizedBox(height: 22),
                _DoctorsCarousel(
                  doctors: _doctors,
                  onOpenDoctors: _openDoctorsSheet,
                  onSelectDoctor: (doc) => _openBookAppointment(doc),
                ),
              ],
              const SizedBox(height: 22),
              const _SectionHeader(title: 'Quick access'),
              const SizedBox(height: 10),
              _QuickActions(
                onOpenTab: widget.onOpenTab,
                onOpenPrescriptions: _showPrescriptionsSheet,
                onOpenAppointments: _showAppointmentsSheet,
                onBookAppointment: _openBookAppointment,
                onOpenDoctors: _openDoctorsSheet,
              ),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Recent activity',
                actionLabel: 'Records',
                onAction: () => widget.onOpenTab(2),
              ),
              const SizedBox(height: 10),
              _RecentActivity(
                data: data,
                onOpenRecords: () => widget.onOpenTab(2),
                onOpenBilling: () => widget.onOpenTab(3),
                onOpenAppointment: _showAppointmentDetails,
                onOpenPrescription: _showPrescriptionDetails,
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Pull down to refresh',
                  style: TextStyle(fontSize: 12, color: AppleColors.textTertiary),
                ),
              ),
            ]),
          ),
        ),
        // Floating Action Button for instant appointment booking
        Positioned(
          right: 16,
          bottom: 18,
          child: FadeTransition(
            opacity: _bookButtonIn,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(_bookButtonIn),
              child: _FloatingBookButton(onTap: _openBookAppointment),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _staggered(List<Widget> sections) {
    var index = 0;
    return [
      for (final section in sections)
        if (section is SizedBox)
          section
        else
          StaggeredReveal(
            animation: _reveal,
            index: index++,
            child: section,
          ),
    ];
  }

  void _openBookAppointment([DoctorEntry? doctor]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookAppointmentPage(
          session: widget.session,
          preselectedDoctor: doctor,
          onAppointmentBooked: _load,
        ),
      ),
    );
  }

  void _openDoctorsSheet() {
    showDoctorsSheet(
      context: context,
      session: widget.session,
      onAppointmentBooked: _load,
    );
  }

  void _showAppointmentsSheet() {
    final appointments = _data?.appointments ?? const <AppointmentEntry>[];
    showDetailsSheet(
      context: context,
      title: 'Appointments',
      subtitle: '${appointments.length} visit${appointments.length == 1 ? '' : 's'} on record',
      icon: Icons.calendar_month_outlined,
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            _openBookAppointment();
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppleColors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text(
            'Book New Appointment',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      children: appointments.isEmpty
          ? [
              const _SheetEmpty(
                icon: Icons.event_busy_outlined,
                message: 'No appointments found.',
              ),
            ]
          : [
              for (var i = 0; i < appointments.length; i++) ...[
                _AppointmentListTile(
                  appointment: appointments[i],
                  onTap: () => _openFromSheet(
                    () => _showAppointmentDetails(appointments[i]),
                  ),
                ),
                if (i != appointments.length - 1)
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
              ],
            ],
    );
  }

  void _showAppointmentDetails(AppointmentEntry appointment) {
    showDetailsSheet(
      context: context,
      title: appointment.reason?.trim().isNotEmpty == true
          ? appointment.reason!.trim()
          : 'Appointment',
      subtitle:
          '${formatDate(appointment.date)} · ${formatTime(appointment.time)}',
      icon: Icons.calendar_month_outlined,
      accent: const Color(0xFF2563EB),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: formatStatus(appointment.status),
              color: appointment.isUpcoming
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B),
              background: appointment.isUpcoming
                  ? const Color(0xFFDBEAFE)
                  : const Color(0xFFF1F5F9),
            ),
            if (appointment.tokenNumber != null)
              StatusPill(
                label: 'Token #${appointment.tokenNumber}',
                color: const Color(0xFF0F766E),
                background: const Color(0xFFCCFBF1),
              ),
            if (appointment.priority)
              const StatusPill(
                label: 'Priority',
                color: Color(0xFFB45309),
                background: Color(0xFFFEF3C7),
              ),
          ],
        ),
        const SizedBox(height: 14),
        DetailSection(
          title: 'Visit details',
          icon: Icons.medical_information_outlined,
          children: [
            DetailField(
              label: 'Doctor',
              value: appointment.doctorName ?? '—',
              icon: Icons.person_outline,
            ),
            DetailField(
              label: 'Date',
              value: formatDate(appointment.date),
              icon: Icons.event_outlined,
            ),
            DetailField(
              label: 'Time',
              value: formatTime(appointment.time),
              icon: Icons.schedule_outlined,
            ),
            if ((appointment.session ?? '').trim().isNotEmpty)
              DetailField(
                label: 'Session',
                value: formatStatus(appointment.session),
                icon: Icons.wb_sunny_outlined,
              ),
            if ((appointment.queueStatus ?? '').trim().isNotEmpty)
              DetailField(
                label: 'Queue status',
                value: formatStatus(appointment.queueStatus),
                icon: Icons.groups_outlined,
              ),
            if ((appointment.reason ?? '').trim().isNotEmpty)
              DetailField(
                label: 'Reason',
                value: appointment.reason!,
                icon: Icons.notes_outlined,
              ),
            if ((appointment.notes ?? '').trim().isNotEmpty)
              DetailField(
                label: 'Notes',
                value: appointment.notes!,
                icon: Icons.description_outlined,
              ),
          ],
        ),
      ],
    );
  }

  void _showPrescriptionsSheet() {
    final prescriptions =
        _data?.prescriptions ?? const <PrescriptionEntry>[];
    showDetailsSheet(
      context: context,
      title: 'Prescriptions',
      subtitle:
          '${prescriptions.length} prescription${prescriptions.length == 1 ? '' : 's'} on record',
      icon: Icons.medication_outlined,
      accent: const Color(0xFF0F766E),
      children: prescriptions.isEmpty
          ? [
              const _SheetEmpty(
                icon: Icons.medication_liquid_outlined,
                message: 'No prescriptions found.',
              ),
            ]
          : [
              for (var i = 0; i < prescriptions.length; i++) ...[
                _PrescriptionListTile(
                  prescription: prescriptions[i],
                  onTap: () => _openFromSheet(
                    () => _showPrescriptionDetails(prescriptions[i]),
                  ),
                ),
                if (i != prescriptions.length - 1)
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),
              ],
            ],
    );
  }

  void _showPrescriptionDetails(PrescriptionEntry prescription) {
    showDetailsSheet(
      context: context,
      title: (prescription.diagnosis ?? '').trim().isNotEmpty
          ? prescription.diagnosis!.trim()
          : 'Prescription',
      subtitle: formatDate(
        prescription.visitDate ?? prescription.createdAt,
      ),
      icon: Icons.medication_outlined,
      accent: const Color(0xFF0F766E),
      children: [
        DetailSection(
          title: 'Visit details',
          icon: Icons.medical_information_outlined,
          accent: const Color(0xFF0F766E),
          children: [
            DetailField(
              label: 'Doctor',
              value: prescription.doctorName ?? '—',
              icon: Icons.person_outline,
            ),
            DetailField(
              label: 'Visit date',
              value: formatDate(
                prescription.visitDate ?? prescription.createdAt,
              ),
              icon: Icons.event_outlined,
            ),
            if ((prescription.diagnosis ?? '').trim().isNotEmpty)
              DetailField(
                label: 'Diagnosis',
                value: prescription.diagnosis!,
                icon: Icons.healing_outlined,
              ),
          ],
        ),
        if (prescription.medicines.isNotEmpty) ...[
          const DetailSectionTitle(
            title: 'Medicines',
            icon: Icons.medication_liquid_outlined,
            accent: Color(0xFF0F766E),
          ),
          for (final medicine in prescription.medicines) ...[
            _MedicineCard(medicine: medicine),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
        ],
        if ((prescription.notes ?? '').trim().isNotEmpty)
          DetailSection(
            title: 'Notes',
            icon: Icons.notes_outlined,
            accent: const Color(0xFF0F766E),
            children: [
              DetailField(label: 'Notes', value: prescription.notes!),
            ],
          ),
      ],
    );
  }

  void _openFromSheet(VoidCallback openDetails) {
    Navigator.of(context).pop();
    Future<void>.delayed(
      const Duration(milliseconds: 240),
      () {
        if (mounted) openDetails();
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.firstName,
    required this.clinicName,
    this.patientId = '',
    this.fullName = '',
    this.onTapAvatar,
  });

  final String firstName;
  final String clinicName;
  final String patientId;
  final String fullName;
  final VoidCallback? onTapAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppleColors.border, width: 0.8),
        boxShadow: AppleColors.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppleColors.blueLight.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppleColors.blueLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.health_and_safety_rounded,
                                size: 13,
                                color: AppleColors.blue,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'PATIENT PORTAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: AppleColors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppleColors.greenLight,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 11,
                                color: AppleColors.green,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppleColors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome, $firstName 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppleColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Here’s an overview of your health information and care schedule.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppleColors.textSecondary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppleColors.groupedBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_hospital_rounded,
                            size: 15,
                            color: AppleColors.blue,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              clinicName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppleColors.textPrimary,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              PatientAvatarView(
                patientId: patientId.isNotEmpty
                    ? patientId
                    : (fullName.isNotEmpty ? fullName : firstName),
                fullName: fullName.isNotEmpty ? fullName : firstName,
                size: 64,
                showEditBadge: true,
                onTap: onTapAvatar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookAppointmentHeroBanner extends StatelessWidget {
  const _BookAppointmentHeroBanner({
    required this.onBookAppointment,
    required this.onOpenDoctors,
  });

  final VoidCallback onBookAppointment;
  final VoidCallback onOpenDoctors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppleColors.blue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppleColors.elevatedShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              'ONLINE APPOINTMENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF34C759).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Doctors Only',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Book Doctor Appointment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Schedule a consultation with our verified clinic specialists at your convenient date & time.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppleTapBounce(
                          onTap: onBookAppointment,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_rounded, size: 18, color: Color(0xFF0071E3)),
                                SizedBox(width: 8),
                                Text(
                                  'Book Appointment',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0071E3),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppleTapBounce(
                        onTap: onOpenDoctors,
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.medical_services_outlined, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Doctors',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_hospital_outlined, size: 13, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            'Clinic Doctors',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 3),
                          Text(
                            'Instant Token',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _wholeNumber(double value) => '${value.round()}';

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.data,
    required this.countProgress,
    required this.onOpenAppointments,
    required this.onOpenPrescriptions,
    required this.onOpenTab,
  });

  final PortalDashboardData data;
  final Animation<double> countProgress;
  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenPrescriptions;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _StatCard(
                icon: Icons.calendar_month_rounded,
                iconColor: AppleColors.blue,
                iconBackground: AppleColors.blueLight,
                countProgress: countProgress,
                countTo: data.upcomingAppointments.length.toDouble(),
                format: _wholeNumber,
                label: 'Appointments',
                subLabel: 'Upcoming visits',
                onTap: () => onOpenTab(1),
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                icon: Icons.folder_shared_rounded,
                iconColor: AppleColors.purple,
                iconBackground: AppleColors.purpleLight,
                countProgress: countProgress,
                countTo: data.documentsCount.toDouble(),
                format: _wholeNumber,
                label: 'Medical Records',
                subLabel: 'Health documents',
                onTap: () => onOpenTab(2),
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                icon: Icons.medication_rounded,
                iconColor: AppleColors.teal,
                iconBackground: AppleColors.tealLight,
                countProgress: countProgress,
                countTo: data.prescriptions.length.toDouble(),
                format: _wholeNumber,
                label: 'Prescriptions',
                subLabel: 'Active medications',
                onTap: onOpenPrescriptions,
              ),
            ),
            SizedBox(
              width: width,
              child: _StatCard(
                icon: Icons.credit_card_rounded,
                iconColor: data.outstandingTotal > 0
                    ? AppleColors.orange
                    : AppleColors.green,
                iconBackground: data.outstandingTotal > 0
                    ? AppleColors.orangeLight
                    : AppleColors.greenLight,
                countProgress: countProgress,
                countTo: data.outstandingTotal,
                format: formatMoney,
                label: 'Bills & Invoices',
                subLabel: data.outstandingTotal > 0
                    ? 'Outstanding'
                    : 'Settled',
                onTap: () => onOpenTab(3),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.countProgress,
    required this.countTo,
    required this.format,
    required this.label,
    required this.subLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Animation<double> countProgress;
  final double countTo;
  final String Function(double) format;
  final String label;
  final String subLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppleTapBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppleColors.border, width: 0.8),
          boxShadow: AppleColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 16,
                  color: AppleColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 26,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: countProgress,
                  builder: (context, _) => Text(
                    format(countTo * countProgress.value),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: AppleColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppleColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              subLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppleColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppleColors.textPrimary,
            ),
          ),
        ),
        if (onAction != null && actionLabel != null)
          AppleTapBounce(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppleColors.blue,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.appointment,
    required this.onTap,
    this.onBookAnother,
  });

  final AppointmentEntry appointment;
  final VoidCallback onTap;
  final VoidCallback? onBookAnother;

  @override
  Widget build(BuildContext context) {
    final date = parseApiDate(appointment.date)?.toLocal();

    return AppleTapBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppleColors.border, width: 0.8),
          boxShadow: AppleColors.cardShadow,
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: AppleColors.blueLight,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppleColors.blue.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        date == null ? '—' : '${date.day}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppleColors.blue,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date == null
                            ? 'DATE'
                            : (formatShortDate(date).split(' ').isNotEmpty
                                ? formatShortDate(date).split(' ').last.toUpperCase()
                                : 'DATE'),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppleColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${formatTime(appointment.time)} · ${appointment.doctorName ?? '—'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppleColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppleColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (appointment.reason ?? '').trim().isNotEmpty
                            ? appointment.reason!.trim()
                            : 'Scheduled visit',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppleColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusPill(
                            label: formatStatus(appointment.status),
                            color: AppleColors.blue,
                            background: AppleColors.blueLight,
                          ),
                          if (appointment.tokenNumber != null)
                            StatusPill(
                              label: 'Token #${appointment.tokenNumber}',
                              color: AppleColors.teal,
                              background: AppleColors.tealLight,
                            ),
                          if (appointment.visitType.trim().isNotEmpty)
                            StatusPill(
                              label: appointment.visitType.trim(),
                              color: AppleColors.purple,
                              background: AppleColors.purpleLight,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onBookAnother != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppleColors.hairline),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppleTapBounce(
                      onTap: onTap,
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppleColors.groupedBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppleColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppleTapBounce(
                      onTap: onBookAnother,
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppleColors.blueLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 16, color: AppleColors.blue),
                            SizedBox(width: 4),
                            Text(
                              'Book Another',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppleColors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoctorsCarousel extends StatelessWidget {
  const _DoctorsCarousel({
    required this.doctors,
    required this.onOpenDoctors,
    required this.onSelectDoctor,
  });

  final List<DoctorEntry> doctors;
  final VoidCallback onOpenDoctors;
  final ValueChanged<DoctorEntry> onSelectDoctor;

  @override
  Widget build(BuildContext context) {
    if (doctors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Our Doctors',
          actionLabel: 'See All (${doctors.length})',
          onAction: onOpenDoctors,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: doctors.length,
            separatorBuilder: (_, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final doc = doctors[index];
              return _DoctorMiniCard(
                doctor: doc,
                onTap: () => onSelectDoctor(doc),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DoctorMiniCard extends StatelessWidget {
  const _DoctorMiniCard({
    required this.doctor,
    required this.onTap,
  });

  final DoctorEntry doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppleTapBounce(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppleColors.border, width: 0.8),
          boxShadow: AppleColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppleColors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initialsOf(doctor.name),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppleColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        doctor.specialization,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppleColors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (doctor.hasExperience || doctor.hasFee)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (doctor.hasFee)
                    Text(
                      formatMoney(doctor.fee),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppleColors.textPrimary,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (doctor.hasExperience)
                    Flexible(
                      child: Text(
                        '${doctor.experienceYears}y exp',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppleColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            Container(
              height: 28,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppleColors.blueLight,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 12, color: AppleColors.blue),
                  SizedBox(width: 4),
                  Text(
                    'Book Visit',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppleColors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingBookButton extends StatelessWidget {
  const _FloatingBookButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppleTapBounce(
      onTap: onTap,
      child: Tooltip(
        message: 'Book Appointment',
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppleColors.blue,
            boxShadow: AppleColors.elevatedShadow,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.calendar_month_rounded,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _OutstandingBanner extends StatelessWidget {
  const _OutstandingBanner({
    required this.amount,
    required this.billCount,
    required this.onViewBills,
  });

  final double amount;
  final int billCount;
  final VoidCallback onViewBills;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppleColors.orangeLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppleColors.orange.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppleColors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              billCount > 0
                  ? '${formatMoney(amount)} outstanding across $billCount bill${billCount == 1 ? '' : 's'}.'
                  : '${formatMoney(amount)} outstanding.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppleColors.textPrimary,
              ),
            ),
          ),
          AppleTapBounce(
            onTap: onViewBills,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppleColors.orange.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: const Text(
                'View bills',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppleColors.orange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOpenTab,
    required this.onOpenPrescriptions,
    required this.onOpenAppointments,
    required this.onBookAppointment,
    required this.onOpenDoctors,
  });

  final ValueChanged<int> onOpenTab;
  final VoidCallback onOpenPrescriptions;
  final VoidCallback onOpenAppointments;
  final VoidCallback onBookAppointment;
  final VoidCallback onOpenDoctors;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.calendar_today_rounded,
                title: 'Book Visit',
                description: 'Schedule with doctor',
                color: AppleColors.blue,
                background: AppleColors.blueLight,
                onTap: onBookAppointment,
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.medical_services_outlined,
                title: 'Our Doctors',
                description: 'Specialists directory',
                color: AppleColors.teal,
                background: AppleColors.tealLight,
                onTap: onOpenDoctors,
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.calendar_month_rounded,
                title: 'Appointments',
                description: 'View & schedule visits',
                color: AppleColors.purple,
                background: AppleColors.purpleLight,
                onTap: onOpenAppointments,
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.medication_rounded,
                title: 'Prescriptions',
                description: 'Medications & doses',
                color: AppleColors.pink,
                background: AppleColors.pinkLight,
                onTap: onOpenPrescriptions,
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.folder_shared_rounded,
                title: 'Medical Records',
                description: 'Reports & lab history',
                color: const Color(0xFF6366F1),
                background: const Color(0xFFEEF2FF),
                onTap: () => onOpenTab(2),
              ),
            ),
            SizedBox(
              width: width,
              child: _QuickActionCard(
                icon: Icons.credit_card_rounded,
                title: 'Bills & Invoices',
                description: 'Invoices & payments',
                color: AppleColors.green,
                background: AppleColors.greenLight,
                onTap: () => onOpenTab(3),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppleTapBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppleColors.border, width: 0.8),
          boxShadow: AppleColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppleColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppleColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppleColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.data,
    required this.onOpenRecords,
    required this.onOpenBilling,
    required this.onOpenAppointment,
    required this.onOpenPrescription,
  });

  final PortalDashboardData data;
  final VoidCallback onOpenRecords;
  final VoidCallback onOpenBilling;
  final ValueChanged<AppointmentEntry> onOpenAppointment;
  final ValueChanged<PrescriptionEntry> onOpenPrescription;

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    if (items.isEmpty) {
      return const _SoftEmptyCard(
        icon: Icons.history_rounded,
        title: 'No recent activity',
        message:
            'Your appointments, reports, prescriptions and bills will appear here.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppleColors.border, width: 0.8),
        boxShadow: AppleColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _ActivityRow(item: items[i]),
            if (i != items.length - 1)
              const Divider(
                height: 1,
                indent: 56,
                color: AppleColors.hairline,
              ),
          ],
        ],
      ),
    );
  }

  List<_ActivityItem> _buildItems() {
    final items = <_ActivityItem>[];

    for (final appointment in data.appointments.take(4)) {
      items.add(
        _ActivityItem(
          title: 'Appointment ${formatStatus(appointment.status)}',
          subtitle: () {
            final doctor = (appointment.doctorName ?? '').trim();
            final reason = (appointment.reason ?? '').trim();
            if (doctor.isNotEmpty && reason.isNotEmpty) {
              return 'Dr. $doctor · $reason';
            }
            if (doctor.isNotEmpty) return 'Dr. $doctor';
            if (reason.isNotEmpty) return reason;
            return 'Clinic visit';
          }(),
          date: formatDate(appointment.date, fallback: ''),
          sortDate: appointment.scheduledAt ?? parseApiDate(appointment.date),
          icon: Icons.calendar_month_rounded,
          color: AppleColors.blue,
          background: AppleColors.blueLight,
          onTap: () => onOpenAppointment(appointment),
        ),
      );
    }

    for (final file in data.files.take(4)) {
      items.add(
        _ActivityItem(
          title: 'Document uploaded',
          subtitle: file.fileName,
          date: formatDate(file.createdAt, fallback: ''),
          sortDate: file.createdAt,
          icon: Icons.description_rounded,
          color: AppleColors.purple,
          background: AppleColors.purpleLight,
          onTap: onOpenRecords,
        ),
      );
    }

    for (final prescription in data.prescriptions.take(4)) {
      items.add(
        _ActivityItem(
          title: 'Prescription issued',
          subtitle: () {
            final doctor = (prescription.doctorName ?? '').trim();
            final diagnosis = (prescription.diagnosis ?? '').trim();
            if (doctor.isNotEmpty && diagnosis.isNotEmpty) {
              return 'Dr. $doctor · $diagnosis';
            }
            if (doctor.isNotEmpty) return 'Dr. $doctor';
            if (diagnosis.isNotEmpty) return diagnosis;
            return 'Prescription';
          }(),
          date: formatDate(
            prescription.visitDate ?? prescription.createdAt,
            fallback: '',
          ),
          sortDate: parseApiDate(
            prescription.visitDate ?? prescription.createdAt,
          ),
          icon: Icons.medication_rounded,
          color: AppleColors.teal,
          background: AppleColors.tealLight,
          onTap: () => onOpenPrescription(prescription),
        ),
      );
    }

    for (final bill in data.bills.take(4)) {
      items.add(
        _ActivityItem(
          title: 'Bill ${bill.billNumber}',
          subtitle: '${formatMoney(bill.total)} · ${bill.displayStatus}',
          date: formatDate(bill.invoiceDate, fallback: ''),
          sortDate: bill.invoiceDate ?? bill.createdAt,
          icon: Icons.receipt_long_rounded,
          color: AppleColors.orange,
          background: AppleColors.orangeLight,
          onTap: onOpenBilling,
        ),
      );
    }

    items.sort((a, b) {
      final da = a.sortDate;
      final db = b.sortDate;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return items.take(6).toList();
  }
}

class _ActivityItem {
  _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
    this.sortDate,
  });

  final String title;
  final String subtitle;
  final String date;
  final DateTime? sortDate;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    return AppleTapBounce(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 19, color: item.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppleColors.textPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppleColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (item.date.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                item.date,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppleColors.textTertiary,
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppleColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftEmptyCard extends StatelessWidget {
  const _SoftEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppleColors.border, width: 0.8),
        boxShadow: AppleColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppleColors.blueLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 22, color: AppleColors.blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppleColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppleColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            AppleTapBounce(
              onTap: onAction,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppleColors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppointmentListTile extends StatelessWidget {
  const _AppointmentListTile({
    required this.appointment,
    required this.onTap,
  });

  final AppointmentEntry appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 42,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    formatShortDate(appointment.date).split(' ').first,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                      height: 1.05,
                    ),
                  ),
                  Text(
                    formatShortDate(appointment.date).split(' ').last
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatTime(appointment.time)} · ${appointment.doctorName ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (appointment.reason ?? '').trim().isNotEmpty
                        ? appointment.reason!.trim()
                        : 'Scheduled visit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(
              label: formatStatus(appointment.status),
              color: appointment.isActive
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B),
              background: appointment.isActive
                  ? const Color(0xFFDBEAFE)
                  : const Color(0xFFF1F5F9),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionListTile extends StatelessWidget {
  const _PrescriptionListTile({
    required this.prescription,
    required this.onTap,
  });

  final PrescriptionEntry prescription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final medicineCount = prescription.medicines.length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFCCFBF1),
              child: Icon(
                Icons.medication_outlined,
                size: 17,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (prescription.diagnosis ?? '').trim().isNotEmpty
                        ? prescription.diagnosis!.trim()
                        : 'Prescription',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${prescription.doctorName ?? 'Doctor'} · '
                    '$medicineCount medicine${medicineCount == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatDate(prescription.visitDate ?? prescription.createdAt),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine});

  final MedicineEntry medicine;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if ((medicine.dosage ?? '').trim().isNotEmpty) medicine.dosage!.trim(),
      if ((medicine.frequency ?? '').trim().isNotEmpty)
        medicine.frequency!.trim(),
      if ((medicine.duration ?? '').trim().isNotEmpty)
        medicine.duration!.trim(),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medication_liquid_outlined,
                size: 16,
                color: Color(0xFF0F766E),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  medicine.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              details.join(' · '),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ],
          if ((medicine.instructions ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              medicine.instructions!.trim(),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetEmpty extends StatelessWidget {
  const _SheetEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        const Icon(
          Icons.cloud_off_outlined,
          size: 52,
          color: Color(0xFF94A3B8),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
