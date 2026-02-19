import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/config_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    final config = configService.config;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'General'),
          _buildListTile(
            context,
            title: 'Download Folder',
            subtitle: config.downloadFolder ?? 'Default',
            icon: Icons.folder_open,
            onTap: () async {
              String? selectedDirectory = await FilePicker.platform
                  .getDirectoryPath();
              if (selectedDirectory != null) {
                configService.setDownloadFolder(selectedDirectory);
              }
            },
          ),
          _buildSliderTile(
            context,
            title: 'Max Concurrent Downloads',
            value: config.maxConcurrentDownloads.toDouble(),
            min: 1,
            max: 10,
            onChanged: (val) {
              configService.setMaxConcurrentDownloads(val.toInt());
            },
          ),

          _buildSectionHeader(context, 'Formats'),
          _buildDropdownTile<String>(
            context,
            title: 'Preferred Video Codec',
            value: config.preferredVideoCodec,
            items: const [
              DropdownMenuItem(
                value: 'h264',
                child: Text('H.264 (Most Compatible)'),
              ),
              DropdownMenuItem(
                value: 'vp9',
                child: Text('VP9 (Better Quality)'),
              ),
              DropdownMenuItem(
                value: 'av1',
                child: Text('AV1 (Most Efficient)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                configService.updateConfig(
                  config.copyWith(preferredVideoCodec: val),
                );
              }
            },
          ),
          _buildDropdownTile<String>(
            context,
            title: 'Audio Quality',
            value: config.preferredAudioQuality,
            items: const [
              DropdownMenuItem(value: 'best', child: Text('Best Available')),
              DropdownMenuItem(value: '320k', child: Text('320 kbps')),
              DropdownMenuItem(value: '192k', child: Text('192 kbps')),
              DropdownMenuItem(value: '128k', child: Text('128 kbps')),
            ],
            onChanged: (val) {
              if (val != null) {
                configService.updateConfig(
                  config.copyWith(preferredAudioQuality: val),
                );
              }
            },
          ),

          _buildSectionHeader(context, 'Network'),
          _buildTextFieldTile(
            context,
            initialValue: config.proxySettings,
            title: 'Proxy Settings',
            hint: 'host:port',
            onChanged: (val) {
              configService.setProxySettings(val.isEmpty ? null : val);
            },
          ),
          _buildSliderTile(
            context,
            title: 'Network Timeout (s)',
            value: config.networkTimeout.toDouble(),
            min: 5,
            max: 120,
            onChanged: (val) {
              configService.updateConfig(
                config.copyWith(networkTimeout: val.toInt()),
              );
            },
          ),

          _buildSectionHeader(context, 'Advanced'),
          _buildTextFieldTile(
            context,
            initialValue: config.cookiesFile,
            title: 'Cookies File Path',
            hint: '/path/to/cookies.txt',
            onChanged: (val) {
              configService.updateConfig(
                config.copyWith(cookiesFile: val.isEmpty ? null : val),
              );
            },
          ),
          _buildTextFieldTile(
            context,
            initialValue: config.archiveFile,
            title: 'Archive File Path',
            hint: '/path/to/archive.txt',
            onChanged: (val) {
              configService.updateConfig(
                config.copyWith(archiveFile: val.isEmpty ? null : val),
              );
            },
          ),
          _buildSectionHeader(context, 'Appearance'),
          _buildDropdownTile<String>(
            context,
            title: 'Theme Mode',
            value: config.themeMode,
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
            ],
            onChanged: (val) {
              if (val != null) {
                configService.setThemeMode(val);
              }
            },
          ),

          _buildSectionHeader(context, 'Experimental'),
          SwitchListTile(
            title: const Text('Enable DRM Decryption Research'),
            subtitle: const Text(
              'EXPERIMENTAL: Widevine L3 decryption support.',
            ),
            value: config.enableExperimentalDRM,
            onChanged: (val) {
              if (val) {
                _showDRMWarning(context, configService);
              } else {
                configService.updateConfig(
                  config.copyWith(enableExperimentalDRM: false),
                );
              }
            },
          ),
          if (config.enableExperimentalDRM)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Research Notes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Widevine L3: Software-based, vulnerable to key extraction via intercepted CDMs.\n'
                      '• Android: ExoPlayer MediaDrm can be used for session key acquisition.\n'
                      '• Legal: Decryption may violate DMCA or regional copyright laws. For research only.',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      leading: Icon(icon),
      onTap: onTap,
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(title),
          trailing: Text(
            value.toInt().toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownTile<T>(
    BuildContext context, {
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextFieldTile(
    BuildContext context, {
    String? initialValue,
    required String title,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: TextFormField(
          initialValue: initialValue,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showDRMWarning(BuildContext context, ConfigService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Legal & Security Warning'),
        content: const Text(
          'Enabling DRM decryption is for educational and research purposes only.\n\n'
          'Technically, this attempts to utilize CDM (Content Decryption Module) hooks or ExoPlayer DRM sessions to extract decryption keys. '
          'Decrypting protected content may violate Terms of Service and local laws.\n\n'
          'Proceed only if you understand the legal implications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              service.updateConfig(
                service.config.copyWith(enableExperimentalDRM: true),
              );
              Navigator.pop(context);
            },
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}
