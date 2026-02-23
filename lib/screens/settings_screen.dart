import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/config_controller.dart';
import '../utils/design_system.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final configController = Get.find<ConfigController>();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final config = configController.config;

      return Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionHeader(context, 'General'),
            _buildSettingCard(
              context,
              child: _buildListTile(
                context,
                title: 'Download Folder',
                subtitle: config.downloadFolder ?? 'Default',
                icon: Icons.folder_open_rounded,
                onTap: () async {
                  String? selectedDirectory = await FilePicker.platform
                      .getDirectoryPath();
                  if (selectedDirectory != null) {
                    configController.setDownloadFolder(selectedDirectory);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingCard(
              context,
              child: _buildSliderTile(
                context,
                title: 'Max Concurrent Downloads',
                value: config.maxConcurrentDownloads.toDouble(),
                min: 1,
                max: 10,
                onChanged: (val) {
                  configController.setMaxConcurrentDownloads(val.toInt());
                },
              ),
            ),
            _buildSectionHeader(context, 'Formats'),
            _buildSettingCard(
              context,
              child: Column(
                children: [
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
                        configController.updateConfig(
                          config.copyWith(preferredVideoCodec: val),
                        );
                      }
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),
                  _buildDropdownTile<String>(
                    context,
                    title: 'Audio Quality',
                    value: config.preferredAudioQuality,
                    items: const [
                      DropdownMenuItem(
                        value: 'best',
                        child: Text('Best Available'),
                      ),
                      DropdownMenuItem(value: '320k', child: Text('320 kbps')),
                      DropdownMenuItem(value: '192k', child: Text('192 kbps')),
                      DropdownMenuItem(value: '128k', child: Text('128 kbps')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        configController.updateConfig(
                          config.copyWith(preferredAudioQuality: val),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            _buildSectionHeader(context, 'Network'),
            _buildSettingCard(
              context,
              child: Column(
                children: [
                  _buildTextFieldTile(
                    context,
                    initialValue: config.proxySettings,
                    title: 'Proxy Settings',
                    hint: 'host:port',
                    onChanged: (val) {
                      configController.setProxySettings(
                        val.isEmpty ? null : val,
                      );
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16, height: 1),
                  _buildSliderTile(
                    context,
                    title: 'Network Timeout',
                    label: '${config.networkTimeout}s',
                    value: config.networkTimeout.toDouble(),
                    min: 5,
                    max: 120,
                    onChanged: (val) {
                      configController.updateConfig(
                        config.copyWith(networkTimeout: val.toInt()),
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildSectionHeader(context, 'Advanced'),
            _buildSettingCard(
              context,
              child: Column(
                children: [
                  _buildTextFieldTile(
                    context,
                    initialValue: config.cookiesFile,
                    title: 'Cookies File Path',
                    hint: '/path/to/cookies.txt',
                    onChanged: (val) {
                      configController.updateConfig(
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
                      configController.updateConfig(
                        config.copyWith(archiveFile: val.isEmpty ? null : val),
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildSectionHeader(context, 'Appearance'),
            _buildSettingCard(
              context,
              child: _buildDropdownTile<String>(
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
                    configController.setThemeMode(val);
                  }
                },
              ),
            ),
            _buildSectionHeader(context, 'Experimental'),
            _buildSettingCard(
              context,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'DRM Research',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? UDesign.textHighDark
                            : UDesign.textHighLight,
                      ),
                    ),
                    subtitle: Text(
                      'EXPERIMENTAL: Widevine L3 decryption.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark
                            ? UDesign.textMedDark
                            : UDesign.textMedLight,
                      ),
                    ),
                    value: config.enableExperimentalDRM,
                    activeColor: UDesign.primary,
                    onChanged: (val) {
                      if (val) {
                        _showDRMWarning(context, configController);
                      } else {
                        configController.updateConfig(
                          config.copyWith(enableExperimentalDRM: false),
                        );
                      }
                    },
                  ),
                  if (config.enableExperimentalDRM)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: UDesign.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: UDesign.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: UDesign.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Research Notes',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: UDesign.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Widevine L3: Software-based, vulnerable to key extraction.\n'
                              '• Legal: Decryption may violate regional copyright laws.',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: isDark
                                    ? UDesign.textMedDark
                                    : UDesign.textMedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      );
    });
  }

  Widget _buildSettingCard(BuildContext context, {required Widget child}) {
    return UDesign.glassLayer(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: UDesign.glass(context: context),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 32, 8, 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          color: UDesign.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
        ),
      ),
      leading: Icon(icon, color: UDesign.primary),
      onTap: onTap,
    );
  }

  Widget _buildSliderTile(
    BuildContext context, {
    required String title,
    String? label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
              ),
            ),
            trailing: Text(
              label ?? value.toInt().toString(),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: UDesign.primary,
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: UDesign.primary,
              inactiveColor: isDark ? Colors.white12 : Colors.black12,
              divisions: (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile<T>(
    BuildContext context, {
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
        ),
      ),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: Theme.of(context).colorScheme.surface,
          style: GoogleFonts.outfit(
            color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
          ),
          items: items,
          onChanged: onChanged,
        ),
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: initialValue,
            style: GoogleFonts.outfit(
              color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showDRMWarning(BuildContext context, ConfigController controller) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Text(
          '⚠️ Security Warning',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'DRM decryption research is for educational purposes only.\n\nLegal implications vary by region.',
          style: GoogleFonts.outfit(
            color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              controller.updateConfig(
                controller.config.copyWith(enableExperimentalDRM: true),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Accept',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
