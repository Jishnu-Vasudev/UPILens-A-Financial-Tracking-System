import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/providers.dart';
import '../../services/llm_service.dart';
import '../../services/sms_service.dart';
import '../../services/transaction_processor.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;
  String _modelSize = 'Unknown';
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final llm = LlmService();
    final ready = await llm.isModelReady();
    String sizeStr = 'Not found';
    if (ready) {
      final path = await llm.getModelPath();
      final size = await File(path).length();
      sizeStr = '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (mounted) {
      setState(() {
        _modelReady = ready;
        _modelSize = sizeStr;
      });
    }
  }

  Future<void> _deleteModel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete AI Model?'),
        content: const Text('This will free up ~800MB of storage. You will need to re-download it to use local AI features.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final path = await LlmService().getModelPath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        LlmService().dispose();
      }
      await _checkModelStatus();
    }
  }

  Future<void> _reSyncSms() async {
    setState(() => _syncing = true);
    try {
      final smsList = await SmsService().getSmsHistory();
      final count = await TransactionProcessor().processBatch(smsList);
      ref.invalidate(transactionsProvider);
      ref.invalidate(monthlyTotalsProvider);
      ref.invalidate(categoryTotalsProvider);
      ref.invalidate(topMerchantsProvider);
      ref.invalidate(monthlyTrendsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced $count new transactions'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will permanently delete all saved transactions. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(databaseHelperProvider).clearAll();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('insight_')).toList();
    for (final k in keys) await prefs.remove(k);

    ref.invalidate(transactionsProvider);
    ref.invalidate(monthlyTotalsProvider);
    ref.invalidate(categoryTotalsProvider);
    ref.invalidate(topMerchantsProvider);
    ref.invalidate(monthlyTrendsProvider);
    ref.invalidate(insightSummaryProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Settings'), centerTitle: false),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                
                _SectionHeader('Local AI Model'),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.auto_awesome, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('On-device LLM', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
                              const Text('Status: Coming soon', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ]),
                          ),
                        ]),
                        const Divider(height: 24),
                        const Text(
                          'AI summaries and automated classification will be available in the next release.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _SectionHeader('SMS & Data'),
                _SettingsTile(
                  icon: Icons.sync,
                  title: 'Re-sync SMS',
                  subtitle: 'Scan inbox for the last 90 days',
                  trailing: _syncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: _syncing ? null : _reSyncSms,
                ),
                FutureBuilder<PermissionStatus>(
                  future: Permission.sms.status,
                  builder: (ctx, snap) {
                    final granted = snap.data?.isGranted ?? false;
                    return _SettingsTile(
                      icon: Icons.sms,
                      title: 'SMS Permission',
                      subtitle: granted ? 'Granted' : 'Not granted — tap to request',
                      iconColor: granted ? Colors.green : theme.colorScheme.error,
                      trailing: granted
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : Icon(Icons.error_outline, color: theme.colorScheme.error),
                      onTap: granted ? null : () => Permission.sms.request().then((_) => setState(() {})),
                    );
                  },
                ),
                const SizedBox(height: 24),

                _SectionHeader('Danger Zone'),
                _SettingsTile(
                  icon: Icons.delete_outline,
                  title: 'Clear All Data',
                  subtitle: 'Delete all saved transactions and insights',
                  iconColor: theme.colorScheme.error,
                  trailing: Icon(Icons.chevron_right, color: theme.colorScheme.error),
                  onTap: _clearData,
                ),
                const SizedBox(height: 40),

                Center(child: Text('UPI Lens v1.0 · Privacy-first · Fully Local AI',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
    )),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle,
    required this.trailing, this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
