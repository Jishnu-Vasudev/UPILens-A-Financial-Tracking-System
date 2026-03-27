import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = AuthService().currentUser;
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoryTotalsAsync = ref.watch(categoryTotalsProvider);
    final monthlyTotalsAsync = ref.watch(monthlyTotalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B)),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar & Name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF13131A),
                    backgroundImage: user?.photoURL != null 
                        ? CachedNetworkImageProvider(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null 
                        ? Text(
                            (user?.displayName ?? 'U').substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF7B6EF6)),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'Guest User',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    user?.email ?? 'Not signed in',
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF888899)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stat Cards
            transactionsAsync.when(
              data: (txs) {
                final totalTx = txs.length;
                return StreamBuilder(
                  stream: Stream.fromFuture(ref.read(monthlyTotalsProvider.future)),
                  builder: (context, snapshot) {
                    final monthlyTotal = snapshot.data?['debit'] ?? 0.0;
                    return Row(
                      children: [
                        _buildStatCard('Transactions', totalTx.toString()),
                        const SizedBox(width: 12),
                        _buildStatCard('Spent (Month)', '₹${NumberFormat('#,##,###').format(monthlyTotal)}'),
                      ],
                    );
                  }
                );
              },
              loading: () => const ShimmerRow(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 32),

            // Spending Identity
            categoryTotalsAsync.when(
              data: (totals) {
                if (totals.isEmpty) return const SizedBox();
                final topCategory = totals.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                final identity = _getIdentity(topCategory.first.key);
                return _buildIdentitySection(identity);
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 32),

            // Settings List
            _buildSettingsList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x08FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF888899))),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySection(String identity) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF7B6EF6).withOpacity(0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7B6EF6).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your spending identity', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF7B6EF6))),
          const SizedBox(height: 12),
          Text(identity, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  String _getIdentity(String category) {
    switch (category.toLowerCase()) {
      case 'food': return 'Foodie 🍕';
      case 'transport': return 'Traveller ✈️';
      case 'shopping': return 'Shopaholic 🛍️';
      default: return 'Saver 💰';
    }
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      children: [
        _buildSettingsItem(Icons.notifications_none_rounded, 'Notification preferences', trailing: Switch(value: true, onChanged: (_) {}, activeColor: const Color(0xFF7B6EF6))),
        _buildSettingsItem(Icons.ios_share_rounded, 'Export data', subtitle: 'Placeholder'),
        _buildSettingsItem(Icons.info_outline_rounded, 'About'),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, {String? subtitle, Widget? trailing}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF13131A), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: Colors.white70),
      ),
      title: Text(title, style: GoogleFonts.inter(fontSize: 16, color: Colors.white)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF888899))) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Color(0xFF888899)),
      onTap: () {},
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        title: Text('Sign out', style: GoogleFonts.inter(color: Colors.white)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.inter(color: const Color(0xFF888899))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
              }
            },
            child: const Text('Sign out', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }
}

class ShimmerRow extends StatelessWidget {
  const ShimmerRow({super.key});
  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 60, child: Row(children: [Expanded(child: ColoredBox(color: Colors.white10)), SizedBox(width: 12), Expanded(child: ColoredBox(color: Colors.white10))]));
  }
}
