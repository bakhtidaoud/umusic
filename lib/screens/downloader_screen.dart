import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/extraction_service.dart';
import '../controllers/config_controller.dart';
import '../controllers/download_controller.dart';
import '../utils/design_system.dart';

class DownloaderScreen extends StatefulWidget {
  final String? initialUrl;
  const DownloaderScreen({super.key, this.initialUrl});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  UniversalMetadata? _currentMetadata;
  bool _isLoading = false;
  String _selectedFormatType = 'video';
  YtDlpFormat? _selectedQuality;
  bool _downloadSubtitles = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMetadata());
    }
  }

  Future<void> _fetchMetadata() async {
    if (_urlController.text.isEmpty) return;
    setState(() => _isLoading = true);
    final extService = Get.find<ExtractionService>();
    final configController = Get.find<ConfigController>();
    final meta = await extService.getMetadata(_urlController.text);
    setState(() {
      _currentMetadata = meta;
      _isLoading = false;
      if (meta != null && meta.formats.isNotEmpty) {
        if (configController.config.smartModeEnabled &&
            configController.config.lastFormatType != null &&
            configController.config.lastQualityId != null) {
          _selectedFormatType = configController.config.lastFormatType!;
          final lastId = configController.config.lastQualityId;
          _selectedQuality = meta.formats.firstWhere(
            (f) => f.formatId == lastId || f.resolution == lastId,
            orElse: () => meta.formats.first,
          );
          _startDownload();
        } else {
          _selectedQuality = meta.formats.first;
        }
      }
    });
  }

  void _startDownload() {
    if (_currentMetadata == null || _selectedQuality == null) return;
    final downloadController = Get.find<DownloadController>();
    final configController = Get.find<ConfigController>();

    configController.setLastSettings(
      _selectedFormatType,
      _selectedQuality!.formatId,
    );

    downloadController.downloadFile(
      _currentMetadata!.originalUrl,
      fileName: '${_currentMetadata!.title}.${_selectedQuality!.ext}',
      downloadSubtitles: _downloadSubtitles,
      isYoutube: _currentMetadata!.isYoutube,
      videoId: _currentMetadata!.videoId,
    );

    Get.snackbar(
      'Download Started',
      _currentMetadata!.title,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black54,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadController = Get.find<DownloadController>();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInputSection(context),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          if (_currentMetadata != null) _buildMetadataCard(context),
          _buildDownloadsList(context, downloadController),
          Obx(() {
            if (_currentMetadata == null &&
                !_isLoading &&
                downloadController.tasks.isEmpty) {
              return Column(
                children: [
                  const SizedBox(height: 60),
                  Animate(
                    effects: const [
                      FadeEffect(duration: Duration(seconds: 1)),
                      ScaleEffect(
                        begin: Offset(0.8, 0.8),
                        duration: Duration(seconds: 1),
                      ),
                    ],
                    child: Center(
                      child: Opacity(
                        opacity: 0.1,
                        child: SvgPicture.asset(
                          'assets/app_icon.svg',
                          width: 200,
                          colorFilter: ColorFilter.mode(
                            isDark ? Colors.white : Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildInputSection(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return UDesign.glassLayer(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: UDesign.glass(context: context),
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.link_rounded, color: UDesign.primary),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _urlController,
                style: GoogleFonts.outfit(
                  color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Paste video URL here...',
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.outfit(
                    color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
                  ),
                ),
                onSubmitted: (_) => _fetchMetadata(),
              ),
            ),
            IconButton.filled(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  _urlController.text = data!.text!;
                  _fetchMetadata();
                }
              },
              style: IconButton.styleFrom(
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                foregroundColor: UDesign.primary,
              ),
              icon: const Icon(Icons.content_paste_rounded),
              tooltip: 'Paste',
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _fetchMetadata,
              style: IconButton.styleFrom(backgroundColor: UDesign.primary),
              icon: const Icon(Icons.analytics_rounded),
              tooltip: 'Analyze',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: UDesign.glassLayer(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          decoration: UDesign.glass(
            context: context,
          ).copyWith(boxShadow: UDesign.softShadow(context)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (_currentMetadata!.thumbnailUrl != null)
                Image.network(
                  _currentMetadata!.thumbnailUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentMetadata!.title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? UDesign.textHighDark
                            : UDesign.textHighLight,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentMetadata!.author ?? 'Unknown Author',
                      style: GoogleFonts.outfit(
                        color: isDark
                            ? UDesign.textMedDark
                            : UDesign.textMedLight,
                        fontSize: 14,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(color: Colors.white12),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<YtDlpFormat>(
                                value: _selectedQuality,
                                isExpanded: true,
                                dropdownColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                style: GoogleFonts.outfit(
                                  color: isDark
                                      ? UDesign.textHighDark
                                      : UDesign.textHighLight,
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: UDesign.primary,
                                ),
                                items: _currentMetadata!.formats.map((f) {
                                  return DropdownMenuItem(
                                    value: f,
                                    child: Text(
                                      '${f.resolution ?? ''} (${f.ext}) ${f.filesizeMb?.toStringAsFixed(1) ?? ''} MB',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedQuality = val),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _startDownload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UDesign.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildDownloadsList(
    BuildContext context,
    DownloadController controller,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      if (controller.tasks.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Active Downloads',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
              ),
            ),
          ),
          ...controller.tasks.values
              .map((task) => _buildTaskTile(context, task, controller))
              .toList(),
        ],
      );
    });
  }

  Widget _buildTaskTile(
    BuildContext context,
    DownloadTask task,
    DownloadController controller,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UDesign.glassLayer(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: UDesign.glass(context: context),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            title: Text(
              task.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
              ),
            ),
            subtitle: Obx(
              () => Column(
                children: [
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: task.progress.value,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        UDesign.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(task.progress.value * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: isDark
                              ? UDesign.textMedDark
                              : UDesign.textMedLight,
                        ),
                      ),
                      if (task.status.value == DownloadStatus.downloading)
                        Text(
                          '${_formatSpeed(task.transferRate.value)} MB/s',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: UDesign.primary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: Obx(
              () => IconButton(
                icon: Icon(
                  task.status.value == DownloadStatus.completed
                      ? Icons.check_circle_rounded
                      : Icons.close_rounded,
                  color: task.status.value == DownloadStatus.completed
                      ? Colors.greenAccent
                      : (isDark ? UDesign.textMedDark : UDesign.textMedLight),
                ),
                onPressed: () => controller.cancelDownload(task.url),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatSpeed(double bytesPerSec) {
    return (bytesPerSec / 1024 / 1024).toStringAsFixed(2);
  }
}
