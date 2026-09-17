import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class RouteAnalyticsScreen extends ConsumerStatefulWidget {
  final int routeId;
  const RouteAnalyticsScreen({super.key, required this.routeId});

  @override
  ConsumerState<RouteAnalyticsScreen> createState() => _RouteAnalyticsScreenState();
}

class _RouteAnalyticsScreenState extends ConsumerState<RouteAnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.getRouteAnalytics(widget.routeId);
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Failed to load analytics'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        _data!['route_name'] ?? '',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _statCard('Total Trips', '${_data!['total_trips']}', Icons.directions_car, AppTheme.primary),
                      _statCard('Avg Completion', '${(_data!['avg_completion_rate'] ?? 0).toStringAsFixed(1)}%', Icons.check_circle, AppTheme.success),
                      _statCard('Avg Distance', '${(_data!['avg_distance_km'] ?? 0).toStringAsFixed(1)} km', Icons.straighten, AppTheme.info),
                      _statCard('Total Stops', '${_data!['total_stops']}', Icons.place, AppTheme.accent),
                      const SizedBox(height: 16),
                      const Text('Recent Trips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...(_data!['recent_trips'] as List? ?? []).map((trip) => Card(
                        child: ListTile(
                          title: Text('${trip['date']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${trip['completed_stops']}/${trip['total_stops']} stops completed'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(trip['status']).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(trip['status'], style: TextStyle(color: _statusColor(trip['status']), fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: AppTheme.textSecondary))),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return AppTheme.success;
      case 'active': return AppTheme.info;
      case 'cancelled': return AppTheme.error;
      default: return AppTheme.textSecondary;
    }
  }
}
