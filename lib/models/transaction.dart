/// Transaction — stored in sqflite and shown in UI
class Transaction {
  final String id;
  final String rawSms;
  final double amount;
  final String type; // 'DEBIT' | 'CREDIT'
  final String merchantName;
  final String upiId;
  final String bankName;
  final String category;
  final DateTime timestamp;
  final String classifiedBy; // 'llm' | 'rule' | 'manual'

  const Transaction({
    required this.id,
    required this.rawSms,
    required this.amount,
    required this.type,
    required this.merchantName,
    required this.upiId,
    required this.bankName,
    required this.category,
    required this.timestamp,
    required this.classifiedBy,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      rawSms: map['rawSms'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      merchantName: map['merchantName'] as String,
      upiId: map['upiId'] as String,
      bankName: map['bankName'] as String,
      category: map['category'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      classifiedBy: map['classifiedBy'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rawSms': rawSms,
      'amount': amount,
      'type': type,
      'merchantName': merchantName,
      'upiId': upiId,
      'bankName': bankName,
      'category': category,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'classifiedBy': classifiedBy,
    };
  }
}

const List<String> kCategories = [
  'Food',
  'Transport',
  'Shopping',
  'Bills',
  'Entertainment',
  'Health',
  'Transfer',
  'Other',
];
