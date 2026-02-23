import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../controllers/subscription_controller.dart';
import '../models/subscription.dart';
import '../utils/design_system.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final TextEditingController _urlController = TextEditingController();

  void _addSubscription() {
    if (_urlController.text.isEmpty) return;
    Get.find<SubscriptionController>().addSubscription(_urlController.text);
    _urlController.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final subController = Get.find<SubscriptionController>();
    return Obx(
      () => Scaffold(
        body: Column(
          children: [
            _buildActionHeader(context, subController),
            if (subController.newDownloadsCount.value > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child:
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: UDesign.premiumGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: UDesign.softShadow(context),
                      ),
                      child: Text(
                        '🎉 Found ${subController.newDownloadsCount.value} new videos!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ).animate().shimmer().scale(
                      begin: const Offset(0.9, 0.9),
                      duration: const Duration(milliseconds: 400),
                    ),
              ),
            Expanded(
              child: subController.subscriptions.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: subController.subscriptions.length,
                      itemBuilder: (context, index) {
                        final sub = subController.subscriptions[index];
                        return _buildSubscriptionCard(
                              context,
                              sub,
                              subController,
                            )
                            .animate()
                            .fadeIn(delay: (index * 50).ms)
                            .slideY(
                              begin: 0.1,
                              duration: const Duration(milliseconds: 400),
                            );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionHeader(
    BuildContext context,
    SubscriptionController subController,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(boxShadow: UDesign.softShadow(context)),
              child: ElevatedButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Track Content',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UDesign.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          UDesign.glassLayer(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: UDesign.glass(context: context),
              child: IconButton(
                onPressed: () => subController.checkNewContent(),
                padding: const EdgeInsets.all(16),
                icon: subController.isChecking.value
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: UDesign.primary,
                        ),
                      )
                    : const Icon(Icons.sync_rounded, color: UDesign.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.subscriptions_rounded,
            size: 100,
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
          ),
          const SizedBox(height: 24),
          Text(
            'No content tracks yet',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a channel or playlist to track updates',
            style: GoogleFonts.outfit(
              color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    Subscription sub,
    SubscriptionController controller,
  ) {
    final dateFormat = DateFormat('MMM dd, HH:mm');
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: UDesign.glassLayer(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: UDesign.glass(context: context),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            title: Text(
              sub.title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  sub.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: UDesign.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 14,
                        color: UDesign.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Last checked: ${dateFormat.format(sub.lastChecked)}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: UDesign.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              onPressed: () => controller.removeSubscription(sub.url),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Text(
          'Track Content',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
          ),
        ),
        content: TextField(
          controller: _urlController,
          style: GoogleFonts.outfit(
            color: isDark ? UDesign.textHighDark : UDesign.textHighLight,
          ),
          decoration: InputDecoration(
            hintText: 'Channel or Playlist URL',
            hintStyle: GoogleFonts.outfit(
              color: isDark ? UDesign.textMedDark : UDesign.textMedLight,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          autofocus: true,
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
            onPressed: _addSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: UDesign.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'Track',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
