import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/extraction_service.dart';
import '../controllers/config_controller.dart';
import '../controllers/download_controller.dart';

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
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'Paste video URL here...',
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.outfit(),
                ),
                onSubmitted: (_) => _fetchMetadata(),
              ),
            ),
            IconButton.filled(
              onPressed: _fetchMetadata,
              icon: const Icon(Icons.analytics_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentMetadata!.title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _currentMetadata!.author ?? 'Unknown Author',
                  style: theme.textTheme.bodyMedium,
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<YtDlpFormat>(
                        value: _selectedQuality,
                        isExpanded: true,
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
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _startDownload,
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildDownloadsList(
    BuildContext context,
    DownloadController controller,
  ) {
    return Obx(() {
      if (controller.tasks.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Active Downloads',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(
          task.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Obx(
          () => Column(
            children: [
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.progress.value,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(task.progress.value * 100).toStringAsFixed(1)}%'),
                  if (task.status.value == DownloadStatus.downloading)
                    Text('${_formatSpeed(task.transferRate.value)} MB/s'),
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
                  : Icons.cancel_rounded,
              color: task.status.value == DownloadStatus.completed
                  ? Colors.green
                  : Colors.grey,
            ),
            onPressed: () => controller.cancelDownload(task.url),
          ),
        ),
      ),
    );
  }

  String _formatSpeed(double bytesPerSec) {
    return (bytesPerSec / 1024 / 1024).toStringAsFixed(2);
  }
}
