import 'dart:io' show Platform;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../models/patient_session.dart';
import '../services/patient_portal_service.dart';
import '../utils/invoice_pdf_generator.dart';
import '../widgets/apple_ui.dart';

/// Apple-styled full-screen in-app PDF previewer for clinic invoices.
///
/// Supports pinch-to-zoom on mobile and simple view on desktop, page navigation,
/// re-downloading to device storage, and instant presentation.
class InvoicePdfPreviewPage extends StatefulWidget {
  const InvoicePdfPreviewPage({
    super.key,
    required this.bill,
    required this.session,
    this.profile,
    this.initialPdfBytes,
  });

  final BillEntry bill;
  final PatientSession session;
  final PatientProfile? profile;
  final Uint8List? initialPdfBytes;

  @override
  State<InvoicePdfPreviewPage> createState() => _InvoicePdfPreviewPageState();
}

class _InvoicePdfPreviewPageState extends State<InvoicePdfPreviewPage> {
  Uint8List? _pdfBytes;
  PdfControllerPinch? _pinchController;
  PdfController? _simpleController;
  bool _loading = true;
  Object? _error;
  bool _isSaving = false;

  bool get _isDesktop {
    if (kIsWeb) return true;
    try {
      if (Platform.isWindows || Platform.isLinux) return true;
    } catch (_) {}
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  @override
  void dispose() {
    _pinchController?.dispose();
    _simpleController?.dispose();
    super.dispose();
  }

  Future<void> _initPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = widget.initialPdfBytes ??
          await generateInvoicePdf(
            bill: widget.bill,
            session: widget.session,
            profile: widget.profile,
          );

      if (_isDesktop) {
        _simpleController?.dispose();
        _simpleController = PdfController(
          document: PdfDocument.openData(Future.value(bytes)),
        );
      } else {
        _pinchController?.dispose();
        _pinchController = PdfControllerPinch(
          document: PdfDocument.openData(Future.value(bytes)),
        );
      }

      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err;
        _loading = false;
      });
    }
  }

  Future<void> _saveToDevice() async {
    if (_isSaving || _pdfBytes == null) return;
    setState(() => _isSaving = true);

    final fileName = 'Invoice_${widget.bill.billNumber}';
    try {
      String? savedPath;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        savedPath = await FileSaver.instance.saveAs(
          name: fileName,
          bytes: _pdfBytes,
          fileExtension: 'pdf',
          mimeType: MimeType.pdf,
        );
      } else {
        savedPath = await FileSaver.instance.saveToDownloads(
          name: fileName,
          bytes: _pdfBytes,
          fileExtension: 'pdf',
          mimeType: MimeType.pdf,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1D1D1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  savedPath != null && savedPath.isNotEmpty
                      ? 'Saved $fileName.pdf to Downloads'
                      : '$fileName.pdf downloaded successfully.',
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text('Failed to save file: $err'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bill.billNumber,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Text(
              'PDF Invoice Document',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Save to Downloads',
            onPressed: _isSaving || _pdfBytes == null ? null : _saveToDevice,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF1C1C1E),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: AppleButton(
                label: 'Save to Downloads',
                icon: Icons.file_download_outlined,
                isLoading: _isSaving,
                onPressed: _isSaving || _pdfBytes == null ? null : _saveToDevice,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppleColors.blue),
            SizedBox(height: 14),
            Text(
              'Generating Apple-styled PDF invoice...',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      );
    }

    final hasController = _isDesktop ? _simpleController != null : _pinchController != null;
    if (_error != null || !hasController) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFFF453A)),
              const SizedBox(height: 12),
              const Text(
                'Could not load invoice PDF',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                '$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _initPdf,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final pageListenable = _isDesktop
        ? _simpleController!.pageListenable
        : _pinchController!.pageListenable;
    final pagesCount = _isDesktop
        ? _simpleController!.pagesCount
        : _pinchController!.pagesCount;

    return Stack(
      children: [
        Container(
          color: const Color(0xFF141416),
          child: _isDesktop
              ? PdfView(
                  controller: _simpleController!,
                  backgroundDecoration: const BoxDecoration(
                    color: Color(0xFF141416),
                  ),
                )
              : PdfViewPinch(
                  controller: _pinchController!,
                  backgroundDecoration: const BoxDecoration(
                    color: Color(0xFF141416),
                  ),
                ),
        ),
        // Floating Page Pill
        Positioned(
          right: 16,
          bottom: 16,
          child: ValueListenableBuilder<int>(
            valueListenable: pageListenable,
            builder: (context, page, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text(
                  pagesCount == null ? 'Page $page' : 'Page $page of $pagesCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
