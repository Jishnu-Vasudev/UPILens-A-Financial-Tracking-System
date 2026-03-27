import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/transaction.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyAsync = ref.watch(monthlyTotalsProvider);
    final categoryAsync = ref.watch(categoryTotalsProvider);
    final txAsync = ref.watch(transactionsProvider);
    
    // TODO: Budget is currently hardcoded at ₹10,000
    const double budget = 10000.0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(transactionsProvider);
          ref.invalidate(monthlyTotalsProvider);
          ref.invalidate(categoryTotalsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Text('UPI Lens', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 22)),
              centerTitle: false,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Hero Spend Card
                    monthlyAsync.when(
                      loading: () => const _HeroShimmer(),
                      error: (e, _) => _ErrorPlaceholder(message: e.toString()),
                      data: (totals) {
                        final spent = totals['debit'] ?? 0.0;
                        return _SpendHeroCard(spent: spent, budget: budget);
                      },
                    ),
                    const SizedBox(height: 32),

                    // Category Chips (Horizontal Scroll)
                    Text(
                      'Categories',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    categoryAsync.when(
                      loading: () => const _ChipsShimmer(),
                      error: (_, __) => const SizedBox(),
                      data: (cats) => _CategoryChips(categories: cats),
                    ),
                    const SizedBox(height: 32),

                    // Recent Transactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () {}, // Navigate to Transactions tab?
                          child: Text('See All', style: GoogleFonts.inter(color: const Color(0xFF7B6EF6), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    txAsync.when(
                      loading: () => const _TransactionsShimmer(),
                      error: (e, _) => const SizedBox(),
                      data: (txs) => txs.isEmpty 
                          ? const _EmptyTransactions()
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: min(txs.length, 10),
                              itemBuilder: (context, index) => _TransactionCard(tx: txs[index]),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendHeroCard extends StatelessWidget {
  final double spent;
  final double budget;
  const _SpendHeroCard({required this.spent, required this.budget});

  @override
  Widget build(BuildContext context) {
    final progress = (spent / budget).clamp(0.0, 1.0);
    final remaining = max(0.0, budget - spent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x08FFFFFF)),
        gradient: LinearGradient(
          colors: [const Color(0xFF7B6EF6).withOpacity(0.1), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Spent (Month)',
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF888899), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${NumberFormat('#,##,###').format(spent.round())}',
                style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B6EF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '₹${NumberFormat('#,##,###').format(remaining.round())} left',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7B6EF6), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Subtle Progress Arc
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  color: const Color(0xFF7B6EF6),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final Map<String, double> categories;
  const _CategoryChips({required this.categories});

  @override
  Widget build(BuildContext context) {
    final sorted = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sorted.map((cat) => Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x08FFFFFF)),
          ),
          child: Row(
            children: [
              Text(cat.key, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(width: 8),
              Text(
                '₹${NumberFormat('#,###').format(cat.value.round())}',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF888899)),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction tx;
  const _TransactionCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isDebit = tx.type == 'DEBIT';
    final name = tx.merchantName.isNotEmpty ? tx.merchantName : tx.upiId;
    final color = _generateColorFromName(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x08FFFFFF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 22,
            child: Text(
              name[0].toUpperCase(),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tx.category,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF888899)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDebit ? '-' : '+'}₹${NumberFormat('#,###').format(tx.amount.round())}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDebit ? const Color(0xFFFF6B6B) : const Color(0xFF4ECDC4),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d').format(tx.timestamp),
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF888899)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _generateColorFromName(String name) {
    final hash = name.hashCode;
    final List<Color> colors = [
      const Color(0xFF7B6EF6),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFB347),
      const Color(0xFFFF6B6B),
      const Color(0xFFF78FB3),
      const Color(0xFF3DC1D3),
    ];
    return colors[hash.abs() % colors.length];
  }
}

class _HeroShimmer extends StatelessWidget {
  const _HeroShimmer();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(color: const Color(0xFF13131A), borderRadius: BorderRadius.circular(24)),
    );
  }
}

class _ChipsShimmer extends StatelessWidget {
  const _ChipsShimmer();
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 44, child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 4,
      itemBuilder: (_, __) => Container(width: 100, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: const Color(0xFF13131A), borderRadius: BorderRadius.circular(12))),
    ));
  }
}

class _TransactionsShimmer extends StatelessWidget {
  const _TransactionsShimmer();
  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(5, (_) => Container(height: 70, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFF13131A), borderRadius: BorderRadius.circular(16)))));
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(child: Text('No transactions found', style: GoogleFonts.inter(color: const Color(0xFF888899)))),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  final String message;
  const _ErrorPlaceholder({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0x11FF6B6B), borderRadius: BorderRadius.circular(16)),
      child: Text(message, style: const TextStyle(color: Color(0xFFFF6B6B))),
    );
  }
}
