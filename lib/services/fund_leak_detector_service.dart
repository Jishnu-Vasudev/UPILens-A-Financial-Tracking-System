import '../models/transaction.dart';
import 'database_helper.dart';

class LeakResult {
  final String title;
  final String description;
  final double amountAtRisk;
  final String label;
  final Map<String, dynamic> metadata;

  LeakResult({
    required this.title,
    required this.description,
    required this.amountAtRisk,
    required this.label,
    this.metadata = const {},
  });
}

class FundLeakDetector {
  final DatabaseHelper _db = DatabaseHelper();

  Future<List<LeakResult>> detectLeaks() async {
    final allTransactions = await _db.getAllTransactions();
    final debits = allTransactions.where((tx) => tx.type == 'DEBIT').toList();
    if (debits.isEmpty) return [];

    final results = <LeakResult>[];

    // 1. Repeat small spends (< ₹200, > 4 times/month)
    results.addAll(_detectSmallFrequentSpends(debits));

    // 2. Subscription creep
    results.addAll(_detectSubscriptionCreep(debits));

    // 3. Late night spending (11pm–3am)
    results.addAll(_detectLateNightSpending(debits));

    // 4. Weekend splurge
    results.addAll(_detectWeekendSplurge(debits));

    // 5. UPI ID leaks (raw @ IDs)
    results.addAll(_detectUntrackedTransfers(debits));

    return results;
  }

  List<LeakResult> _detectSmallFrequentSpends(List<Transaction> debits) {
    final now = DateTime.now();
    final thisMonthDebits = debits.where((tx) => 
      tx.timestamp.year == now.year && tx.timestamp.month == now.month).toList();

    final merchantGroups = <String, List<Transaction>>{};
    for (var tx in thisMonthDebits) {
      if (tx.amount < 200) {
        merchantGroups.putIfAbsent(tx.merchantName, () => []).add(tx);
      }
    }

    final leaks = <LeakResult>[];
    merchantGroups.forEach((merchant, txs) {
      if (txs.length > 4) {
        final total = txs.fold(0.0, (sum, tx) => sum + tx.amount);
        leaks.add(LeakResult(
          title: merchant,
          description: 'Used $merchant ${txs.length} times this month for small spends.',
          amountAtRisk: total,
          label: 'Small but frequent',
        ));
      }
    });
    return leaks;
  }

  List<LeakResult> _detectSubscriptionCreep(List<Transaction> debits) {
    final merchantGroups = <String, List<Transaction>>{};
    for (var tx in debits) {
      merchantGroups.putIfAbsent(tx.merchantName, () => []).add(tx);
    }

    final leaks = <LeakResult>[];
    merchantGroups.forEach((merchant, txs) {
      if (txs.length >= 2) {
        txs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        for (int i = 0; i < txs.length - 1; i++) {
          final a = txs[i];
          final b = txs[i+1];
          final diffDays = b.timestamp.difference(a.timestamp).inDays;
          
          // Monthly pattern (28-32 days) and same amount (+-5%)
          if (diffDays >= 28 && diffDays <= 32) {
            final amountDiff = (a.amount - b.amount).abs();
            if (amountDiff <= (a.amount * 0.05)) {
              leaks.add(LeakResult(
                title: merchant,
                description: 'Recurring ₹${b.amount.toStringAsFixed(0)} charge detected on ${b.timestamp.day}th.',
                amountAtRisk: b.amount,
                label: 'Possibly forgotten subscription',
              ));
              break; // Only report once per merchant
            }
          }
        }
      }
    });
    return leaks;
  }

  List<LeakResult> _detectLateNightSpending(List<Transaction> debits) {
    final lateNight = debits.where((tx) {
      final hour = tx.timestamp.hour;
      return hour >= 23 || hour < 3;
    }).toList();

    if (lateNight.isEmpty) return [];

    final totalLateNight = lateNight.fold(0.0, (sum, tx) => sum + tx.amount);
    final totalSpend = debits.fold(0.0, (sum, tx) => sum + tx.amount);
    final percentage = (totalLateNight / totalSpend) * 100;

    return [LeakResult(
      title: 'Late Night Impulse',
      description: 'Spend between 11 PM - 3 AM is ${percentage.toStringAsFixed(1)}% of total.',
      amountAtRisk: totalLateNight,
      label: 'Late night impulse',
    )];
  }

  List<LeakResult> _detectWeekendSplurge(List<Transaction> debits) {
    final weekendSpends = debits.where((tx) => 
      tx.timestamp.weekday == DateTime.saturday || tx.timestamp.weekday == DateTime.sunday).toList();
    final weekdaySpends = debits.where((tx) => 
      tx.timestamp.weekday != DateTime.saturday && tx.timestamp.weekday != DateTime.sunday).toList();

    if (weekendSpends.isEmpty || weekdaySpends.isEmpty) return [];

    // Simple daily averages
    // Actually we should group by unique days present in history
    final weekendDays = weekendSpends.map((tx) => '${tx.timestamp.year}-${tx.timestamp.month}-${tx.timestamp.day}').toSet().length;
    final weekdayDays = weekdaySpends.map((tx) => '${tx.timestamp.year}-${tx.timestamp.month}-${tx.timestamp.day}').toSet().length;

    final avgWeekend = (weekendSpends.fold(0.0, (sum, tx) => sum + tx.amount)) / (weekendDays > 0 ? weekendDays : 1);
    final avgWeekday = (weekdaySpends.fold(0.0, (sum, tx) => sum + tx.amount)) / (weekdayDays > 0 ? weekdayDays : 1);

    if (avgWeekend > (avgWeekday * 1.4)) {
      final excess = avgWeekend - avgWeekday;
      return [LeakResult(
        title: 'Weekend Splurge',
        description: 'You spend ₹${avgWeekend.toStringAsFixed(0)}/day on weekends vs ₹${avgWeekday.toStringAsFixed(0)} on weekdays.',
        amountAtRisk: excess * 4, // Estimate for a month (4 weekends)
        label: 'Weekend overspend',
      )];
    }
    return [];
  }

  List<LeakResult> _detectUntrackedTransfers(List<Transaction> debits) {
    final untracked = debits.where((tx) {
      // Logic: merchant name is just the UPI ID or looks like a raw ID
      // If merchantName == upiId or merchantName contains @
      return tx.merchantName.contains('@') || tx.merchantName == tx.upiId;
    }).toList();

    if (untracked.isEmpty) return [];

    final total = untracked.fold(0.0, (sum, tx) => sum + tx.amount);

    return [LeakResult(
      title: 'Untracked Transfers',
      description: '${untracked.length} transfers to raw UPI IDs not identified as merchants.',
      amountAtRisk: total,
      label: 'Untracked transfers',
    )];
  }
}
