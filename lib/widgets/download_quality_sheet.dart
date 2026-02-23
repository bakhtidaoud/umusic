import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/extraction_service.dart';
import '../controllers/download_controller.dart';
import '../utils/design_system.dart';

class DownloadQualitySheet extends StatefulWidget {
  final String url;
  final String title;

  const DownloadQualitySheet({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<DownloadQualitySheet> createState() => _DownloadQualitySheetState();
}

class _DownloadQualitySheetState extends State<DownloadQualitySheet> {
  final ExtractionService _extractionService = Get.find<ExtractionService>();
  final DownloadController _downloadController = Get.find<DownloadController>();

  UniversalMetadata? _metadata;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final meta = await _extractionService.getMetadata(widget.url);
      if (mounted) {
        setState(() {
          _metadata = meta;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? UDesign.darkSurface : UDesign.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(isDark),
          const Divider(height: 1, color: Colors.white10),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: _buildContent(context, isDark),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: UDesign.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.download_for_offline_rounded,
              color: UDesign.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Quality',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? UDesign.textHighDark
                        : UDesign.textHighLight,
                  ),
                ),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close_rounded, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    if (_isLoading) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: UDesign.primary,
                strokeWidth: 2,
              ),
              const SizedBox(height: 20),
              Text(
                'Fetching premium formats...',
                style: GoogleFonts.outfit(color: Colors.white38),
              ),
            ],
          ).animate().fadeIn(),
        ),
      );
    }

    if (_error != null || _metadata == null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load formats',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final formats = _metadata!.formats;
    final muxed = formats.where((f) => f.type == 'muxed').toList();
    final videoOnly = formats.where((f) => f.type == 'video').toList();
    final audioOnly = formats.where((f) => f.type == 'audio').toList();

    final sections = <Map<String, dynamic>>[];
    if (muxed.isNotEmpty) {
      sections.add({'title': 'Video + Audio (Recommended)', 'formats': muxed});
    }
    if (videoOnly.isNotEmpty) {
      sections.add({'title': 'Video Only', 'formats': videoOnly});
    }
    if (audioOnly.isNotEmpty) {
      sections.add({'title': 'Audio Only', 'formats': audioOnly});
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = sections[sectionIndex];
        final sectionFormats = section['formats'] as List<YtDlpFormat>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(section['title'] as String),
            ...sectionFormats.map((f) => _buildFormatTile(f, isDark)),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: UDesign.primary.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildFormatTile(YtDlpFormat format, bool isDark) {
    final sizeStr = format.filesizeMb != null
        ? '${format.filesizeMb!.toStringAsFixed(1)} MB'
        : 'Unknown size';

    final bitrateStr = format.bitrate != null
        ? '${(format.bitrate! / 1000).toStringAsFixed(0)} kbps'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _startDownload(format),
        borderRadius: BorderRadius.circular(16),
        child: UDesign.glassLayer(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: UDesign.glass(context: context, opacity: 0.03),
            child: Row(
              children: [
                _getFormatIcon(format),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            format.resolution ?? 'Native',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (format.isHdr) _buildTag('HDR', Colors.orange),
                          if (format.ext == 'webm' || format.ext == 'mp4')
                            const SizedBox(width: 4),
                          _buildTag(format.ext.toUpperCase(), Colors.blueGrey),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${format.codec ?? 'Unknown codec'} • $bitrateStr',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  sizeStr,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: UDesign.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _getFormatIcon(YtDlpFormat format) {
    IconData icon;
    Color color;

    if (format.type == 'audio') {
      icon = Icons.audiotrack_rounded;
      color = Colors.cyanAccent;
    } else if (format.type == 'video') {
      icon = Icons.videocam_off_rounded;
      color = Colors.blueAccent;
    } else {
      icon = Icons.video_library_rounded;
      color = UDesign.primary;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _startDownload(YtDlpFormat format) {
    final fileName =
        '${widget.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '')}.${format.ext}';

    _downloadController.downloadFile(
      widget.url,
      fileName: fileName,
      isYoutube: true,
      videoId: _metadata?.videoId,
      formatId: format.formatId,
      artist: _metadata?.artist,
      album: _metadata?.album,
      downloadThumbnail: true,
    );

    Get.back();
    Get.snackbar(
      'Download Started',
      'Added $fileName to queue',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black54,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
    );
  }
}
