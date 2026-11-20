import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/apple_ui.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../services/records_service.dart';

enum _PreviewKind { image, pdf, video, other }

/// In-app preview for an uploaded medical record file.
///
/// Images are streamed, PDFs are rendered with pdfx and videos play with
/// video_player. The download action saves the original file to the device's
/// Downloads folder (or a user-chosen location on iOS).
class FileViewerPage extends StatefulWidget {
  const FileViewerPage({
    super.key,
    required this.file,
    required this.url,
  });

  final MedicalRecordFileEntry file;

  /// Short-lived signed download URL from the clinic API.
  final String url;

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  late final _PreviewKind _kind = _resolveKind();

  PdfControllerPinch? _pdfController;
  bool _pdfLoading = false;
  Object? _pdfError;

  VideoPlayerController? _videoController;
  bool _videoLoading = false;
  Object? _videoError;

  bool _downloading = false;
  int _imageReload = 0;

  @override
  void initState() {
    super.initState();
    if (_kind == _PreviewKind.pdf) {
      _pdfLoading = true;
      _loadPdf(showSpinner: false);
    } else if (_kind == _PreviewKind.video) {
      _videoLoading = true;
      _initVideo(showSpinner: false);
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _pdfLoading = true;
        _pdfError = null;
      });
    }
    try {
      final response = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      if (!mounted) return;
      final controller = PdfControllerPinch(
        document: PdfDocument.openData(Future.value(response.bodyBytes)),
      );
      setState(() {
        _pdfController = controller;
        _pdfLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pdfLoading = false;
        _pdfError = error;
      });
    }
  }

  void _retryPdf() {
    final old = _pdfController;
    _pdfController = null;
    setState(() => _pdfError = null);
    old?.dispose();
    _loadPdf();
  }

  Future<void> _initVideo({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _videoLoading = true;
        _videoError = null;
      });
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _videoLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _videoLoading = false;
        _videoError = error;
      });
    }
  }

  void _retryVideo() {
    final old = _videoController;
    _videoController = null;
    setState(() => _videoError = null);
    old?.dispose();
    _initVideo();
  }

  void _togglePlay() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    final extension = _extensionOf(widget.file.fileName);
    final name = _baseNameOf(widget.file.fileName);
    final mime = _resolvedMime();

    try {
      String? savedPath;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        savedPath = await FileSaver.instance.saveAs(
          name: name,
          link: LinkDetails(link: widget.url),
          fileExtension: extension,
          mimeType: MimeType.custom,
          customMimeType: mime,
        );
      } else {
        savedPath = await FileSaver.instance.saveToDownloads(
          name: name,
          link: LinkDetails(link: widget.url),
          fileExtension: extension,
          mimeType: MimeType.custom,
          customMimeType: mime,
        );
      }
      if (!mounted) return;
      if (savedPath != null) {
        _showMessage('File downloaded to your device.');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not download this file. Please try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openExternally() async {
    final launched = await launchUrl(
      Uri.parse(widget.url),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!launched) {
      _showMessage('No app found to open this file.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _retryImage() {
    imageCache.evict(NetworkImage(widget.url));
    setState(() => _imageReload++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: AppleColors.textPrimary,
        foregroundColor: Colors.white,
        titleSpacing: 4,
        title: Text(
          widget.file.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Open in another app',
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
        bottom: _downloading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_kind) {
      case _PreviewKind.image:
        return _buildImage();
      case _PreviewKind.pdf:
        return _buildPdf();
      case _PreviewKind.video:
        return _buildVideo();
      case _PreviewKind.other:
        return _buildUnsupported();
    }
  }

  Widget _buildImage() {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.network(
          widget.url,
          key: ValueKey(_imageReload),
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            final total = progress.expectedTotalBytes;
            return Center(
              child: CircularProgressIndicator(
                value: total == null
                    ? null
                    : progress.cumulativeBytesLoaded / total,
                color: AppleColors.brandOnDark,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _ViewerMessage(
              icon: Icons.broken_image_outlined,
              message: 'Could not load this image.',
              onRetry: _retryImage,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPdf() {
    if (_pdfLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppleColors.brandOnDark),
      );
    }
    if (_pdfError != null || _pdfController == null) {
      return _ViewerMessage(
        icon: Icons.picture_as_pdf_outlined,
        message: 'Could not load this document.',
        onRetry: _retryPdf,
      );
    }

    final controller = _pdfController!;
    return Stack(
      children: [
        PdfViewPinch(controller: controller),
        Positioned(
          right: 14,
          bottom: 14,
          child: ValueListenableBuilder<int>(
            valueListenable: controller.pageListenable,
            builder: (context, page, _) {
              final total = controller.pagesCount;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  total == null ? 'Page $page' : 'Page $page of $total',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideo() {
    if (_videoLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppleColors.brandOnDark),
      );
    }
    final controller = _videoController;
    if (_videoError != null || controller == null) {
      return _ViewerMessage(
        icon: Icons.videocam_off_outlined,
        message: 'Could not play this video.',
        onRetry: _retryVideo,
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio <= 0
                ? 16 / 9
                : controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _togglePlay,
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: AppleColors.brandOnDark,
                              bufferedColor: Color(0xFF334155),
                              backgroundColor: AppleColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppleColors.border,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 56,
              color: AppleColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.file.fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Preview is not available for this file type. Download it or open it with another app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppleColors.border,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _downloading ? null : _download,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open with another app'),
            ),
          ],
        ),
      ),
    );
  }

  _PreviewKind _resolveKind() {
    final mime = (widget.file.mimeType ?? '').toLowerCase();
    final ext = _extensionOf(widget.file.fileName);

    const imageExts = {
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'tif',
      'tiff',
    };
    const videoExts = {'mp4', 'webm', 'mov', 'm4v', 'mkv', 'avi'};

    if (mime.startsWith('image/') || imageExts.contains(ext)) {
      return _PreviewKind.image;
    }
    if (mime == 'application/pdf' || ext == 'pdf') {
      return _PreviewKind.pdf;
    }
    if (mime.startsWith('video/') || videoExts.contains(ext)) {
      return _PreviewKind.video;
    }
    return _PreviewKind.other;
  }

  String _resolvedMime() {
    final mime = (widget.file.mimeType ?? '').trim();
    if (mime.isNotEmpty && mime != 'application/octet-stream') return mime;
    switch (_extensionOf(widget.file.fileName)) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppleColors.textTertiary),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppleColors.border),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppleColors.textSecondary),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _extensionOf(String name) {
  final index = name.lastIndexOf('.');
  if (index <= 0 || index == name.length - 1) return '';
  return name.substring(index + 1).toLowerCase();
}

String _baseNameOf(String name) {
  final index = name.lastIndexOf('.');
  if (index <= 0) return name;
  return name.substring(0, index);
}

String _formatDuration(Duration duration) {
  final total = duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
