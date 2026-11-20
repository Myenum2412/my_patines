import 'package:flutter/material.dart';

import '../models/patient_session.dart';
import '../services/patient_portal_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_animations.dart';
import '../widgets/apple_ui.dart';

/// Apple-styled appointment booking form where patients choose from verified
/// clinic doctors only, pick an available slot, and submit their appointment.
class BookAppointmentPage extends StatefulWidget {
  const BookAppointmentPage({
    super.key,
    required this.session,
    this.preselectedDoctor,
    this.onAppointmentBooked,
    this.service,
  });

  final PatientSession session;
  final DoctorEntry? preselectedDoctor;
  final VoidCallback? onAppointmentBooked;
  final PatientPortalService? service;

  @override
  State<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends State<BookAppointmentPage> {
  late final PatientPortalService _service;
  late final bool _ownsService;

  List<DoctorEntry> _doctors = [];
  bool _loadingDoctors = true;
  DoctorEntry? _selectedDoctor;
  String _doctorSearchQuery = '';

  String _visitType = 'New Visit';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _selectedTime = '10:30';
  final _reasonController = TextEditingController();
  final _symptomsController = TextEditingController();
  String _priority = 'Normal';
  bool _whatsappAlert = true;
  bool _doctorNotification = true;

  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _morningSlots = const [
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '12:00',
  ];

  final List<String> _eveningSlots = const [
    '16:00',
    '16:30',
    '17:00',
    '17:30',
    '18:00',
    '18:30',
  ];

  final List<String> _visitTypes = const [
    'New Visit',
    'Follow-up',
    'Routine Checkup',
    'Consultation',
    'Emergency',
  ];

  final List<String> _priorities = const [
    'Normal',
    'High',
    'Urgent',
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PatientPortalService(session: widget.session);
    _ownsService = widget.service == null;
    _selectedDoctor = widget.preselectedDoctor;
    _loadDoctors();
  }

  @override
  void dispose() {
    if (_ownsService) _service.dispose();
    _reasonController.dispose();
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _loadingDoctors = true);
    try {
      final docs = await _service.fetchDoctors(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _doctors = docs;
        _loadingDoctors = false;
        if (_selectedDoctor == null && docs.isNotEmpty) {
          _selectedDoctor = docs.first;
        } else if (_selectedDoctor != null) {
          final found = docs.where((d) => d.doctorId == _selectedDoctor!.doctorId);
          if (found.isNotEmpty) _selectedDoctor = found.first;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDoctors = false);
    }
  }

  List<DoctorEntry> get _filteredDoctors {
    final q = _doctorSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return _doctors;
    return _doctors.where((d) {
      final nameMatches = d.name.toLowerCase().contains(q);
      final specMatches = d.specialization.toLowerCase().contains(q);
      final deptMatches = (d.department ?? '').toLowerCase().contains(q);
      return nameMatches || specMatches || deptMatches;
    }).toList();
  }

  Future<void> _submitBooking() async {
    setState(() => _errorMessage = null);

    if (_selectedDoctor == null) {
      setState(() => _errorMessage = 'Please select a doctor for your consultation.');
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'Please enter the primary reason for your visit.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dateStr =
          '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final input = AppointmentBookingInput(
        doctorId: _selectedDoctor!.doctorId,
        doctorName: _selectedDoctor!.displayName,
        date: dateStr,
        time: _selectedTime,
        department: _selectedDoctor!.department,
        visitType: _visitType,
        duration: 30,
        reason: reason,
        priority: _priority,
        symptoms: _symptomsController.text.trim().isEmpty ? null : _symptomsController.text.trim(),
        whatsappAlert: _whatsappAlert,
        doctorNotification: _doctorNotification,
        consultationFee: _selectedDoctor!.fee,
      );

      final booked = await _service.bookAppointment(input);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      widget.onAppointmentBooked?.call();

      _showSuccessDialog(booked);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not book appointment: $err';
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog(AppointmentEntry appointment) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppleColors.elevatedShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SuccessCheck(size: 76),
                const SizedBox(height: 18),
                const Text(
                  'Appointment Booked!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppleColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your consultation with ${_selectedDoctor?.displayName ?? "the doctor"} has been scheduled.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppleColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppleColors.groupedBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppleColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildSuccessRow(
                        'Token Number:',
                        appointment.tokenNumber != null
                            ? '#${appointment.tokenNumber}'
                            : 'Assigned by clinic',
                      ),
                      const Divider(height: 14, color: AppleColors.border),
                      _buildSuccessRow(
                        'Date & Time:',
                        '${formatDate(appointment.date)} · ${formatTime(appointment.time)}',
                      ),
                      const Divider(height: 14, color: AppleColors.border),
                      _buildSuccessRow(
                        'Doctor:',
                        (appointment.doctorName ?? '').trim().isNotEmpty
                            ? appointment.doctorName!
                            : _selectedDoctor?.displayName ?? 'Assigned doctor',
                      ),
                      const Divider(height: 14, color: AppleColors.border),
                      _buildSuccessRow('Visit Type:', appointment.visitType),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: AppleButton(
                    label: 'Done',
                    onPressed: () {
                      Navigator.of(ctx).pop(); // pop dialog
                      Navigator.of(context).pop(); // pop booking page
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppleColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppleColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppleColors.canvas,
      appBar: AppBar(
        backgroundColor: AppleColors.canvas,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: AppleColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Book Appointment',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppleColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              (widget.session.clinicName ?? '').trim().isNotEmpty
                  ? widget.session.clinicName!.trim()
                  : 'Healthcare Clinic',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppleColors.textSecondary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPatientHeaderCard(),
              const SizedBox(height: 18),

              // SECTION 1: CHOOSE DOCTOR (DOCTORS ONLY)
              _buildSectionTitle('1. Choose Doctor', 'Only verified clinic doctors are listed'),
              const SizedBox(height: 10),
              _buildDoctorSelector(),
              const SizedBox(height: 20),

              // SECTION 2: VISIT TYPE & DATE/TIME
              _buildSectionTitle('2. Schedule & Slot', 'Select visit type, date, and preferred slot'),
              const SizedBox(height: 10),
              _buildVisitTypePicker(),
              const SizedBox(height: 14),
              _buildDatePicker(),
              const SizedBox(height: 14),
              _buildTimeSlotPicker(),
              const SizedBox(height: 20),

              // SECTION 3: REASON FOR VISIT & SYMPTOMS
              _buildSectionTitle('3. Consultation Details', 'Provide details for the consulting doctor'),
              const SizedBox(height: 10),
              _buildReasonAndSymptomsFields(),
              const SizedBox(height: 20),

              // SECTION 4: NOTIFICATION PREFERENCES
              _buildSectionTitle('4. Preferences', 'Automated reminders and doctor alerts'),
              const SizedBox(height: 10),
              _buildPreferencesCard(),
              const SizedBox(height: 20),

              // SECTION 5: BOOKING SUMMARY
              _buildSummaryCard(),
              const SizedBox(height: 14),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppleColors.redLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppleColors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppleColors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12.5, color: AppleColors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: AppleColors.border, width: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        child: AppleButton(
          label: 'Confirm & Book Appointment',
          icon: Icons.calendar_today_rounded,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting ? null : _submitBooking,
        ),
      ),
    );
  }

  Widget _buildPatientHeaderCard() {
    final patientName = (widget.session.name ?? '').trim().isNotEmpty
        ? widget.session.name!.trim()
        : 'Patient';
    final patientId = (widget.session.patientId ?? '').trim().isNotEmpty
        ? widget.session.patientId!.trim()
        : '—';

    return AppleCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppleColors.blue,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              initialsOf(patientName),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppleColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppleColors.greenLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Booking for You',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Patient ID: $patientId',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppleColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
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
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11.5, color: AppleColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDoctorSelector() {
    if (_loadingDoctors) {
      return Container(
        height: 130,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppleColors.blue),
      );
    }

    final doctors = _filteredDoctors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Doctor Search Input
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppleColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 19, color: AppleColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _doctorSearchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search doctor by name or specialty...',
                    hintStyle: TextStyle(fontSize: 13, color: AppleColors.textTertiary),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13.5, color: AppleColors.textPrimary),
                ),
              ),
              if (_doctorSearchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _doctorSearchQuery = ''),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppleColors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Doctors List
        if (doctors.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppleColors.border),
            ),
            child: const Text(
              'No matching active doctors found.',
              style: TextStyle(fontSize: 13, color: AppleColors.textSecondary),
            ),
          )
        else
          Column(
            children: doctors.map((doc) {
              final isSelected = _selectedDoctor?.doctorId == doc.doctorId;

              final metaParts = <String>[
                if (doc.hasExperience) '${doc.experienceYears} yrs exp',
                if (doc.hasFee) formatMoney(doc.fee),
              ];
              final availability = _doctorAvailabilityLabel(doc);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppleTapBounce(
                  onTap: () => setState(() => _selectedDoctor = doc),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? AppleColors.blue : AppleColors.border,
                        width: isSelected ? 2.0 : 0.8,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppleColors.blue.withValues(alpha: 0.14),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : AppleColors.cardShadow,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? AppleColors.blueLight : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.medical_services_outlined,
                            size: 24,
                            color: isSelected ? AppleColors.blue : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.displayName,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? AppleColors.blue : AppleColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                doc.specialization,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              if (metaParts.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  metaParts.join(' · '),
                                  style: const TextStyle(fontSize: 11, color: AppleColors.textSecondary),
                                ),
                              ],
                              if (availability != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    availability,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppleColors.blue : AppleColors.border,
                              width: isSelected ? 6 : 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildVisitTypePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visit Type',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppleColors.textSecondary),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _visitTypes.map((type) {
              final isSelected = _visitType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppleTapBounce(
                  onTap: () => setState(() => _visitType = type),
                  child: AnimatedContainer(
                    duration: Motion.hoverIn,
                    curve: Motion.ease,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppleColors.textPrimary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppleColors.textPrimary : AppleColors.border,
                      ),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppleColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    final now = DateTime.now();
    final dates = List.generate(14, (i) => now.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Date',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppleColors.textSecondary),
            ),
            Text(
              formatDate(_selectedDate),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppleColors.blue),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: dates.map((d) {
              final isSelected =
                  _selectedDate.year == d.year &&
                  _selectedDate.month == d.month &&
                  _selectedDate.day == d.day;

              final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppleTapBounce(
                  onTap: () => setState(() => _selectedDate = d),
                  child: AnimatedContainer(
                    duration: Motion.hoverIn,
                    curve: Motion.ease,
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppleColors.blue : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppleColors.blue : AppleColors.border,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppleColors.blue.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : AppleColors.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Text(
                          weekday,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white.withValues(alpha: 0.8) : AppleColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppleColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlotPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Time Slot',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppleColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppleColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, size: 16, color: AppleColors.orange),
                  SizedBox(width: 6),
                  Text(
                    'Morning Sessions',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppleColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _morningSlots.map((slot) => _buildSlotChip(slot)).toList(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppleColors.separator),
              ),
              const Row(
                children: [
                  Icon(Icons.nightlight_round_outlined, size: 16, color: AppleColors.purple),
                  SizedBox(width: 6),
                  Text(
                    'Evening Sessions',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppleColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _eveningSlots.map((slot) => _buildSlotChip(slot)).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlotChip(String time) {
    final isSelected = _selectedTime == time;
    final display = formatTime(time);

    return AppleTapBounce(
      onTap: () => setState(() => _selectedTime = time),
      child: AnimatedContainer(
        duration: Motion.hoverIn,
        curve: Motion.ease,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppleColors.blue : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppleColors.blue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          display,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppleColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildReasonAndSymptomsFields() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppleColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reason for Visit *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppleColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              hintText: 'e.g. Regular BP checkup, recurring fever, dental pain',
              hintStyle: const TextStyle(fontSize: 13, color: AppleColors.textTertiary),
              filled: true,
              fillColor: AppleColors.groupedBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(fontSize: 13.5, color: AppleColors.textPrimary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Symptoms & Notes (Optional)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppleColors.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _symptomsController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Describe any symptoms or instructions for the doctor...',
              hintStyle: const TextStyle(fontSize: 13, color: AppleColors.textTertiary),
              filled: true,
              fillColor: AppleColors.groupedBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(fontSize: 13.5, color: AppleColors.textPrimary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Priority',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppleColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            children: _priorities.map((p) {
              final isSelected = _priority == p;
              Color activeColor = AppleColors.blue;
              if (p == 'High') activeColor = AppleColors.orange;
              if (p == 'Urgent') activeColor = AppleColors.red;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppleTapBounce(
                  onTap: () => setState(() => _priority = p),
                  child: AnimatedContainer(
                    duration: Motion.hoverIn,
                    curve: Motion.ease,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor.withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? activeColor : AppleColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppleColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppleColors.greenLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF059669), size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automated WhatsApp Alert',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppleColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Queue booking confirmation & token update to WhatsApp',
                        style: TextStyle(fontSize: 11.5, color: AppleColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: _whatsappAlert,
                  onChanged: (val) => setState(() => _whatsappAlert = val),
                  activeTrackColor: AppleColors.green,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppleColors.separator),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppleColors.blueLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: AppleColors.blue, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctor Instant Notification',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppleColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Alert attending physician portal dashboard immediately',
                        style: TextStyle(fontSize: 11.5, color: AppleColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: _doctorNotification,
                  onChanged: (val) => setState(() => _doctorNotification = val),
                  activeTrackColor: AppleColors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final docName = _selectedDoctor?.displayName ?? 'Not selected';
    final department = _selectedDoctor?.department?.trim().isNotEmpty == true
        ? _selectedDoctor!.department!
        : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_outlined, size: 17, color: Color(0xFF0F172A)),
              SizedBox(width: 8),
              Text(
                'Consultation Overview',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryLine('Doctor:', docName),
          const SizedBox(height: 6),
          _buildSummaryLine('Department:', department),
          const SizedBox(height: 6),
          _buildSummaryLine('Date & Time:', '${formatDate(_selectedDate)} at ${formatTime(_selectedTime)}'),
          const SizedBox(height: 6),
          _buildSummaryLine('Visit Type:', _visitType),
        ],
      ),
    );
  }

  String? _doctorAvailabilityLabel(DoctorEntry doc) {
    final days = doc.availableDays.take(4).join(', ');
    final hours = doc.availableHours.trim();
    if (days.isEmpty && hours.isEmpty) return null;
    if (days.isEmpty) return hours;
    if (hours.isEmpty) return days;
    return 'Available: $days · $hours';
  }

  Widget _buildSummaryLine(String label, String value, {bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppleColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
            color: isHighlighted ? AppleColors.blue : AppleColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
