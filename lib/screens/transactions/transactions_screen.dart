import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/transaction.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredTransactionsProvider);
    final query = ref.watch(searchQueryProvider);
    final activeCategory = ref.watch(activeCategoryFilterProvider);

    const categories = [
      'Food', 'Transport', 'Shopping', 'Bills',
      'Entertainment', 'Health', 'Transfer', 'Other',
    ];

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              const SliverAppBar(
                floating: true,
                title: Text('Transactions'),
                centerTitle: false,
                toolbarHeight: 70,
              ),
              // Spacing for sticky search below app bar
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
              
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              
              filteredAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF7B6EF6))),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e', style: const TextStyle(color: Color(0xFFFF6B6B)))),
                ),
                data: (txList) {
                  if (txList.isEmpty) {
                    return SliverFillRemaining(
                      child: _EmptyState(query: query, activeCategory: activeCategory),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _AnimatedTransactionTile(
                            tx: txList[index],
                            index: index,
                          );
                        },
                        childCount: txList.length,
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),

          // Sticky Search Bar with Frosted Glass Effect
          Positioned(
            top: 100, // Roughly below app bar
            left: 0,
            right: 0,
            child: _FrostedSearchBar(
              query: query,
              activeCategory: activeCategory,
              categories: categories,
              onSearch: (v) => ref.read(searchQueryProvider.notifier).state = v,
              onCategorySelect: (cat) => ref.read(activeCategoryFilterProvider.notifier).state = cat,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedSearchBar extends StatelessWidget {
  final String query;
  final String? activeCategory;
  final List<String> categories;
  final Function(String) onSearch;
  final Function(String?) onCategorySelect;

  const _FrostedSearchBar({
    required this.query,
    required this.activeCategory,
    required this.categories,
    required this.onSearch,
    required this.onCategorySelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF13131A).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  onChanged: onSearch,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search merchant, UPI ID…',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF888899)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF888899)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF888899), size: 18),
                            onPressed: () => onSearch(''),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _CategoryChip(
                label: 'All',
                isSelected: activeCategory == null,
                onTap: () => onCategorySelect(null),
              ),
              ...categories.map((cat) => _CategoryChip(
                label: cat,
                isSelected: activeCategory == cat,
                onTap: () => onCategorySelect(cat == activeCategory ? null : cat),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7B6EF6) : const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B6EF6) : const Color(0x08FFFFFF),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF888899),
          ),
        ),
      ),
    );
  }
}

class _AnimatedTransactionTile extends StatefulWidget {
  final Transaction tx;
  final int index;
  const _AnimatedTransactionTile({required this.tx, required this.index});

  @override
  State<_AnimatedTransactionTile> createState() => _AnimatedTransactionTileState();
}

class _AnimatedTransactionTileState extends State<_AnimatedTransactionTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 400 + (widget.index * 50).clamp(0, 400)),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = widget.tx.type == 'DEBIT';
    final name = widget.tx.merchantName.isNotEmpty ? widget.tx.merchantName : widget.tx.upiId;
    final color = _generateColorFromName(name);

    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Container(
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
                      widget.tx.upiId,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF888899)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isDebit ? '-' : '+'}₹${NumberFormat('#,###').format(widget.tx.amount.round())}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDebit ? const Color(0xFFFF6B6B) : const Color(0xFF4ECDC4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, HH:mm').format(widget.tx.timestamp),
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF888899)),
                  ),
                ],
              ),
            ],
          ),
        ),
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

class _EmptyState extends StatelessWidget {
  final String query;
  final String? activeCategory;
  const _EmptyState({required this.query, required this.activeCategory});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            query.isNotEmpty || activeCategory != null
                ? 'No matches found'
                : 'No transactions yet',
            style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF888899)),
          ),
        ],
      ),
    );
  }
}
