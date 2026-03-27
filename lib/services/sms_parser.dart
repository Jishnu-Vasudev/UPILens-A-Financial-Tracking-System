import '../models/parsed_sms.dart';

/// SmsParser — parses raw UPI SMS bodies from Indian banks.
/// Covers HDFC, SBI, ICICI, Axis, Paytm/GPay formats.
class SmsParser {
  static final SmsParser _instance = SmsParser._internal();
  factory SmsParser() => _instance;
  SmsParser._internal();

  // ── Shared helpers ─────────────────────────────────────────────────────
  static final _amountPatterns = [
    RegExp(r'Rs\.?\s*([\d,]+\.?\d*)', caseSensitive: false),
    RegExp(r'INR\s*([\d,]+\.?\d*)', caseSensitive: false),
    RegExp(r'₹\s*([\d,]+\.?\d*)', caseSensitive: false),
  ];

  static final _upiIdPattern = RegExp(
    r'(?:VPA|UPI[:\s]+|to\s+|paid\s+to\s+)([a-zA-Z0-9.\-_]+@[a-zA-Z0-9]+)',
    caseSensitive: false,
  );

  static final _refPattern = RegExp(
    r'(?:Ref\.?\s*(?:No\.?|ID)?|UPI\s*Ref\.?\s*(?:No\.?)?|Txn\s*(?:Id|Ref)?)[:\s]*([A-Z0-9]{6,20})',
    caseSensitive: false,
  );

  // ── Bank-specific patterns (type, amount, merchant, upiId, ref, bank) ─
  static final _hdfc = RegExp(
    r'Rs\.?([\d,]+\.?\d*)\s+debited.*?(?:VPA|UPI\s+)([a-zA-Z0-9._\-]+@[a-zA-Z0-9]+).*?Ref\s*(?:No\s*)?([A-Z0-9]+)',
    caseSensitive: false,
  );

  static final _hdfcCredit = RegExp(
    r'Rs\.?([\d,]+\.?\d*)\s+credited.*?(?:VPA|UPI\s+)([a-zA-Z0-9._\-]+@[a-zA-Z0-9]+).*?Ref\s*(?:No\s*)?([A-Z0-9]+)',
    caseSensitive: false,
  );

  static final _sbi = RegExp(
    r'(?:a/c|acct?|account)\s+[Xx*]+(\d{4}).*?(?:debited|credited)\s+(?:by\s+)?(?:Rs|INR)\.?\s*([\d,]+\.?\d*).*?UPI\s*Ref\s*(?:No\.?\s*)?([A-Z0-9]+)',
    caseSensitive: false,
  );

  static final _icici = RegExp(
    r'ICICI\s*Bank\s*Acct?\s+[Xx*]+(\d{1,6})\s+(?:debited|credited)\s+(?:Rs|INR)\.?\s*([\d,]+\.?\d*).*?UPI[:\s]+([a-zA-Z0-9._\-]+@[a-zA-Z0-9]+).*?Ref[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );

  static final _axis = RegExp(
    r'INR\s*([\d,]+\.?\d*)\s+(?:debited|credited)\s+from\s+Axis\s*Bank.*?UPI\s*Ref\s*([A-Z0-9]+)',
    caseSensitive: false,
  );

  static final _paytmGpay = RegExp(
    r'Rs\.?\s*([\d,]+\.?\d*)\s+(?:paid|sent|transferred)\s+(?:to|via)\s+([^.]+?)(?:\.|,|UPI)\s*(?:Ref|UPI\s*Ref)[:\s]+([A-Z0-9]+)',
    caseSensitive: false,
  );

  // ── Public API ──────────────────────────────────────────────────────────
  ParsedSms parse(Map<String, String> rawSms) {
    final body = rawSms['body'] ?? '';
    final address = rawSms['address'] ?? '';
    final dateMs = int.tryParse(rawSms['date'] ?? '') ?? 0;
    final timestamp =
        dateMs > 0 ? DateTime.fromMillisecondsSinceEpoch(dateMs) : DateTime.now();
    final id = _generateId(body, dateMs);

    // Determine bank from sender address
    final bankName = _detectBank(address, body);

    // Try each format in priority order
    ParsedSms? result;
    result ??= _tryHdfc(body, id, timestamp, bankName);
    result ??= _trySbi(body, id, timestamp, bankName);
    result ??= _tryIcici(body, id, timestamp, bankName);
    result ??= _tryAxis(body, id, timestamp, bankName);
    result ??= _tryPaytmGpay(body, id, timestamp, bankName);
    result ??= _tryGeneric(body, id, timestamp, bankName);

    return result ??
        ParsedSms(
          id: id,
          rawBody: body,
          type: SmsType.unknown,
          timestamp: timestamp,
          status: ParseStatus.unclassified,
        );
  }

  // ── Bank-specific parsers ───────────────────────────────────────────────

  ParsedSms? _tryHdfc(String body, String id, DateTime ts, String bank) {
    // DEBIT
    var m = _hdfc.firstMatch(body);
    if (m != null) {
      return ParsedSms(
        id: id, rawBody: body, type: SmsType.debit, timestamp: ts, status: ParseStatus.parsed,
        amount: _parseAmount(m.group(1)),
        upiId: m.group(2),
        merchantName: _merchantFromUpi(m.group(2)),
        txnRef: m.group(3),
        bankName: bank,
      );
    }
    // CREDIT
    m = _hdfcCredit.firstMatch(body);
    if (m != null) {
      return ParsedSms(
        id: id, rawBody: body, type: SmsType.credit, timestamp: ts, status: ParseStatus.parsed,
        amount: _parseAmount(m.group(1)),
        upiId: m.group(2),
        merchantName: _merchantFromUpi(m.group(2)),
        txnRef: m.group(3),
        bankName: bank,
      );
    }
    return null;
  }

  ParsedSms? _trySbi(String body, String id, DateTime ts, String bank) {
    final m = _sbi.firstMatch(body);
    if (m == null) return null;
    final type = body.toLowerCase().contains('debited') ? SmsType.debit : SmsType.credit;
    final upi = _upiIdPattern.firstMatch(body)?.group(1);
    return ParsedSms(
      id: id, rawBody: body, type: type, timestamp: ts, status: ParseStatus.parsed,
      amount: _parseAmount(m.group(2)),
      upiId: upi,
      merchantName: _merchantFromUpi(upi),
      txnRef: m.group(3),
      bankName: bank.isNotEmpty ? bank : 'SBI',
    );
  }

  ParsedSms? _tryIcici(String body, String id, DateTime ts, String bank) {
    final m = _icici.firstMatch(body);
    if (m == null) return null;
    final type = body.toLowerCase().contains('debited') ? SmsType.debit : SmsType.credit;
    return ParsedSms(
      id: id, rawBody: body, type: type, timestamp: ts, status: ParseStatus.parsed,
      amount: _parseAmount(m.group(2)),
      upiId: m.group(3),
      merchantName: _merchantFromUpi(m.group(3)),
      txnRef: m.group(4),
      bankName: bank.isNotEmpty ? bank : 'ICICI',
    );
  }

  ParsedSms? _tryAxis(String body, String id, DateTime ts, String bank) {
    final m = _axis.firstMatch(body);
    if (m == null) return null;
    final type = body.toLowerCase().contains('debited') ? SmsType.debit : SmsType.credit;
    final upi = _upiIdPattern.firstMatch(body)?.group(1);
    return ParsedSms(
      id: id, rawBody: body, type: type, timestamp: ts, status: ParseStatus.parsed,
      amount: _parseAmount(m.group(1)),
      upiId: upi,
      merchantName: _merchantFromUpi(upi),
      txnRef: m.group(2),
      bankName: bank.isNotEmpty ? bank : 'Axis',
    );
  }

  ParsedSms? _tryPaytmGpay(String body, String id, DateTime ts, String bank) {
    final m = _paytmGpay.firstMatch(body);
    if (m == null) return null;
    final upi = _upiIdPattern.firstMatch(body)?.group(1);
    final merchant = m.group(2)?.trim();
    return ParsedSms(
      id: id, rawBody: body, type: SmsType.debit, timestamp: ts, status: ParseStatus.parsed,
      amount: _parseAmount(m.group(1)),
      upiId: upi,
      merchantName: merchant?.isNotEmpty == true ? merchant : _merchantFromUpi(upi),
      txnRef: m.group(3),
      bankName: bank.isNotEmpty ? bank : 'Paytm/GPay',
    );
  }

  /// Generic fallback — tries to extract amount, UPI ID, and ref from any body
  ParsedSms? _tryGeneric(String body, String id, DateTime ts, String bank) {
    double? amount;
    for (final p in _amountPatterns) {
      final m = p.firstMatch(body);
      if (m != null) { amount = _parseAmount(m.group(1)); break; }
    }
    if (amount == null) return null;

    final type = body.toLowerCase().contains('debited') ? SmsType.debit
        : body.toLowerCase().contains('credited') ? SmsType.credit
        : SmsType.unknown;
    final upi = _upiIdPattern.firstMatch(body)?.group(1);
    final ref = _refPattern.firstMatch(body)?.group(1);

    return ParsedSms(
      id: id,
      rawBody: body,
      type: type,
      timestamp: ts,
      status: ParseStatus.parsed,
      amount: amount,
      upiId: upi,
      merchantName: _merchantFromUpi(upi),
      txnRef: ref,
      bankName: bank,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _detectBank(String address, String body) {
    final a = address.toUpperCase();
    final b = body.toUpperCase();
    if (a.contains('HDFC') || b.startsWith('HDFC')) return 'HDFC Bank';
    if (a.contains('SBIINB') || a.contains('SBIPSG') || b.contains('STATE BANK')) return 'SBI';
    if (a.contains('ICICI')) return 'ICICI Bank';
    if (a.contains('AXISBK') || a.contains('AXISBANK') || b.contains('AXIS BANK')) return 'Axis Bank';
    if (a.contains('PAYTM') || a.contains('PYTM')) return 'Paytm';
    if (a.contains('GPAY') || a.contains('OKAXIS') || a.contains('OKSBI') || a.contains('OKHDFCBANK')) return 'Google Pay';
    if (a.contains('YESBNK')) return 'Yes Bank';
    return '';
  }

  String? _merchantFromUpi(String? upiId) {
    if (upiId == null) return null;
    final parts = upiId.split('@');
    if (parts.isEmpty) return upiId;
    // Clean up handle (e.g. "merchant.name" → "merchant name")
    return parts[0].replaceAll('.', ' ').replaceAll('-', ' ').trim();
  }

  double? _parseAmount(String? raw) {
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }

  String _generateId(String body, int dateMs) {
    final hash = body.hashCode ^ dateMs.hashCode ^ DateTime.now().microsecondsSinceEpoch;
    return hash.abs().toRadixString(16).padLeft(16, '0');
  }
}
