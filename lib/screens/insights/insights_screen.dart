import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/providers.dart';
import '../../services/fund_leak_detector_service.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(insightSummaryProvider);
    final leaksAsync = ref.watch(fundLeaksProvider);
    final trendsAsync = ref.watch(monthlyTrendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(insightSummaryProvider);
          ref.invalidate(fundLeaksProvider);
          ref.invalidate(monthlyTrendsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // AI Summary Section
              insightAsync.when(
                loading: () => const _ShimmerSummary(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (summary) => _AISummaryCard(summary: summary),
              ),
              const SizedBox(height: 32),

              // Fund Leak Detector Section
              Text(
                'Fund leak detector',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              leaksAsync.when(
                loading: () => _buildLeakShimmer(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (leaks) => _LeakDetectorSection(leaks: leaks),
              ),
              const SizedBox(height: 32),

              // Spend Trend Section
              Text(
                '6-Month Trend',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              trendsAsync.when(
                loading: () => const _BarChartShimmer(),
                error: (e, _) => _ErrorCard(message: e.toString()),
                data: (trends) => _SpendTrendChart(trends: trends),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeakShimmer() {
    return Column(
      children: List.generate(3, (_) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: _BoxShimmer(height: 80),
      )),
    );
  }
}

class _AISummaryCard extends StatelessWidget {
  final String summary;
  const _AISummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final bullets = summary.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x08FFFFFF)),
        gradient: LinearGradient(
          colors: [const Color(0xFF7B6EF6).withOpacity(0.05), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7B6EF6), size: 20),
              const SizedBox(width: 8),
              Text(
                'SMART SUMMARY',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF7B6EF6),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...bullets.map((b) {
            final text = b.startsWith('-') ? b.substring(1).trim() : b.trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LeakDetectorSection extends StatelessWidget {
  final List<LeakResult> leaks;
  const _LeakDetectorSection({required this.leaks});

  @override
  Widget build(BuildContext context) {
    if (leaks.isEmpty) {
      return const _EmptyState(message: 'No fund leaks detected. You\'re doing great!');
    }

    final totalRisk = leaks.fold(0.0, (sum, l) => sum + l.amountAtRisk);

    return Column(
      children: [
        // Total Savings Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x08FFFFFF)),
          ),
          child: Column(
            children: [
              Text(
                'Potential monthly savings',
                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF888899)),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${NumberFormat('#,##,###').format(totalRisk.round())}',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4ECDC4),
                ),
              ),
            ],
          ),
        ),
        // Leak Cards
        ...leaks.map((leak) => _LeakCard(leak: leak)),
      ],
    );
  }
}

class _LeakCard extends StatelessWidget {
  final LeakResult leak;
  const _LeakCard({required this.leak});

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    if (leak.amountAtRisk > 1000) {
      accentColor = const Color(0xFFFF6B6B);
    } else if (leak.amountAtRisk > 200) {
      accentColor = const Color(0xFFFFB347);
    } else {
      accentColor = const Color(0xFF4ECDC4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x08FFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              leak.title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '₹${leak.amountAtRisk.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        leak.description,
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF888899)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          leak.label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpendTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trends;
  const _SpendTrendChart({required this.trends});

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) return const _EmptyState(message: 'Not enough data yet');

    final maxVal = trends.map((t) => (t['total'] as double)).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x08FFFFFF)),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal == 0 ? 1000 : maxVal * 1.3,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= trends.length) return const SizedBox.shrink();
                  final date = trends[idx]['month'] as DateTime;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      DateFormat('MMM').format(date).toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF888899), fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(trends.length, (i) {
            final total = (trends[i]['total'] as double);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: total,
                  color: const Color(0xFF7B6EF6),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVal * 1.3,
                    color: const Color(0x05FFFFFF),
                  ),
                ),
              ],
            );
          }),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              // tooltipBgColor: const Color(0xFF13131A),
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '₹${NumberFormat('#,###').format(rod.toY.round())}',
                GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerSummary extends StatelessWidget {
  const _ShimmerSummary();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF13131A),
      highlightColor: const Color(0xFF1A1A23),
      child: Container(
        height: 160,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _BarChartShimmer extends StatelessWidget {
  const _BarChartShimmer();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF13131A),
      highlightColor: const Color(0xFF1A1A23),
      child: Container(
        height: 240,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _BoxShimmer extends StatelessWidget {
  final double height;
  const _BoxShimmer({required this.height});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF13131A),
      highlightColor: const Color(0xFF1A1A23),
      child: Container(
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0x11FF6B6B), borderRadius: BorderRadius.circular(16)),
      child: Text(message, style: const TextStyle(color: Color(0xFFFF6B6B))),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: const Color(0xFF888899), fontSize: 14),
        ),
      ),
    );
  }
}
