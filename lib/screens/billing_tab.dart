import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/patient_session.dart';
import '../services/patient_portal_service.dart';
import '../utils/formatters.dart';
import '../utils/invoice_pdf_generator.dart';
import '../widgets/app_animations.dart';
import '../widgets/apple_ui.dart';
import '../widgets/details_sheet.dart';
import 'invoice_pdf_preview_page.dart';

enum _BillFilter { all, unpaid, paid }
enum _BillDurationFilter { all, thisMonth, last30Days, thisYear }
enum _BillSort { newest, oldest, highestAmount, lowestAmount }

/// Billing tab: the patient's invoices, payments and outstanding balance.
class BillingTab extends StatefulWidget {
  const BillingTab({super.key, required this.session, this.service});

  final PatientSession session;
  final PatientPortalService? service;

  @override
  State<BillingTab> createState() => BillingTabState();
}

class BillingTabState extends State<BillingTab> {
  late final PatientPortalService _service;
  late final bool _ownsService;

  List<BillEntry>? _bills;
  bool _loading = true;
  String? _error;
  _BillFilter _filter = _BillFilter.all;
  _BillDurationFilter _durationFilter = _BillDurationFilter.all;
  _BillSort _sort = _BillSort.newest;
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

  void _resetFilters() {
    setState(() {
      _filter = _BillFilter.all;
      _durationFilter = _BillDurationFilter.all;
      _sort = _BillSort.newest;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Future<void> refresh() => _load(showSpinner: false);

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner && _bills == null) {
      setState(() => _loading = true);
    }
    try {
      final bills = await _service.fetchBills();
      if (!mounted) return;
      setState(() {
        _bills = bills;
        _error = null;
        _loading = false;
      });
    } on PortalException catch (error) {
      if (!mounted) return;
      if (_bills == null) {
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
      const message = 'Could not load your bills. Please try again.';
      if (_bills == null) {
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
    if (_loading && _bills == null) {
      return const SkeletonLoader();
    }
    if (_error != null && _bills == null) {
      return _BillingError(message: _error!, onRetry: () => _load());
    }

    final allBills = [...?_bills]..sort((a, b) {
        final da = a.invoiceDate ?? a.createdAt;
        final db = b.invoiceDate ?? b.createdAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

    final activeBills =
        allBills.where((bill) => !bill.isVoid && !bill.isDraft).toList();
    final totalBilled = activeBills.fold<double>(
      0,
      (sum, bill) => sum + bill.total,
    );
    final totalPaid = activeBills.fold<double>(
      0,
      (sum, bill) => sum + bill.amountPaid,
    );
    final outstanding = activeBills.fold<double>(
      0,
      (sum, bill) => sum + bill.outstanding,
    );
    final unpaidCount =
        activeBills.where((bill) => !bill.isPaid).length;
    final paidCount =
        activeBills.where((bill) => bill.isPaid).length;

    // 1. Filter by status
    var result = switch (_filter) {
      _BillFilter.all => allBills,
      _BillFilter.unpaid => allBills
          .where((bill) => !bill.isPaid && !bill.isVoid)
          .toList(),
      _BillFilter.paid => allBills.where((bill) => bill.isPaid).toList(),
    };

    // 2. Filter by duration / date range
    final now = DateTime.now();
    if (_durationFilter != _BillDurationFilter.all) {
      result = result.where((bill) {
        final date = bill.invoiceDate ?? bill.createdAt;
        if (date == null) return false;
        return switch (_durationFilter) {
          _BillDurationFilter.all => true,
          _BillDurationFilter.thisMonth =>
            date.year == now.year && date.month == now.month,
          _BillDurationFilter.last30Days =>
            date.isAfter(now.subtract(const Duration(days: 30))),
          _BillDurationFilter.thisYear => date.year == now.year,
        };
      }).toList();
    }

    // 3. Filter by search query
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((bill) {
        if (bill.billNumber.toLowerCase().contains(query)) return true;
        if (bill.notes?.toLowerCase().contains(query) ?? false) return true;
        if (bill.items.any((item) => item.description.toLowerCase().contains(query))) return true;
        return false;
      }).toList();
    }

    // 4. Sort
    result.sort((a, b) {
      final da = a.invoiceDate ?? a.createdAt;
      final db = b.invoiceDate ?? b.createdAt;
      return switch (_sort) {
        _BillSort.newest => () {
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          }(),
        _BillSort.oldest => () {
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          }(),
        _BillSort.highestAmount => b.total.compareTo(a.total),
        _BillSort.lowestAmount => a.total.compareTo(b.total),
      };
    });

    final filtered = result;
    final isFilterActive = _filter != _BillFilter.all ||
        _durationFilter != _BillDurationFilter.all ||
        _sort != _BillSort.newest ||
        query.isNotEmpty;

    final content = RefreshIndicator(
      onRefresh: refresh,
      color: const Color(0xFF2196F3),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _BillingSummaryCard(
            outstanding: outstanding,
            totalBilled: totalBilled,
            totalPaid: totalPaid,
            unpaidCount: unpaidCount,
            billCount: activeBills.length,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Invoices',
                  style: TextStyle(
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
                '${filtered.length} of ${allBills.length}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search Filtration
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
                hintText: 'Search by invoice #, item, or notes...',
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
                        icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
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
          // Horizontal Filter Chips (Status + Duration + Sort)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _BillFilterChip(
                  label: 'All (${allBills.length})',
                  selected: _filter == _BillFilter.all,
                  onTap: () => setState(() => _filter = _BillFilter.all),
                ),
                const SizedBox(width: 8),
                _BillFilterChip(
                  label: 'Unpaid ($unpaidCount)',
                  selected: _filter == _BillFilter.unpaid,
                  onTap: () => setState(() => _filter = _BillFilter.unpaid),
                ),
                const SizedBox(width: 8),
                _BillFilterChip(
                  label: 'Paid ($paidCount)',
                  selected: _filter == _BillFilter.paid,
                  onTap: () => setState(() => _filter = _BillFilter.paid),
                ),
                Container(
                  height: 20,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: const Color(0xFFCBD5E1),
                ),
                _BillFilterChip(
                  label: 'All time',
                  icon: Icons.calendar_today_rounded,
                  selected: _durationFilter == _BillDurationFilter.all,
                  onTap: () => setState(() => _durationFilter = _BillDurationFilter.all),
                ),
                const SizedBox(width: 8),
                _BillFilterChip(
                  label: 'This Month',
                  icon: Icons.date_range_rounded,
                  selected: _durationFilter == _BillDurationFilter.thisMonth,
                  onTap: () => setState(() => _durationFilter = _BillDurationFilter.thisMonth),
                ),
                const SizedBox(width: 8),
                _BillFilterChip(
                  label: 'Last 30 Days',
                  icon: Icons.history_rounded,
                  selected: _durationFilter == _BillDurationFilter.last30Days,
                  onTap: () => setState(() => _durationFilter = _BillDurationFilter.last30Days),
                ),
                const SizedBox(width: 8),
                _BillFilterChip(
                  label: 'This Year',
                  icon: Icons.event_note_rounded,
                  selected: _durationFilter == _BillDurationFilter.thisYear,
                  onTap: () => setState(() => _durationFilter = _BillDurationFilter.thisYear),
                ),
                Container(
                  height: 20,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: const Color(0xFFCBD5E1),
                ),
                PopupMenuButton<_BillSort>(
                  tooltip: 'Sort invoices',
                  initialValue: _sort,
                  onSelected: (sort) => setState(() => _sort = sort),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _BillSort.newest,
                      child: Text('Date: Newest first'),
                    ),
                    const PopupMenuItem(
                      value: _BillSort.oldest,
                      child: Text('Date: Oldest first'),
                    ),
                    const PopupMenuItem(
                      value: _BillSort.highestAmount,
                      child: Text('Amount: High to Low'),
                    ),
                    const PopupMenuItem(
                      value: _BillSort.lowestAmount,
                      child: Text('Amount: Low to High'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _sort != _BillSort.newest ? AppleColors.blue : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _sort != _BillSort.newest ? AppleColors.blue : AppleColors.border,
                        width: 0.8,
                      ),
                      boxShadow: AppleColors.cardShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: 13,
                          color: _sort != _BillSort.newest ? Colors.white : AppleColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          switch (_sort) {
                            _BillSort.newest => 'Sort',
                            _BillSort.oldest => 'Oldest',
                            _BillSort.highestAmount => 'Highest ₹',
                            _BillSort.lowestAmount => 'Lowest ₹',
                          },
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _sort != _BillSort.newest ? Colors.white : AppleColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: _sort != _BillSort.newest ? Colors.white : AppleColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            _BillsEmpty(
              filtered: isFilterActive,
              onShowAll: _resetFilters,
            )
          else
            for (final (index, bill) in filtered.indexed) ...[
              RevealItem(
                index: index,
                child: _BillCard(
                  bill: bill,
                  onTap: () => _showBillDetails(bill),
                ),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Pull down to refresh',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
    return FadeSlideIn(
      child: RevealScope(
        replayKey: (_filter, _sort),
        child: content,
      ),
    );
  }

  void _showBillDetails(BillEntry bill) {
    final status = _statusStyle(bill);
    showDetailsSheet(
      context: context,
      title: bill.billNumber,
      subtitle:
          '${formatDate(bill.invoiceDate)} · ${formatMoney(bill.total)}',
      icon: Icons.receipt_long_outlined,
      accent: status.color,
      children: [
        Row(
          children: [
            StatusPill(
              label: bill.displayStatus,
              color: status.color,
              background: status.background,
            ),
            const Spacer(),
            Text(
              formatMoney(bill.total),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DetailSection(
          title: 'Invoice details',
          icon: Icons.receipt_outlined,
          accent: status.color,
          children: [
            DetailField(label: 'Invoice number', value: bill.billNumber),
            DetailField(
              label: 'Invoice date',
              value: formatDate(bill.invoiceDate),
            ),
            if (bill.dueDate != null)
              DetailField(
                label: 'Due date',
                value: formatDate(bill.dueDate),
              ),
            if (bill.paidAt != null)
              DetailField(
                label: 'Paid on',
                value: formatDateTime(bill.paidAt),
              ),
            if ((bill.doctorName ?? '').trim().isNotEmpty)
              DetailField(label: 'Doctor', value: bill.doctorName!),
            if ((bill.paymentMethod ?? bill.paymentType ?? '')
                .trim()
                .isNotEmpty)
              DetailField(
                label: 'Payment method',
                value: formatStatus(bill.paymentMethod ?? bill.paymentType),
              ),
            if ((bill.reference ?? '').trim().isNotEmpty)
              DetailField(label: 'Reference', value: bill.reference!),
          ],
        ),
        DetailSection(
          title: 'Items',
          icon: Icons.format_list_bulleted_rounded,
          accent: status.color,
          children: [
            if (bill.items.isEmpty)
              const Text(
                'No line items were recorded for this invoice.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              )
            else
              for (final item in bill.items) _BillItemRow(item: item),
          ],
        ),
        DetailSection(
          title: 'Summary',
          icon: Icons.calculate_outlined,
          accent: status.color,
          children: [
            DetailAmountRow(
              label: 'Subtotal',
              value: formatMoney(bill.subtotal),
            ),
            if (bill.discount > 0)
              DetailAmountRow(
                label: 'Discount',
                value: '-${formatMoney(bill.discount)}',
                color: const Color(0xFF15803D),
              ),
            if (bill.taxAmount > 0)
              DetailAmountRow(
                label: 'Tax'
                    '${bill.taxPercent > 0 ? ' (${_trimNumber(bill.taxPercent)}%)' : ''}',
                value: formatMoney(bill.taxAmount),
              ),
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            DetailAmountRow(
              label: 'Total',
              value: formatMoney(bill.total),
              emphasized: true,
            ),
            DetailAmountRow(
              label: 'Amount paid',
              value: formatMoney(bill.amountPaid),
              color: const Color(0xFF15803D),
            ),
            if (bill.outstanding > 0)
              DetailAmountRow(
                label: 'Balance due',
                value: formatMoney(bill.outstanding),
                color: const Color(0xFFB91C1C),
                emphasized: true,
              )
            else
              DetailAmountRow(
                label: 'Balance due',
                value: formatMoney(0),
                color: const Color(0xFF15803D),
              ),
          ],
        ),
        if ((bill.notes ?? '').trim().isNotEmpty)
          DetailSection(
            title: 'Notes',
            icon: Icons.notes_outlined,
            accent: status.color,
            children: [
              DetailField(label: 'Notes', value: bill.notes!),
            ],
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 17,
                color: Color(0xFF64748B),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'For printed copies or insurance reimbursement assistance, contact clinic reception.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleDownloadPdf(bill);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Download PDF Invoice',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Preview PDF',
                onPressed: () {
                  Navigator.of(context).pop();
                  _openPdfViewer(bill);
                },
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Future<void> _handleDownloadPdf(BillEntry bill) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1D1D1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Generating PDF invoice ${bill.billNumber}...',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final bytes = await generateInvoicePdf(
        bill: bill,
        session: widget.session,
      );

      final fileName = 'Invoice_${bill.billNumber}';
      String? savedPath;
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          savedPath = await FileSaver.instance.saveAs(
            name: fileName,
            bytes: bytes,
            fileExtension: 'pdf',
            mimeType: MimeType.pdf,
          );
        } else {
          savedPath = await FileSaver.instance.saveToDownloads(
            name: fileName,
            bytes: bytes,
            fileExtension: 'pdf',
            mimeType: MimeType.pdf,
          );
        }
      } catch (_) {
        // Fallback for test / headless environments where file_saver native channel is unmocked
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1D1D1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  savedPath != null && savedPath.isNotEmpty
                      ? 'Invoice ${bill.billNumber}.pdf saved to Downloads.'
                      : 'Invoice ${bill.billNumber}.pdf downloaded.',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'View',
            textColor: const Color(0xFF60A5FA),
            onPressed: () => _openPdfViewer(bill, bytes),
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text('Failed to generate invoice PDF: $err'),
        ),
      );
    }
  }

  void _openPdfViewer(BillEntry bill, [Uint8List? initialBytes]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoicePdfPreviewPage(
          bill: bill,
          session: widget.session,
          initialPdfBytes: initialBytes,
        ),
      ),
    );
  }
}

class _BillingSummaryCard extends StatelessWidget {
  const _BillingSummaryCard({
    required this.outstanding,
    required this.totalBilled,
    required this.totalPaid,
    required this.unpaidCount,
    required this.billCount,
  });

  final double outstanding;
  final double totalBilled;
  final double totalPaid;
  final int unpaidCount;
  final int billCount;

  @override
  Widget build(BuildContext context) {
    final settled = outstanding <= 0.009;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: settled ? const Color(0xFF0F5132) : const Color(0xFF1D1D1F),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
        boxShadow: AppleColors.elevatedShadow,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                            Icons.credit_card_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Billing overview',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$billCount invoice${billCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  settled ? 'All settled up' : 'Total outstanding',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(outstanding),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  settled
                      ? 'No pending balance on your account.'
                      : '$unpaidCount unpaid invoice${unpaidCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 0.8,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryMiniStat(
                        label: 'Total billed',
                        value: formatMoney(totalBilled),
                      ),
                    ),
                    Container(
                      width: 0.8,
                      height: 32,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _SummaryMiniStat(
                        label: 'Paid',
                        value: formatMoney(totalPaid),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Payment / Settlement Ratio Bar
                Builder(
                  builder: (_) {
                    final ratio = totalBilled > 0
                        ? (totalPaid / totalBilled).clamp(0.0, 1.0)
                        : 1.0;
                    final percent = (ratio * 100).round();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Settlement ratio',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.8),
                                letterSpacing: -0.1,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$percent% paid',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 6,
                            width: double.infinity,
                            color: Colors.white.withValues(alpha: 0.16),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: ratio,
                              child: Container(
                                color: settled
                                    ? const Color(0xFF34C759)
                                    : const Color(0xFF64ACFF),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMiniStat extends StatelessWidget {
  const _SummaryMiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFFC7D2FE),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _BillFilterChip extends StatelessWidget {
  const _BillFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AppleTapBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.hoverIn,
        curve: Motion.ease,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppleColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppleColors.blue : AppleColors.border,
            width: 0.8,
          ),
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

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.onTap});

  final BillEntry bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle(bill);
    return AppleTapBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
                    color: status.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_rounded,
                    size: 18,
                    color: status.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bill.billNumber,
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
                const SizedBox(width: 8),
                StatusPill(
                  label: bill.displayStatus,
                  color: status.color,
                  background: status.background,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                formatDate(bill.invoiceDate),
                if ((bill.doctorName ?? '').trim().isNotEmpty)
                  'Dr. ${bill.doctorName!.trim()}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppleColors.textSecondary,
              ),
            ),
            if (bill.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                bill.items
                    .take(2)
                    .map(
                      (item) =>
                          '${item.description} × ${_trimNumber(item.quantity)}',
                    )
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppleColors.textPrimary,
                ),
              ),
              if (bill.items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '+${bill.items.length - 2} more item${bill.items.length - 2 == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppleColors.textTertiary,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppleColors.hairline),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _BillAmount(
                    label: 'Total',
                    value: formatMoney(bill.total),
                    color: AppleColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: _BillAmount(
                    label: 'Paid',
                    value: formatMoney(bill.amountPaid),
                    color: AppleColors.green,
                  ),
                ),
                Expanded(
                  child: _BillAmount(
                    label: bill.outstanding > 0 ? 'Balance' : 'Status',
                    value: bill.outstanding > 0
                        ? formatMoney(bill.outstanding)
                        : 'Settled',
                    color: bill.outstanding > 0
                        ? AppleColors.red
                        : AppleColors.green,
                    alignEnd: true,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: AppleColors.textTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillAmount extends StatelessWidget {
  const _BillAmount({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _BillItemRow extends StatelessWidget {
  const _BillItemRow({required this.item});

  final BillItemEntry item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${_trimNumber(item.quantity)} × ${formatMoney(item.unitPrice)}'
                  '${item.taxPercent > 0 ? ' · ${_trimNumber(item.taxPercent)}% tax' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMoney(item.lineTotal),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillsEmpty extends StatelessWidget {
  const _BillsEmpty({required this.filtered, required this.onShowAll});

  final bool filtered;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            filtered
                ? Icons.filter_alt_off_outlined
                : Icons.receipt_long_outlined,
            size: 48,
            color: const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 12),
          Text(
            filtered ? 'No invoices in this filter' : 'No bills yet',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            filtered
                ? 'Try a different filter to see your other invoices.'
                : 'Your invoices and payment history will appear here once your clinic issues a bill.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF64748B),
            ),
          ),
          if (filtered) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onShowAll,
              child: const Text('Show all invoices'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillingError extends StatelessWidget {
  const _BillingError({required this.message, required this.onRetry});

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

({Color color, Color background}) _statusStyle(BillEntry bill) {
  if (bill.isVoid || bill.isDraft) {
    return (color: const Color(0xFF64748B), background: const Color(0xFFF1F5F9));
  }
  if (bill.isPaid) {
    return (color: const Color(0xFF15803D), background: const Color(0xFFDCFCE7));
  }
  if (bill.paymentStatus == 'partial' || bill.amountPaid > 0) {
    return (color: const Color(0xFFB45309), background: const Color(0xFFFEF3C7));
  }
  return (color: const Color(0xFFB91C1C), background: const Color(0xFFFEE2E2));
}

String _trimNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
