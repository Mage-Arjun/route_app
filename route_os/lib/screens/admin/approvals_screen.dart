import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/route_change.dart';

class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  List<RouteChange> _changes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChanges();
  }

  Future<void> _loadChanges() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getRouteChanges();
      final changes = (data as List).map((c) => RouteChange.fromJson(c)).toList();
      if (mounted) setState(() { _changes = changes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(int id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.approveChange(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Change approved'), backgroundColor: AppTheme.success),
      );
      _loadChanges();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _reject(int id) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.rejectChange(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Change rejected'), backgroundColor: AppTheme.warning),
      );
      _loadChanges();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _changes.where((c) => c.status == 'pending').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Route Change Approvals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pending.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
                      SizedBox(height: 16),
                      Text('No pending approvals', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadChanges,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: pending.length,
                    itemBuilder: (context, index) => _changeCard(pending[index]),
                  ),
                ),
    );
  }

  Widget _changeCard(RouteChange change) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add ${change.customerName ?? 'Customer'} to ${change.routeName ?? 'Route'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(Icons.person, 'Requested by', change.requestedByName ?? 'Unknown'),
            _infoRow(Icons.numbers, 'Position', '#${change.recommendedSequence}'),
            _infoRow(Icons.straighten, 'Extra distance', '${change.additionalDistanceKm} km'),
            _infoRow(Icons.timer, 'Extra time', '${change.additionalTimeMins} min'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(change.id),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(change.id),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
