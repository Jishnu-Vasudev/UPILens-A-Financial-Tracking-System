import '../models/transaction.dart';
import '../models/parsed_sms.dart';
import 'sms_parser.dart';
import 'rule_classifier.dart';
import 'llm_service.dart';
import 'database_helper.dart';

/// TransactionProcessor — the pipeline:
/// raw SMS → SmsParser → LlmService (try) / RuleClassifier (fallback) → DatabaseHelper
class TransactionProcessor {
  static final TransactionProcessor _instance = TransactionProcessor._internal();
  factory TransactionProcessor() => _instance;
  TransactionProcessor._internal();

  final _parser = SmsParser();
  final _rule = RuleClassifier();
  final _llm = LlmService();
  final _db = DatabaseHelper();

  /// Process a single raw SMS map.
  /// Returns the saved [Transaction] or null if the SMS couldn't be parsed.
  Future<Transaction?> process(Map<String, String> rawSms) async {
    final parsed = _parser.parse(rawSms);

    if (parsed.status == ParseStatus.unclassified || parsed.amount == null) {
      return null;
    }

    // Dedup — skip if already stored
    if (await _db.exists(parsed.id)) return null;

    final merchantName = parsed.merchantName ?? 'Unknown';
    final upiId = parsed.upiId ?? '';

    // Try LLM, fall back to rule classifier
    String category;
    String classifiedBy;
    try {
      category = await _llm.classifyTransaction(merchantName, upiId);
      classifiedBy = 'llm';
    } catch (_) {
      category = _rule.classify(merchantName, upiId);
      classifiedBy = 'rule';
    }

    final tx = Transaction(
      id: parsed.id,
      rawSms: parsed.rawBody,
      amount: parsed.amount!,
      type: parsed.type == SmsType.credit ? 'CREDIT' : 'DEBIT',
      merchantName: merchantName,
      upiId: upiId,
      bankName: parsed.bankName ?? '',
      category: category,
      timestamp: parsed.timestamp,
      classifiedBy: classifiedBy,
    );

    await _db.insertTransaction(tx);
    return tx;
  }

  /// Process a batch of raw SMS maps (e.g. from getSmsHistory).
  Future<int> processBatch(List<Map<String, String>> smsList) async {
    int saved = 0;
    for (final sms in smsList) {
      final tx = await process(sms);
      if (tx != null) saved++;
    }
    return saved;
  }
}
