import 'package:flutter/material.dart';

import '../models/patient_session.dart';
import '../services/records_service.dart';
import '../widgets/app_animations.dart';
import '../utils/formatters.dart';
import '../widgets/apple_ui.dart';
import '../widgets/details_sheet.dart';
import 'file_viewer_page.dart';

/// The patient's "Medical Record" tab: clinical records plus uploaded
/// documents, always read live from the clinic so new uploads and deletions
/// are reflected on the next load or pull-to-refresh.
class MedicalRecordsTab extends StatefulWidget {
  const MedicalRecordsTab({super.key, required this.session, this.service});

  final PatientSession session;
  final RecordsService? service;

  @override
  State<MedicalRecordsTab> createState() => _MedicalRecordsTabState();
}

class _MedicalRecordsTabState extends State<MedicalRecordsTab> {
  late final RecordsService _service;
  late final bool _ownsService;
  late Future<MedicalRecordsData> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RecordsService(session: widget.session);
    _ownsService = widget.service == null;
    _future = _service.fetchAll();
  }

  @override
  void dispose() {
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.fetchAll();
    });
  }

  Future<void> _refresh() async {
    try {
      final updated = await _service.fetchAll();
      if (!mounted) return;
      setState(() => _future = Future.value(updated));
    } catch (error) {
      if (!mounted) return;
      final message = error is RecordsException
          ? error.message
          : 'Could not refresh your medical records. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MedicalRecordsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonLoader();
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is RecordsException
              ? error.message
              : 'Could not load your medical records. Please try again.';
          return _ErrorView(message: message, onRetry: _reload);
        }
        final data = snapshot.data;
        if (data == null) {
          return _ErrorView(
            message: 'Could not load your medical records. Please try again.',
            onRetry: _reload,
          );
        }
        return FadeSlideIn(
          child: _RecordsBody(
            data: data,
            service: _service,
            onRefresh: _refresh,
          ),
        );
      },
    );
  }
}

class _RecordsBody extends StatefulWidget {
  const _RecordsBody({
    required this.data,
    required this.service,
    required this.onRefresh,
  });

  final MedicalRecordsData data;
  final RecordsService service;
  final Future<void> Function() onRefresh;

  @override
  State<_RecordsBody> createState() => _RecordsBodyState();
}

class _RecordsBodyState extends State<_RecordsBody> {
  String? _openingFileId;

  Future<void> _openFile(MedicalRecordFileEntry file) async {
    if (_openingFileId != null) return;
    setState(() => _openingFileId = file.fileId);
    try {
      final url = await widget.service.downloadUrl(file.fileId);
      if (!mounted) return;
      setState(() => _openingFileId = null);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FileViewerPage(file: file, url: url),
        ),
      );
    } on RecordsException catch (error) {
      if (!mounted) return;
      setState(() => _openingFileId = null);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _openingFileId = null);
      _showMessage('Could not open this file. Please try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppleColors.brand,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 24),
            _EmptyView(),
            SizedBox(height: 28),
            Center(
              child: Text(
                'Pull down to refresh',
                style: TextStyle(fontSize: 12, color: AppleColors.textTertiary),
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AppleColors.canvas,
            child: TabBar(
              labelColor: AppleColors.brand,
              unselectedLabelColor: AppleColors.textSecondary,
              indicatorColor: AppleColors.brand,
              indicatorWeight: 2.5,
              dividerColor: AppleColors.border,
              labelStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
              tabs: const [
                Tab(icon: Icon(Icons.timeline_rounded, size: 20), text: 'Timeline'),
                Tab(icon: Icon(Icons.folder_outlined, size: 20), text: 'Files'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _TimelineView(
                  data: data,
                  onRefresh: widget.onRefresh,
                  onOpenFile: _openFile,
                  openingFileId: _openingFileId,
                  onOpenRecord: (record) =>
                      _showRecordDetails(context, record),
                ),
                _FilesView(
                  data: data,
                  onRefresh: widget.onRefresh,
                  onOpenFile: _openFile,
                  openingFileId: _openingFileId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TimelineFilter { all, visits, documents }

class _TimelineView extends StatefulWidget {
  const _TimelineView({
    required this.data,
    required this.onRefresh,
    required this.onOpenFile,
    required this.openingFileId,
    required this.onOpenRecord,
  });

  final MedicalRecordsData data;
  final Future<void> Function() onRefresh;
  final ValueChanged<MedicalRecordFileEntry> onOpenFile;
  final String? openingFileId;
  final ValueChanged<MedicineRecordEntry> onOpenRecord;

  @override
  State<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<_TimelineView> {
  _TimelineFilter _filter = _TimelineFilter.all;

  List<_TimelineEvent> _buildEvents() {
    final events = <_TimelineEvent>[];
    if (_filter != _TimelineFilter.documents) {
      for (final record in widget.data.records) {
        events.add(
          _TimelineEvent(
            date: record.visitDate ?? record.createdAt,
            record: record,
          ),
        );
      }
    }
    if (_filter != _TimelineFilter.visits) {
      for (final file in widget.data.files) {
        events.add(_TimelineEvent(date: file.createdAt, file: file));
      }
    }
    events.sort((a, b) {
      final da = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final events = _buildEvents();
    final groups = <String, List<_TimelineEvent>>{};
    for (final event in events) {
      groups.putIfAbsent(_dayLabel(event.date), () => []).add(event);
    }

    var revealIndex = 0;
    final content = RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppleColors.brand,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == _TimelineFilter.all,
                onTap: () => setState(() => _filter = _TimelineFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Visits',
                selected: _filter == _TimelineFilter.visits,
                onTap: () => setState(() => _filter = _TimelineFilter.visits),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Documents',
                selected: _filter == _TimelineFilter.documents,
                onTap: () => setState(() => _filter = _TimelineFilter.documents),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'Nothing in this filter yet.',
                  style: TextStyle(fontSize: 14, color: AppleColors.textSecondary),
                ),
              ),
            ),
          for (final group in groups.entries) ...[
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppleColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  group.key,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppleColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final event in group.value)
              RevealItem(
                index: revealIndex++,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: 2,
                                color: AppleColors.border,
                              ),
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: event.isRecord
                                    ? AppleColors.brand
                                    : AppleColors.orange,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                width: 2,
                                color: AppleColors.border,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: event.isRecord
                              ? _TimelineCard(
                                  icon: Icons.medical_information_outlined,
                                  iconColor: AppleColors.brand,
                                  iconBackground: AppleColors.brandLight,
                                  badge: 'Visit',
                                  title: _recordTitle(event.record!),
                                  subtitle: _recordSubtitle(event.record!),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: AppleColors.textTertiary,
                                  ),
                                  onTap: () =>
                                      widget.onOpenRecord(event.record!),
                                )
                              : _TimelineCard(
                                  icon: _fileIcon(event.file!.mimeType),
                                  iconColor: _iconColor(event.file!.mimeType),
                                  iconBackground:
                                      _iconBackground(event.file!.mimeType),
                                  badge: 'Document',
                                  title: event.file!.fileName,
                                  subtitle: _fileSubtitle(event.file!),
                                  trailing: widget.openingFileId ==
                                          event.file!.fileId
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.play_circle_outline_rounded,
                                          color: AppleColors.brand,
                                        ),
                                  onTap: () => widget.onOpenFile(event.file!),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Pull down to refresh',
              style: TextStyle(fontSize: 12, color: AppleColors.textTertiary),
            ),
          ),
        ],
      ),
    );
    return RevealScope(replayKey: _filter, child: content);
  }
}

class _FilesView extends StatelessWidget {
  const _FilesView({
    required this.data,
    required this.onRefresh,
    required this.onOpenFile,
    required this.openingFileId,
  });

  final MedicalRecordsData data;
  final Future<void> Function() onRefresh;
  final ValueChanged<MedicalRecordFileEntry> onOpenFile;
  final String? openingFileId;

  @override
  Widget build(BuildContext context) {
    final groups = _groupFiles(data.files, data.folders);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppleColors.brand,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _SectionHeader(
            icon: Icons.folder_shared_outlined,
            title: 'Files & Documents',
            count: data.files.length,
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a file to view it, stream it, or download it.',
            style: TextStyle(fontSize: 12.5, color: AppleColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Center(
                child: Text(
                  'No documents uploaded yet.',
                  style: TextStyle(fontSize: 14, color: AppleColors.textSecondary),
                ),
              ),
            ),
          for (final group in groups) ...[
            _FolderCard(
              group: group,
              openingFileId: openingFileId,
              onOpenFile: onOpenFile,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
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
}

class _TimelineEvent {
  const _TimelineEvent({this.date, this.record, this.file});

  final DateTime? date;
  final MedicineRecordEntry? record;
  final MedicalRecordFileEntry? file;

  bool get isRecord => record != null;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: Motion.panel,
        curve: Motion.ease,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppleColors.brand : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppleColors.brand : AppleColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppleColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String badge;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppleTapBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppleColors.border, width: 0.8),
          boxShadow: AppleColors.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppleColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppleColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: trailing,
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.group,
    required this.openingFileId,
    required this.onOpenFile,
  });

  final _FileGroup group;
  final String? openingFileId;
  final ValueChanged<MedicalRecordFileEntry> onOpenFile;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppleColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            color: AppleColors.canvas,
            child: Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: AppleColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  '${group.files.length}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppleColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < group.files.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppleColors.border),
            _FileTile(
              file: group.files[i],
              isOpening: openingFileId == group.files[i].fileId,
              onTap: () => onOpenFile(group.files[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.isOpening,
    required this.onTap,
  });

  final MedicalRecordFileEntry file;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      _formatSize(file.size),
      _formatDate(file.createdAt),
    ];
    if (file.version > 1) meta.add('v${file.version}');
    if ((file.uploadedByName ?? '').trim().isNotEmpty) {
      meta.add('by ${file.uploadedByName!.trim()}');
    }

    return ListTile(
      onTap: isOpening ? null : onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: _iconBackground(file.mimeType),
        child: Icon(
          _fileIcon(file.mimeType),
          size: 18,
          color: _iconColor(file.mimeType),
        ),
      ),
      title: Text(
        file.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        meta.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppleColors.textSecondary),
      ),
      trailing: isOpening
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(
              Icons.play_circle_outline_rounded,
              size: 21,
              color: AppleColors.brand,
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppleColors.brand),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppleColors.brandLight,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppleColors.brand,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: const [
          Icon(
            Icons.folder_open_outlined,
            size: 56,
            color: AppleColors.brand,
          ),
          SizedBox(height: 16),
          Text(
            'No medical records yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppType.displayFamily,
              fontSize: 19,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Records and documents added by your clinic will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppleColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 64),
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppleColors.brandLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_shared_outlined,
              size: 32,
              color: AppleColors.brand,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppleColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: AppleTapBounce(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: AppleColors.brand,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Try again',
                    style: TextStyle(
                      fontSize: 14,
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
    );
  }
}

class _FileGroup {
  const _FileGroup({required this.name, required this.files});

  final String name;
  final List<MedicalRecordFileEntry> files;
}

List<_FileGroup> _groupFiles(
  List<MedicalRecordFileEntry> files,
  List<MedicalRecordFolderEntry> folders,
) {
  final namesByKey = <String, String>{};
  for (final folder in folders) {
    namesByKey[folder.folderId] = folder.name;
    final key = folder.defaultKey;
    if (key != null && key.isNotEmpty) namesByKey[key] = folder.name;
  }

  final grouped = <String, List<MedicalRecordFileEntry>>{};
  for (final file in files) {
    final key = (file.folder ?? '').trim();
    final name = key.isEmpty
        ? 'Other Documents'
        : (namesByKey[key] ?? _prettifyFolderKey(key));
    grouped.putIfAbsent(name, () => []).add(file);
  }

  final orderedNames = <String>[];
  for (final folder in folders) {
    if (grouped.containsKey(folder.name) &&
        !orderedNames.contains(folder.name)) {
      orderedNames.add(folder.name);
    }
  }
  for (final name in grouped.keys) {
    if (!orderedNames.contains(name)) orderedNames.add(name);
  }

  return [
    for (final name in orderedNames)
      _FileGroup(name: name, files: grouped[name]!),
  ];
}

void _showRecordDetails(BuildContext context, MedicineRecordEntry record) {
  showDetailsSheet(
    context: context,
    title: record.diagnosis?.trim().isNotEmpty == true
        ? record.diagnosis!.trim()
        : 'Medical Record',
    subtitle: _formatDate(record.visitDate),
    icon: Icons.folder_shared_outlined,
    accent: AppleColors.brand,
    children: [
      DetailSection(
        title: 'Clinical Summary',
        icon: Icons.medical_information_outlined,
        accent: AppleColors.brand,
        children: [
          DetailField(
            label: 'Diagnosis',
            value: record.diagnosis ?? 'Not specified',
          ),
          DetailField(
            label: 'Visit date',
            value: _formatDate(record.visitDate),
          ),
          if (record.doctorName != null)
            DetailField(label: 'Doctor', value: record.doctorName!),
          if (record.symptoms != null)
            DetailField(label: 'Symptoms', value: record.symptoms!),
          if (record.treatment != null)
            DetailField(label: 'Treatment', value: record.treatment!),
          if (record.notes != null)
            DetailField(label: 'Notes', value: record.notes!),
          if (record.attachments.isNotEmpty)
            DetailField(
              label: 'Attachments',
              value: record.attachments.join(', '),
            ),
        ],
      ),
    ],
  );
}

String _recordTitle(MedicineRecordEntry record) {
  final diagnosis = (record.diagnosis ?? '').trim();
  return diagnosis.isEmpty ? 'Medical record' : diagnosis;
}

String _recordSubtitle(MedicineRecordEntry record) {
  final parts = <String>[
    'Visit',
    if ((record.doctorName ?? '').trim().isNotEmpty)
      doctorTitle(record.doctorName),
    _formatDate(record.visitDate),
  ];
  final preview = (record.treatment ?? record.symptoms ?? '').trim();
  if (preview.isNotEmpty) parts.add(preview);
  return parts.join(' · ');
}

String _fileSubtitle(MedicalRecordFileEntry file) {
  final parts = <String>[
    _formatSize(file.size),
    _formatDate(file.createdAt),
  ];
  if (file.version > 1) parts.add('v${file.version}');
  if ((file.uploadedByName ?? '').trim().isNotEmpty) {
    parts.add('by ${file.uploadedByName!.trim()}');
  }
  return parts.join(' · ');
}

String _dayLabel(DateTime? date) {
  if (date == null) return 'Undated';
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  if (local.year == now.year) {
    return '${local.day} ${months[local.month - 1]}';
  }
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String _prettifyFolderKey(String key) {
  final words = key.split(RegExp(r'[-_]+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return 'Other Documents';
  return words
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Date not available';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String _formatSize(int bytes) {
  if (bytes <= 0) return 'Document';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

IconData _fileIcon(String? mimeType) {
  final mime = (mimeType ?? '').toLowerCase();
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mime.startsWith('video/')) return Icons.videocam_outlined;
  return Icons.description_outlined;
}

Color _iconColor(String? mimeType) {
  final mime = (mimeType ?? '').toLowerCase();
  if (mime.startsWith('image/')) return AppleColors.brand;
  if (mime == 'application/pdf') return AppleColors.red;
  if (mime.startsWith('video/')) return AppleColors.purple;
  return AppleColors.brand;
}

Color _iconBackground(String? mimeType) {
  final mime = (mimeType ?? '').toLowerCase();
  if (mime.startsWith('image/')) return AppleColors.brandLight;
  if (mime == 'application/pdf') return AppleColors.redLight;
  if (mime.startsWith('video/')) return AppleColors.purpleLight;
  return AppleColors.brandLight;
}
