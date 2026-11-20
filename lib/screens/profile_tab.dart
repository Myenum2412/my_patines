import 'package:flutter/material.dart';

import '../main.dart' show LoginPage;
import '../models/patient_session.dart'; // includes SessionStorage
import '../services/patient_portal_service.dart';
import '../services/session_manager.dart';
import '../utils/formatters.dart';
import '../widgets/app_animations.dart';
import '../widgets/apple_ui.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/patient_avatar_view.dart';

/// Profile tab backed by the clinic's `/me/patient` endpoint.
///
/// The layout mirrors the web patient profile: a summary header with the
/// patient's key details, then Overview / Contact / Medical / Clinic tabs.
/// Patients can edit their own record; the clinic tab stays read-only.
class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.session,
    this.onProfileUpdated,
    this.service,
  });

  final PatientSession session;
  final VoidCallback? onProfileUpdated;
  final PatientPortalService? service;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with SingleTickerProviderStateMixin {
  late final PatientPortalService _service;
  late final bool _ownsService;
  late final TabController _tabController;

  PatientProfile? _patient;
  ClinicInfo? _clinic;
  bool _loading = true;
  String? _error;
  bool _editing = false;
  bool _saving = false;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _errors = {};
  String _gender = '';
  String _bloodGroup = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PatientPortalService(session: widget.session);
    _ownsService = widget.service == null;
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _tabController.dispose();
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && _patient == null) {
      setState(() => _loading = true);
    }
    try {
      final patient = await _service.fetchProfile();
      ClinicInfo? clinic;
      try {
        clinic = await _service.fetchClinic();
      } catch (_) {
        clinic = null;
      }
      if (!mounted) return;
      setState(() {
        _patient = patient;
        _clinic = clinic;
        _error = null;
        _loading = false;
      });
    } on PortalException catch (error) {
      if (!mounted) return;
      if (_patient == null) {
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
      const message = 'Could not load your profile. Please try again.';
      if (_patient == null) {
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

  Future<void> _refresh() async {
    if (_editing) return;
    await _load(showSpinner: false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _startEdit() {
    final patient = _patient;
    if (patient == null) return;
    _fillControllers(patient);
    _gender = patient.gender ?? '';
    _bloodGroup = patient.bloodGroup ?? '';
    _errors.clear();
    setState(() => _editing = true);
    _tabController.animateTo(0);
  }

  void _cancelEdit() {
    _errors.clear();
    setState(() => _editing = false);
  }

  void _fillControllers(PatientProfile patient) {
    final initial = <String, String>{
      'fullName': patient.fullName,
      'mobile': patient.mobile,
      'whatsapp': patient.whatsapp ?? '',
      'email': patient.email ?? '',
      'dateOfBirth': patient.dateOfBirth ?? '',
      'height': patient.height ?? '',
      'weight': patient.weight ?? '',
      'bloodPressure': patient.bloodPressure ?? '',
      'temperature': patient.temperature ?? '',
      'pulse': patient.pulse ?? '',
      'respiratoryRate': patient.respiratoryRate ?? '',
      'spo2': patient.spo2 ?? '',
      'maritalStatus': patient.maritalStatus ?? '',
      'occupation': patient.occupation ?? '',
      'address': patient.address ?? '',
      'city': patient.city ?? '',
      'state': patient.state ?? '',
      'pincode': patient.pincode ?? '',
      'emergencyContactName': patient.emergencyContactName ?? '',
      'emergencyContactRelationship':
          patient.emergencyContactRelationship ?? '',
      'emergencyContactMobile': patient.emergencyContactMobile ?? '',
      'allergies': patient.allergies.join(', '),
      'medicalConditions': patient.medicalConditions ?? '',
      'previousSurgeries': patient.previousSurgeries ?? '',
      'currentMedications': patient.currentMedications ?? '',
      'familyHistory': patient.familyHistory ?? '',
      'patientHistory': patient.patientHistory ?? '',
      'habits': patient.habits ?? '',
      'idType': patient.idType ?? '',
      'idNumber': patient.idNumber ?? '',
      'insuranceProvider': patient.insuranceProvider ?? '',
      'insurancePolicyNumber': patient.insurancePolicyNumber ?? '',
      'insurancePolicyHolderName': patient.insurancePolicyHolderName ?? '',
      'insuranceValidTill': patient.insuranceValidTill ?? '',
    };
    for (final entry in initial.entries) {
      final controller = _controllers.putIfAbsent(
        entry.key,
        () => TextEditingController(),
      );
      controller.text = entry.value;
    }
  }

  TextEditingController _controller(String key) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(),
    );
  }

  String _value(String key) => (_controllers[key]?.text ?? '').trim();

  Future<void> _pickDate(String key, {required bool birthDate}) async {
    final controller = _controllers[key];
    if (controller == null) return;
    final now = DateTime.now();
    final firstDate = birthDate ? DateTime(1900) : now.subtract(const Duration(days: 365 * 5));
    final lastDate = birthDate ? now : now.add(const Duration(days: 365 * 20));
    final parsed = DateTime.tryParse(controller.text.trim());
    var initialDate = parsed ??
        (birthDate
            ? DateTime(1990, 1, 1)
            : now.add(const Duration(days: 365)));
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: birthDate ? 'Select date of birth' : 'Select valid till date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = _isoDate(picked);
      _errors.remove(key);
    });
  }

  String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  bool _validate() {
    final errors = <String, String>{};
    if (_value('fullName').length < 2) {
      errors['fullName'] = 'Enter your full name';
    }
    if (_value('mobile').length < 8) {
      errors['mobile'] = 'Enter a valid mobile number';
    }
    final email = _value('email');
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      errors['email'] = 'Enter a valid email address';
    }
    final pincode = _value('pincode');
    if (pincode.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(pincode)) {
      errors['pincode'] = 'Pincode must be 6 digits';
    }

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });

    if (errors.isEmpty) return true;
    const overviewFields = {'fullName'};
    const contactFields = {'mobile', 'email', 'pincode'};
    if (errors.keys.any(overviewFields.contains)) {
      _tabController.animateTo(0);
    } else if (errors.keys.any(contactFields.contains)) {
      _tabController.animateTo(1);
    }
    return false;
  }

  Future<void> _save() async {
    if (_saving || !_validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await _service.updateProfile(_buildPayload());
      if (!mounted) return;
      setState(() {
        _patient = updated;
        _editing = false;
        _saving = false;
        _errors.clear();
      });
      widget.onProfileUpdated?.call();
      _showMessage('Profile updated successfully.');
    } on PortalException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not update your profile. Please try again.');
    }
  }

  Map<String, dynamic> _buildPayload() {
    String? optional(String key) {
      final value = _value(key);
      return value.isEmpty ? null : value;
    }

    return {
      'fullName': _value('fullName'),
      'mobile': _value('mobile'),
      'whatsapp': optional('whatsapp'),
      'email': optional('email'),
      'gender': _gender.isEmpty ? null : _gender,
      'dateOfBirth': optional('dateOfBirth'),
      'bloodGroup': _bloodGroup.isEmpty ? null : _bloodGroup,
      'address': optional('address'),
      'city': optional('city'),
      'state': optional('state'),
      'pincode': optional('pincode'),
      'height': optional('height'),
      'weight': optional('weight'),
      'bloodPressure': optional('bloodPressure'),
      'temperature': optional('temperature'),
      'pulse': optional('pulse'),
      'respiratoryRate': optional('respiratoryRate'),
      'spo2': optional('spo2'),
      'occupation': optional('occupation'),
      'maritalStatus': optional('maritalStatus'),
      'emergencyContactName': optional('emergencyContactName'),
      'emergencyContactRelationship':
          optional('emergencyContactRelationship'),
      'emergencyContactMobile': optional('emergencyContactMobile'),
      'allergies': _value('allergies')
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'medicalConditions': optional('medicalConditions'),
      'previousSurgeries': optional('previousSurgeries'),
      'currentMedications': optional('currentMedications'),
      'familyHistory': optional('familyHistory'),
      'patientHistory': optional('patientHistory'),
      'habits': optional('habits'),
      'idType': optional('idType'),
      'idNumber': optional('idNumber'),
      'insuranceProvider': optional('insuranceProvider'),
      'insurancePolicyNumber': optional('insurancePolicyNumber'),
      'insurancePolicyHolderName': optional('insurancePolicyHolderName'),
      'insuranceValidTill': optional('insuranceValidTill'),
    };
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          title: const Text('Log out?'),
          content: const Text(
            'You will need your email and password to sign in again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await SessionManager.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _patient == null) {
      return const SkeletonLoader(rows: 5);
    }
    if (_error != null && _patient == null) {
      return _ProfileError(message: _error!, onRetry: () => _load());
    }

    final patient = _patient;
    if (patient == null) {
      return _ProfileError(
        message: 'Your profile is not available right now.',
        onRetry: () => _load(),
      );
    }

    final values = _displayValues(patient);

    final content = Column(
      children: [
        _ProfileHeader(
          patient: patient,
          clinicName: _clinic?.name ?? widget.session.clinicName ?? 'My Clinic',
          editing: _editing,
          saving: _saving,
          onEdit: _startEdit,
          onCancel: _cancelEdit,
          onSave: _save,
          onLogout: _logout,
        ),
        Material(
          color: AppleColors.canvas,
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppleColors.brand,
                unselectedLabelColor: AppleColors.textSecondary,
                indicatorColor: AppleColors.brand,
                indicatorWeight: 2.5,
                dividerColor: AppleColors.border,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Contact & Address'),
                  Tab(text: 'Medical & Health'),
                  Tab(text: 'Clinic Details'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _tabBody(_buildOverview(patient, values)),
              _tabBody(_buildContact(values)),
              _tabBody(_buildMedical(values)),
              _tabBody(_buildClinic()),
            ],
          ),
        ),
      ],
    );
    return FadeSlideIn(child: content);
  }

  Widget _tabBody(List<Widget> sections) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppleColors.brand,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          ...sections,
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Pull down to refresh',
              style: TextStyle(fontSize: 12, color: AppleColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOverview(
    PatientProfile patient,
    Map<String, String> values,
  ) {
    return [
      _SectionCard(
        icon: Icons.person_outline,
        title: 'Personal details',
        accent: AppleColors.brand,
        children: [
          _InfoGrid(
            columns: _editing ? 1 : 2,
            children: [
              _field('fullName', 'Full name', values),
              _genderField(values),
              _field(
                'dateOfBirth',
                'Date of birth',
                values,
                readOnly: true,
                onTap: () => _pickDate('dateOfBirth', birthDate: true),
              ),
              _bloodGroupField(values),
            ],
          ),
          const SizedBox(height: 14),
          _InfoGrid(
            columns: _editing ? 1 : 2,
            children: [
              _field('height', 'Height', values, hint: 'e.g. 175 cm'),
              _field('weight', 'Weight', values, hint: 'e.g. 70 kg'),
              _field('maritalStatus', 'Marital status', values),
              _field('occupation', 'Occupation', values),
            ],
          ),
          const SizedBox(height: 14),
          _InfoGrid(
            columns: _editing ? 1 : 2,
            children: [
              _field('idType', 'ID type', values, hint: 'Aadhaar / Passport'),
              _field('idNumber', 'ID number', values),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SectionCard(
        icon: Icons.monitor_heart_outlined,
        title: 'Physical & health',
        accent: AppleColors.brand,
        children: [
          _InfoGrid(
            columns: _editing ? 1 : 2,
            children: [
              _field(
                'bloodPressure',
                'Blood pressure',
                values,
                hint: '120/80',
              ),
              _field('temperature', 'Temperature', values, hint: '98.6'),
              _field('pulse', 'Pulse', values, hint: '72 bpm'),
              _field(
                'respiratoryRate',
                'Respiratory rate',
                values,
                hint: '16 /min',
              ),
              _field('spo2', 'SpO₂', values, hint: '98 %'),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      _StatusNote(
        text: patient.status.toLowerCase() == 'active'
            ? 'This patient record is active at your clinic.'
            : 'This patient record is currently marked ${formatStatus(patient.status).toLowerCase()}.',
      ),
    ];
  }

  List<Widget> _buildContact(Map<String, String> values) {
    return [
      _SectionCard(
        icon: Icons.phone_outlined,
        title: 'Contact channels',
        accent: AppleColors.purple,
        children: [
          _InfoGrid(
            columns: _editing ? 1 : 2,
            children: [
              _field(
                'mobile',
                'Mobile number',
                values,
                keyboardType: TextInputType.phone,
              ),
              _field(
                'whatsapp',
                'WhatsApp number',
                values,
                keyboardType: TextInputType.phone,
              ),
              _field(
                'email',
                'Email address',
                values,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SectionCard(
        icon: Icons.home_outlined,
        title: 'Address',
        accent: AppleColors.orange,
        children: [
          _field(
            'address',
            'Street address',
            values,
            maxLines: 2,
            hint: 'House no, street, area',
          ),
          const SizedBox(height: 14),
          _InfoGrid(
            columns: _editing ? 1 : 2,
            children: [
              _field('city', 'City', values),
              _field('state', 'State', values),
              _field('pincode', 'Pincode', values, keyboardType: TextInputType.number),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SectionCard(
        icon: Icons.emergency_outlined,
        title: 'Emergency contact',
        accent: AppleColors.red,
        children: [
          _InfoGrid(
            columns: _editing ? 1 : 2,
            children: [
              _field(
                'emergencyContactName',
                'Contact name',
                values,
              ),
              _field(
                'emergencyContactRelationship',
                'Relationship',
                values,
              ),
              _field(
                'emergencyContactMobile',
                'Emergency mobile',
                values,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildMedical(Map<String, String> values) {
    return [
      _SectionCard(
        icon: Icons.favorite_border_rounded,
        title: 'Medical history',
        accent: const Color(0xFFE11D48),
        children: [
          _field(
            'allergies',
            'Known allergies',
            values,
            hint: 'Dust, penicillin (comma separated)',
          ),
          const SizedBox(height: 14),
          _field(
            'medicalConditions',
            'Medical conditions',
            values,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _field(
            'currentMedications',
            'Current medications',
            values,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _field(
            'previousSurgeries',
            'Previous surgeries',
            values,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _field(
            'familyHistory',
            'Family history',
            values,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _field(
            'patientHistory',
            'Patient history',
            values,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _field('habits', 'Habits', values, maxLines: 2),
        ],
      ),
      const SizedBox(height: 12),
      _SectionCard(
        icon: Icons.shield_outlined,
        title: 'Insurance details',
        accent: AppleColors.green,
        children: [
          _InfoGrid(
            columns: _editing ? 1 : 2,
            children: [
              _field('insuranceProvider', 'Insurance provider', values),
              _field('insurancePolicyNumber', 'Policy number', values),
              _field('insurancePolicyHolderName', 'Policy holder', values),
              _field(
                'insuranceValidTill',
                'Valid till',
                values,
                readOnly: true,
                onTap: () => _pickDate(
                  'insuranceValidTill',
                  birthDate: false,
                ),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildClinic() {
    final clinic = _clinic;
    if (clinic == null) {
      return [
        _SectionCard(
          icon: Icons.local_hospital_outlined,
          title: 'Clinic details',
          accent: AppleColors.brandDeep,
          children: [
            Text(
              widget.session.clinicName ?? 'My Clinic',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppleColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Detailed clinic information is not available right now. Pull down to try again, or contact your clinic directly.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppleColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _StatusNote(
          text: 'Clinic details are maintained by your clinic and cannot be edited here.',
        ),
      ];
    }

    return [
      _SectionCard(
        icon: Icons.local_hospital_outlined,
        title: 'Clinic overview',
        accent: AppleColors.brandDeep,
        children: [
          _InfoGrid(
            columns: 2,
            children: [
              _InfoField(label: 'Clinic name', value: clinic.name),
              _InfoField(
                label: 'Clinic type',
                value: clinic.clinicType,
              ),
              _InfoField(
                label: 'Registration number',
                value: clinic.registrationNumber,
              ),
              _InfoField(
                label: 'Established year',
                value: clinic.establishedYear,
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      _SectionCard(
        icon: Icons.contact_phone_outlined,
        title: 'Contact & location',
        accent: AppleColors.brand,
        children: [
          _InfoGrid(
            columns: 2,
            children: [
              _InfoField(label: 'Clinic phone', value: clinic.phone),
              _InfoField(label: 'WhatsApp support', value: clinic.whatsapp),
              _InfoField(label: 'Clinic email', value: clinic.email),
              _InfoField(label: 'Working hours', value: clinic.workingHours),
            ],
          ),
          const SizedBox(height: 14),
          _InfoField(label: 'Website', value: clinic.website),
          const SizedBox(height: 14),
          _InfoField(
            label: 'Clinic address',
            value: clinic.fullAddress,
          ),
          const SizedBox(height: 14),
          _InfoField(
            label: 'Emergency contact',
            value: clinic.emergencyContact,
          ),
        ],
      ),
      const SizedBox(height: 12),
      const _StatusNote(
        text: 'Clinic details are maintained by your clinic and cannot be edited here.',
      ),
    ];
  }

  Map<String, String> _displayValues(PatientProfile patient) {
    return {
      'fullName': patient.fullName,
      'mobile': patient.mobile,
      'whatsapp': patient.whatsapp ?? '',
      'email': patient.email ?? '',
      'gender': formatStatus(patient.gender),
      'dateOfBirth': formatDate(patient.dateOfBirth, fallback: '—'),
      'bloodGroup': patient.bloodGroup ?? '',
      'height': patient.height ?? '',
      'weight': patient.weight ?? '',
      'bloodPressure': patient.bloodPressure ?? '',
      'temperature': patient.temperature ?? '',
      'pulse': patient.pulse ?? '',
      'respiratoryRate': patient.respiratoryRate ?? '',
      'spo2': patient.spo2 ?? '',
      'maritalStatus': patient.maritalStatus ?? '',
      'occupation': patient.occupation ?? '',
      'address': patient.address ?? '',
      'city': patient.city ?? '',
      'state': patient.state ?? '',
      'pincode': patient.pincode ?? '',
      'emergencyContactName': patient.emergencyContactName ?? '',
      'emergencyContactRelationship':
          patient.emergencyContactRelationship ?? '',
      'emergencyContactMobile': patient.emergencyContactMobile ?? '',
      'allergies': patient.allergies.join(', '),
      'medicalConditions': patient.medicalConditions ?? '',
      'previousSurgeries': patient.previousSurgeries ?? '',
      'currentMedications': patient.currentMedications ?? '',
      'familyHistory': patient.familyHistory ?? '',
      'patientHistory': patient.patientHistory ?? '',
      'habits': patient.habits ?? '',
      'idType': patient.idType ?? '',
      'idNumber': patient.idNumber ?? '',
      'insuranceProvider': patient.insuranceProvider ?? '',
      'insurancePolicyNumber': patient.insurancePolicyNumber ?? '',
      'insurancePolicyHolderName': patient.insurancePolicyHolderName ?? '',
      'insuranceValidTill': formatDate(
        patient.insuranceValidTill,
        fallback: '—',
      ),
    };
  }

  Widget _field(
    String key,
    String label,
    Map<String, String> values, {
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    if (!_editing) {
      return _InfoField(label: label, value: values[key] ?? '');
    }
    return _EditField(
      controller: _controller(key),
      label: label,
      hint: hint,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      errorText: _errors[key],
      onChanged: (_) {
        if (_errors.containsKey(key)) {
          setState(() => _errors.remove(key));
        }
      },
    );
  }

  Widget _genderField(Map<String, String> values) {
    if (!_editing) {
      return _InfoField(label: 'Gender', value: values['gender'] ?? '');
    }
    return _DropdownField(
      label: 'Gender',
      value: _gender,
      options: const ['male', 'female', 'other'],
      onChanged: (value) => setState(() => _gender = value ?? ''),
    );
  }

  Widget _bloodGroupField(Map<String, String> values) {
    if (!_editing) {
      return _InfoField(
        label: 'Blood group',
        value: values['bloodGroup'] ?? '',
      );
    }
    return _DropdownField(
      label: 'Blood group',
      value: _bloodGroup,
      options: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
      onChanged: (value) => setState(() => _bloodGroup = value ?? ''),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.patient,
    required this.clinicName,
    required this.editing,
    required this.saving,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
    required this.onLogout,
  });

  final PatientProfile patient;
  final String clinicName;
  final bool editing;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final active = patient.status.toLowerCase() == 'active';
    return Container(
      width: double.infinity,
      color: AppleColors.canvas,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PatientAvatarView(
                patientId: patient.patientId,
                fullName: patient.fullName,
                size: 64,
                showEditBadge: true,
                onTap: () => showAvatarPickerSheet(
                  context: context,
                  patientId: patient.patientId,
                  fullName: patient.fullName,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppType.displayFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: AppleColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppleColors.greenLight
                                : AppleColors.groupedBackground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            active ? 'Active Patient' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? AppleColors.green
                                  : AppleColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ID: ${patient.patientId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppleColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!editing) ...[
                Expanded(
                  child: AppleTapBounce(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppleColors.brandLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: AppleColors.brand,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppleColors.brand,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppleTapBounce(
                    onTap: () => showAvatarPickerSheet(
                      context: context,
                      patientId: patient.patientId,
                      fullName: patient.fullName,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppleColors.groupedBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppleColors.border, width: 0.8),
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 14,
                            color: AppleColors.textPrimary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Avatar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppleColors.textPrimary,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppleTapBounce(
                  onTap: saving ? null : onLogout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppleColors.redLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 14,
                          color: AppleColors.red,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppleColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: AppleTapBounce(
                    onTap: saving ? null : onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppleColors.groupedBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppleColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppleTapBounce(
                    onTap: saving ? null : onSave,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppleColors.brand,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (saving)
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            saving ? 'Saving...' : 'Save',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppleColors.groupedBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppleColors.border, width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderStat(
                    label: 'Blood group',
                    value: patient.bloodGroup ?? '—',
                  ),
                ),
                const _HeaderDivider(),
                Expanded(
                  child: _HeaderStat(
                    label: 'Gender',
                    value: formatStatus(patient.gender),
                  ),
                ),
                const _HeaderDivider(),
                Expanded(
                  child: _HeaderStat(
                    label: 'Date of birth',
                    value: formatDate(patient.dateOfBirth, fallback: '—'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              _HeaderContactLine(
                icon: Icons.local_hospital_rounded,
                text: clinicName,
              ),
              if (patient.locationLabel != '—')
                _HeaderContactLine(
                  icon: Icons.place_rounded,
                  text: patient.locationLabel,
                ),
              _HeaderContactLine(
                icon: Icons.phone_rounded,
                text: patient.mobile.isEmpty ? '—' : patient.mobile,
              ),
              if ((patient.email ?? '').trim().isNotEmpty)
                _HeaderContactLine(
                  icon: Icons.mail_rounded,
                  text: patient.email!.trim(),
                ),
              _HeaderContactLine(
                icon: Icons.event_rounded,
                text: 'Member since ${formatMonthYear(patient.createdAt)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppleColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.trim().isEmpty ? '—' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppleColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  const _HeaderDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppleColors.brandLight,
    );
  }
}

class _HeaderContactLine extends StatelessWidget {
  const _HeaderContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppleColors.textTertiary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text.trim().isEmpty ? '—' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppleColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.accent = AppleColors.brand,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppleColors.border, width: 0.8),
        boxShadow: AppleColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppleColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.children, this.columns = 2});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = columns <= 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final child in children)
              SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppleColors.textTertiary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text.isEmpty ? '—' : text,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppleColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 13.5, color: AppleColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        filled: true,
        fillColor: AppleColors.canvas,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        labelStyle: const TextStyle(fontSize: 12.5, color: AppleColors.textSecondary),
        floatingLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppleColors.brand,
        ),
        hintStyle: const TextStyle(fontSize: 12.5, color: AppleColors.textTertiary),
        suffixIcon: readOnly
            ? const Icon(
                Icons.calendar_today_outlined,
                size: 17,
                color: AppleColors.textTertiary,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 36,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppleColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppleColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppleColors.brand, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppleColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppleColors.red, width: 1.4),
        ),
        errorStyle: const TextStyle(fontSize: 11, color: AppleColors.red),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppleColors.canvas,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        labelStyle: const TextStyle(fontSize: 12.5, color: AppleColors.textSecondary),
        floatingLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppleColors.brand,
        ),
        hintStyle: const TextStyle(fontSize: 12.5, color: AppleColors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppleColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppleColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppleColors.brand, width: 1.4),
        ),
      ),
      hint: Text('Select ${label.toLowerCase()}'),
      items: [
        for (final option in options)
          DropdownMenuItem<String>(
            value: option,
            child: Text(
              formatStatus(option),
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _StatusNote extends StatelessWidget {
  const _StatusNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppleColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppleColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppleColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppleColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

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
          Icons.person_off_outlined,
          size: 52,
          color: AppleColors.textTertiary,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppleColors.textSecondary,
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
