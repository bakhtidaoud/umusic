import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/download_service.dart';
import '../services/extraction_service.dart';
import '../services/config_service.dart';

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
    final extService = Provider.of<ExtractionService>(context, listen: false);
    final configService = Provider.of<ConfigService>(context, listen: false);
    final meta = await extService.getMetadata(_urlController.text);
    setState(() {
      _currentMetadata = meta;
      _isLoading = false;
      if (meta != null && meta.formats.isNotEmpty) {
        if (configService.config.smartModeEnabled &&
            configService.config.lastFormatType != null &&
            configService.config.lastQualityId != null) {
          _selectedFormatType = configService.config.lastFormatType!;
          final lastId = configService.config.lastQualityId;
          _selectedQuality = meta.formats.firstWhere(
            (f) => f.formatId == lastId || f.resolution == lastId,
            orElse: () => meta.formats.first,
          );
          _startDownload(context);
        } else {
          _selectedQuality = meta.formats.first;
        }
      }
    });
  }

  void _startDownload(BuildContext context) {
    if (_currentMetadata == null || _selectedQuality == null) return;
    final downloadService = Provider.of<DownloadService>(
      context,
      listen: false,
    );
    final configService = Provider.of<ConfigService>(context, listen: false);

    configService.setLastSettings(
      _selectedFormatType,
      _selectedQuality!.formatId ?? _selectedQuality!.resolution ?? 'best',
    );

    downloadService.downloadFile(
      _getDownloadUrl(),
      fileName: '${_currentMetadata!.title}.${_selectedQuality!.ext}',
      downloadSubtitles: _downloadSubtitles,
      isYoutube: _currentMetadata!.isYoutube,
      videoId: _currentMetadata!.videoId,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting download: ${_currentMetadata!.title}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getDownloadUrl() {
    // Logic from original main.dart
    return _currentMetadata!.originalUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloadService = Provider.of<DownloadService>(context);

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
          _buildDownloadsList(context, downloadService),

          if (_currentMetadata == null &&
              !_isLoading &&
              downloadService.tasks.isEmpty) ...[
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
                  child: SvgPicture.asset('assets/app_icon.svg', width: 200),
                ),
              ),
            ),
          ],
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
                      onPressed: () => _startDownload(context),
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

  Widget _buildDownloadsList(BuildContext context, DownloadService service) {
    if (service.tasks.isEmpty) return const SizedBox.shrink();

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
        ...service.tasks.values
            .map((task) => _buildTaskTile(context, task, service))
            .toList(),
      ],
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    DownloadTask task,
    DownloadService service,
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
        subtitle: Column(
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(task.progress * 100).toStringAsFixed(1)}%'),
                if (task.status == DownloadStatus.downloading)
                  Text(
                    '${(task.transferRate / 1024 / 1024).toStringAsFixed(2)} MB/s',
                  ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            task.status == DownloadStatus.completed
                ? Icons.check_circle
                : Icons.cancel,
          ),
          onPressed: () => service.cancelDownload(task.url),
        ),
      ),
    );
  }
}
