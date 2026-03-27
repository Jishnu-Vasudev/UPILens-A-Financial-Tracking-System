/// ParsedSms — result of SmsParser.parse()
class ParsedSms {
  final String id; // UUID generated at parse time
  final String rawBody;
  final SmsType type;
  final double? amount;
  final String? merchantName;
  final String? upiId;
  final String? bankName;
  final String? txnRef;
  final DateTime timestamp;
  final ParseStatus status;

  const ParsedSms({
    required this.id,
    required this.rawBody,
    required this.type,
    this.amount,
    this.merchantName,
    this.upiId,
    this.bankName,
    this.txnRef,
    required this.timestamp,
    required this.status,
  });
}

enum SmsType { debit, credit, unknown }

enum ParseStatus { parsed, unclassified }
