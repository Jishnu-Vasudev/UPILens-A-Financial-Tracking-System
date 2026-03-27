import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ModelNotLoadedException implements Exception {
  final String message;
  ModelNotLoadedException(this.message);
  @override
  String toString() => 'ModelNotLoadedException: $message';
}

class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  LlmService._internal();

  Future<String> getModelPath() async {
    final docs = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${docs.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return '${modelsDir.path}/gemma3-1b.gguf';
  }

  Future<bool> isModelReady() async {
    // Always false for now as fllama is removed
    return false;
  }

  Future<String> classifyTransaction(String merchantName, String upiId) async {
    throw ModelNotLoadedException('AI summaries will be available once on-device model support is added in the next release.');
  }

  Future<String> generateInsightSummary(Map<String, double> categoryTotals, double totalSpent) async {
    throw ModelNotLoadedException('AI summaries will be available once on-device model support is added in the next release.');
  }

  void dispose() {}

  Future<bool> testConnection() async => false;
}
