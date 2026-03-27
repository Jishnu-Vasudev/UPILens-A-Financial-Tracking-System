import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import '../services/llm_service.dart';
import '../services/rule_classifier.dart';
import '../services/sms_service.dart';
import '../services/transaction_processor.dart';
import '../services/fund_leak_detector_service.dart';

// ── Singleton service providers ────────────────────────────────────────────

final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper());
final smsServiceProvider = Provider<SmsService>((ref) => SmsService());
final llmServiceProvider = Provider<LlmService>((ref) => LlmService());
final ruleClassifierProvider = Provider<RuleClassifier>((ref) => RuleClassifier());
final transactionProcessorProvider = Provider<TransactionProcessor>((ref) => TransactionProcessor());
final fundLeakDetectorProvider = Provider<FundLeakDetector>((ref) => FundLeakDetector());

// ── Data providers ─────────────────────────────────────────────────────────

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return db.getAllTransactions();
});

final monthlyTotalsProvider = FutureProvider<Map<String, double>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return db.getMonthlyTotals();
});

final categoryTotalsProvider = FutureProvider<Map<String, double>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return db.getCategoryTotalsThisMonth();
});

final topMerchantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return db.getTopMerchants(limit: 5);
});

final monthlyTrendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  return db.getMonthlyTrends(months: 6);
});

final fundLeaksProvider = FutureProvider<List<LeakResult>>((ref) async {
  final detector = ref.watch(fundLeakDetectorProvider);
  return detector.detectLeaks();
});

// ── Insight summary ────────────────────────────────────────────────────────

final insightSummaryProvider = FutureProvider<String>((ref) async {
  final db = ref.watch(databaseHelperProvider);
  
  final categoryTotals = await db.getCategoryTotalsThisMonth();
  final weeklyComp = await db.getWeeklySpendComparison();
  final topMerchantRow = await db.getTopMerchantThisMonth();
  
  if (categoryTotals.isEmpty) {
    return '- No transactions recorded this month yet.\n- Sync your SMS to start tracking UPI spends.\n- Insights will appear once data is available.';
  }

  final bullets = <String>[];

  // 1. Top Category
  final sorted = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  bullets.add('- Your highest spend is on ${sorted.first.key}, totaling ₹${sorted.first.value.toStringAsFixed(0)} this month.');

  // 2. Week-over-week change
  final thisWeek = weeklyComp['thisWeek'] ?? 0;
  final lastWeek = weeklyComp['lastWeek'] ?? 0;
  if (lastWeek > 0) {
    final percent = ((thisWeek - lastWeek) / lastWeek * 100).abs();
    final direction = thisWeek > lastWeek ? 'up' : 'down';
    bullets.add('- Weekly spend is $direction by ${percent.toStringAsFixed(1)}% compared to last week (₹${thisWeek.toStringAsFixed(0)} vs ₹${lastWeek.toStringAsFixed(0)}).');
  } else {
    bullets.add('- You spent ₹${thisWeek.toStringAsFixed(0)} this week. Keep tracking to see weekly trends.');
  }

  // 3. Top Merchant
  if (topMerchantRow != null) {
    bullets.add('- Most frequent merchant is ${topMerchantRow['merchantName']} with ₹${(topMerchantRow['total'] as num).toStringAsFixed(0)} in payments.');
  } else {
    bullets.add('- AI summaries will be available once on-device model support is added in the next release.');
  }

  return bullets.join('\n');
});

// ── Model Download Status ──────────────────────────────────────────────────

enum DownloadStatus { idle, downloading, error, complete }

final modelDownloadStatusProvider = StateProvider<DownloadStatus>((ref) => DownloadStatus.idle);
final modelDownloadProgressProvider = StateProvider<double>((ref) => 0.0);
final modelDownloadMessageProvider = StateProvider<String>((ref) => '');

// ── Search & filter state ──────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');
final activeCategoryFilterProvider = StateProvider<String?>((ref) => null);

final filteredTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final all = await ref.watch(transactionsProvider.future);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final cat = ref.watch(activeCategoryFilterProvider);

  return all.where((tx) {
    final matchesSearch = query.isEmpty ||
        tx.merchantName.toLowerCase().contains(query) ||
        tx.upiId.toLowerCase().contains(query) ||
        tx.category.toLowerCase().contains(query);
    final matchesCat = cat == null || tx.category == cat;
    return matchesSearch && matchesCat;
  }).toList();
});
