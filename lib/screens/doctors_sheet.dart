import 'package:flutter/material.dart';

import '../models/patient_session.dart';
import '../services/patient_portal_service.dart';
import '../utils/formatters.dart';
import '../widgets/apple_ui.dart';
import 'book_appointment_page.dart';

/// Bottom sheet displaying the clinic's verified active doctors only.
///
/// Patients can view doctor qualifications, experience, consultation fees,
/// and working hours, then book an appointment directly.
void showDoctorsSheet({
  required BuildContext context,
  required PatientSession session,
  VoidCallback? onAppointmentBooked,
  PatientPortalService? service,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) {
      return _DoctorsSheetContent(
        session: session,
        onAppointmentBooked: onAppointmentBooked,
        service: service,
      );
    },
  );
}

class _DoctorsSheetContent extends StatefulWidget {
  const _DoctorsSheetContent({
    required this.session,
    this.onAppointmentBooked,
    this.service,
  });

  final PatientSession session;
  final VoidCallback? onAppointmentBooked;
  final PatientPortalService? service;

  @override
  State<_DoctorsSheetContent> createState() => _DoctorsSheetContentState();
}

class _DoctorsSheetContentState extends State<_DoctorsSheetContent> {
  late final PatientPortalService _service;
  late final bool _ownsService;
  List<DoctorEntry> _doctors = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PatientPortalService(session: widget.session);
    _ownsService = widget.service == null;
    _load();
  }

  @override
  void dispose() {
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.fetchDoctors(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _doctors = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<DoctorEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _doctors;
    return _doctors.where((d) {
      return d.name.toLowerCase().contains(q) ||
          d.specialization.toLowerCase().contains(q) ||
          (d.department ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppleColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppleColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppleColors.brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: AppleColors.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinic Doctors',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppleColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Verified consulting specialists at ${widget.session.clinicName ?? "Clinic"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppleColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppleColors.border,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF48484A)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppleColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: AppleColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _query = val),
                      decoration: const InputDecoration(
                        hintText: 'Search by doctor name, specialty, department...',
                        hintStyle: TextStyle(fontSize: 12.5, color: AppleColors.textTertiary),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13, color: AppleColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppleColors.border),

          // Doctors List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppleColors.brand))
                : _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No doctors found.',
                          style: TextStyle(fontSize: 13, color: AppleColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final doc = _filtered[index];
                          return _buildDoctorCard(doc);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(DoctorEntry doc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppleColors.border),
          boxShadow: AppleColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppleColors.brand,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initialsOf(doc.name),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
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
                          Expanded(
                            child: Text(
                              doc.displayName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppleColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.specialization,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppleColors.brand,
                        ),
                      ),
                      if (doc.qualification != null && doc.qualification!.isNotEmpty)
                        Text(
                          doc.qualification!,
                          style: const TextStyle(fontSize: 11, color: AppleColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metadata Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (doc.hasExperience)
                  _buildPill(
                    Icons.work_outline_rounded,
                    '${doc.experienceYears} Years Exp',
                    AppleColors.canvas,
                    const Color(0xFF334155),
                  ),
                if (doc.hasFee)
                  _buildPill(
                    Icons.payments_outlined,
                    formatMoney(doc.fee),
                    const Color(0xFFECFDF5),
                    const Color(0xFF047857),
                  ),
                if (doc.department != null && doc.department!.isNotEmpty)
                  _buildPill(
                    Icons.domain_rounded,
                    doc.department!,
                    AppleColors.canvas,
                    AppleColors.textSecondary,
                  ),
              ],
            ),

            if (doc.about != null && doc.about!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                doc.about!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppleColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],

            if (doc.hasAvailability) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppleColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppleColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: AppleColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _availabilityLabel(doc),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppleColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Book Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BookAppointmentPage(
                        session: widget.session,
                        preselectedDoctor: doc,
                        onAppointmentBooked: widget.onAppointmentBooked,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppleColors.brand,
                  side: const BorderSide(color: AppleColors.brandLight),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 16),
                label: Text(
                  'Book Appointment with ${doc.displayName.split(",").first}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(IconData icon, String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textCol),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textCol),
          ),
        ],
      ),
    );
  }
}

String _availabilityLabel(DoctorEntry doc) {
  final days = doc.availableDays.take(5).join(', ');
  final hours = doc.availableHours.trim();
  if (days.isNotEmpty && hours.isNotEmpty) return '$days · $hours';
  if (days.isNotEmpty) return days;
  return hours;
}