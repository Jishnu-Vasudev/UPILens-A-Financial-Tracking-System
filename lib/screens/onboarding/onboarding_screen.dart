import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../providers/providers.dart';
import '../../services/llm_service.dart';
import '../../services/sms_service.dart';
import '../../services/rule_classifier.dart';
import '../../services/transaction_processor.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _smsGranted = false;
  bool _syncing = false;
  
  final String _modelUrl = 'https://huggingface.co/lmstudio-community/gemma-3-1B-it-GGUF/resolve/main/gemma-3-1B-it-Q4_K_M.gguf';

  Future<void> _requestSmsPermission() async {
    final status = await Permission.sms.request();
    setState(() => _smsGranted = status.isGranted);
    if (status.isGranted) {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _step = 1);
    }
  }

  Future<void> _downloadModel() async {
    final status = ref.read(modelDownloadStatusProvider);
    if (status == DownloadStatus.downloading) return;

    final llm = LlmService();
    if (await llm.isModelReady()) {
      ref.read(modelDownloadStatusProvider.notifier).state = DownloadStatus.complete;
      return;
    }

    ref.read(modelDownloadStatusProvider.notifier).state = DownloadStatus.downloading;
    ref.read(modelDownloadProgressProvider.notifier).state = 0.0;
    
    final path = await llm.getModelPath();
    final file = File(path);
    
    // Ensure dir exists
    await file.parent.create(recursive: true);

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_modelUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      int downloaded = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        downloaded += chunk.length;
        sink.add(chunk);
        
        final progress = total > 0 ? (downloaded / total) : 0.0;
        ref.read(modelDownloadProgressProvider.notifier).state = progress;
        
        final mbDown = (downloaded / (1024 * 1024)).toStringAsFixed(0);
        final mbTotal = (total / (1024 * 1024)).toStringAsFixed(0);
        ref.read(modelDownloadMessageProvider.notifier).state = '$mbDown MB / $mbTotal MB';
      }

      await sink.close();
      client.close();

      if (await llm.isModelReady()) {
        ref.read(modelDownloadStatusProvider.notifier).state = DownloadStatus.complete;
      } else {
        throw Exception('Download finished but file size is incorrect.');
      }
    } catch (e) {
      if (await file.exists()) await file.delete();
      ref.read(modelDownloadStatusProvider.notifier).state = DownloadStatus.error;
      ref.read(modelDownloadMessageProvider.notifier).state = 'Error: ${e.toString()}';
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _syncing = true);
    await RuleClassifier().initialize();
    final smsList = await SmsService().getSmsHistory();
    await TransactionProcessor().processBatch(smsList);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _step == 0 ? _buildSmsStep() : _buildModelStep(),
        ),
      ),
    );
  }

  Widget _buildSmsStep() {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('sms'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepIcon(icon: Icons.sms_outlined, colors: [theme.colorScheme.primary, theme.colorScheme.tertiary]),
          const SizedBox(height: 40),
          Text('Read Your UPI SMS', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            'UPI Lens reads your bank SMS messages to automatically track UPI transactions. Your messages never leave your device.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: _requestSmsPermission,
            icon: const Icon(Icons.mobile_screen_share),
            label: const Text('Grant SMS Access'),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: () => setState(() => _step = 1), child: const Text('Skip for now')),
        ],
      ),
    );
  }

  Widget _buildModelStep() {
    final theme = Theme.of(context);
    final status = ref.watch(modelDownloadStatusProvider);
    final progress = ref.watch(modelDownloadProgressProvider);
    final message = ref.watch(modelDownloadMessageProvider);

    return Padding(
      key: const ValueKey('model'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepIcon(icon: Icons.auto_awesome, colors: [theme.colorScheme.secondary, theme.colorScheme.tertiary]),
          const SizedBox(height: 40),
          Text('On-Device AI', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            'UPI Lens uses Gemma 3-1B for private, offline transaction analysis. The model is approximately 800 MB.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          
          if (status == DownloadStatus.idle)
            FilledButton.icon(
              onPressed: _downloadModel,
              icon: const Icon(Icons.download),
              label: const Text('Download AI Model (800 MB)'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            )
          else if (status == DownloadStatus.downloading)
            Column(children: [
              LinearProgressIndicator(value: progress, borderRadius: BorderRadius.circular(8), minHeight: 10),
              const SizedBox(height: 12),
              Text(message, style: theme.textTheme.bodyMedium),
            ])
          else if (status == DownloadStatus.complete)
            Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text('AI Model Ready', style: theme.textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _syncing ? null : _finishOnboarding,
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                child: _syncing ? const CircularProgressIndicator(color: Colors.white) : const Text('Get Started'),
              ),
            ])
          else if (status == DownloadStatus.error)
            Column(children: [
              Text(message, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _downloadModel,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Download'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              ),
            ],
          ),
          
          if (status != DownloadStatus.complete) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _syncing ? null : _finishOnboarding,
              child: const Text('Skip — use rule-based classifier only'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  const _StepIcon({required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Icon(icon, size: 60, color: Colors.white),
    );
  }
}
