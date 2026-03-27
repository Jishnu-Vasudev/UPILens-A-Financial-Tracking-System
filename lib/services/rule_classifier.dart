import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/transaction.dart';

/// RuleClassifier — always-on fallback classifier.
/// 1. Checks merchant_lookup for exact keyword match.
/// 2. Falls back to cosine similarity against 384-dim anchor embeddings.
class RuleClassifier {
  static final RuleClassifier _instance = RuleClassifier._internal();
  factory RuleClassifier() => _instance;
  RuleClassifier._internal();

  Map<String, List<double>>? _anchorEmbeddings;
  Map<String, String>? _merchantLookup;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final String raw =
        await rootBundle.loadString('assets/classifier_data.json');
    final Map<String, dynamic> data = json.decode(raw) as Map<String, dynamic>;

    _merchantLookup = (data['merchant_lookup'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));

    _anchorEmbeddings = {};
    for (final category in kCategories) {
      final raw = data[category];
      if (raw != null) {
        _anchorEmbeddings![category] =
            (raw as List<dynamic>).map((e) => (e as num).toDouble()).toList();
      }
    }
    _initialized = true;
  }

  /// Classify a merchant name + UPI ID to a single category string.
  /// Never throws — always returns a result.
  String classify(String merchantName, String upiId) {
    if (!_initialized) return 'Other';

    final query = '$merchantName $upiId'.toLowerCase();

    // Step 1: keyword lookup
    for (final entry in _merchantLookup!.entries) {
      if (query.contains(entry.key)) return entry.value;
    }

    // Step 2: cosine similarity on bag-of-chars embedding
    final queryEmbedding = _bagOfCharsEmbedding(query);
    String bestCategory = 'Other';
    double bestScore = -double.infinity;

    for (final entry in _anchorEmbeddings!.entries) {
      final score = _cosine(queryEmbedding, entry.value);
      if (score > bestScore) {
        bestScore = score;
        bestCategory = entry.key;
      }
    }
    return bestCategory;
  }

  // ── Embedding helpers ──────────────────────────────────────────────────

  /// Simple bag-of-chars embedding: project each character's codepoint
  /// into a 384-dim space using a fixed hash projection.
  List<double> _bagOfCharsEmbedding(String text) {
    const dim = 384;
    final vec = List<double>.filled(dim, 0.0);
    for (int i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      // Simple projection: two hash planes
      final idx1 = (c * 31 + i * 7) % dim;
      final idx2 = (c * 17 + i * 13 + 5) % dim;
      vec[idx1] += 1.0;
      vec[idx2] += 0.5;
    }
    // L2 normalize
    return _normalize(vec);
  }

  List<double> _normalize(List<double> vec) {
    double norm = 0;
    for (final v in vec) norm += v * v;
    norm = sqrt(norm);
    if (norm == 0) return vec;
    return vec.map((v) => v / norm).toList();
  }

  double _cosine(List<double> a, List<double> b) {
    if (a.length != b.length) return 0;
    double dot = 0;
    for (int i = 0; i < a.length; i++) dot += a[i] * b[i];
    return dot; // vectors are L2-normalized, so dot = cosine
  }
}
