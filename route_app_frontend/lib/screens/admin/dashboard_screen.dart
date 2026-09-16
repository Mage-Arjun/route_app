import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/trip.dart';
import 'route_list_screen.dart';
import 'customer_list_screen.dart';
import 'vehicle_list_screen.dart';
import 'approvals_screen.dart';
import 'live_tracking_screen.dart';
import 'driver_approval_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _stats;
  List<Trip> _activeTrips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final stats = await api.getDashboard();
      final trips = await api.getTrips(status: 'active');
      if (mounted) {
        setState(() {
          _stats = stats;
          _activeTrips = trips;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─ Greeting Header ─
                  _buildGreeting(auth.user?.name ?? 'Admin', today),
                  const SizedBox(height: 20),

                  // ─ Today's Live Summary ─
                  _buildLiveSummaryCard(),
                  const SizedBox(height: 20),

                  // ─ Stat Grid ─
                  _buildStatGrid(),
                  const SizedBox(height: 20),

                  // ─ Active Trips ─
                  if (_activeTrips.isNotEmpty) ...[
                    _sectionHeader('Active Trips Today', Icons.local_shipping),
                    const SizedBox(height: 10),
                    ..._activeTrips.map((trip) => _ActiveTripCard(trip: trip)),
                    const SizedBox(height: 20),
                  ],

                  // ─ Quick Actions ─
                  _sectionHeader('Quick Actions', Icons.apps),
                  const SizedBox(height: 10),
                  _buildQuickActions(),
                ],
              ),
            ),
    );
  }

  Widget _buildGreeting(String name, String date) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_timeOfDay()}, $name 👋',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Icon(Icons.business_center, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSummaryCard() {
    if (_stats == null) return const SizedBox();
    final completed = _stats!['today_completed_stops'] as int? ?? 0;
    final pending = _stats!['today_pending_stops'] as int? ?? 0;
    final total = completed + pending;
    final rate = total > 0 ? completed / total : 0.0;
    final approvals = _stats!['pending_approvals'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's Progress", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (approvals > 0)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovalsScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pending_actions, size: 14, color: AppTheme.error),
                        const SizedBox(width: 4),
                        Text('$approvals approvals', style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('$completed', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.success)),
              Text(' / $total stops', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
              const Spacer(),
              Text('${(rate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: rate >= 0.8 ? AppTheme.success : rate >= 0.5 ? AppTheme.warning : AppTheme.error,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                rate >= 0.8 ? AppTheme.success : rate >= 0.5 ? AppTheme.warning : AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    if (_stats == null) return const SizedBox();
    final items = [
      (label: 'Routes', value: '${_stats!['total_routes']}', icon: Icons.route, color: AppTheme.primary),
      (label: 'Trips Today', value: '${_stats!['today_trips']}', icon: Icons.local_shipping, color: AppTheme.accent),
      (label: 'Customers', value: '${_stats!['total_customers']}', icon: Icons.store, color: AppTheme.info),
      (label: 'Drivers', value: '${_stats!['total_drivers']}', icon: Icons.person, color: AppTheme.success),
      (label: 'Vehicles', value: '${_stats!['total_vehicles']}', icon: Icons.directions_car, color: Colors.teal),
      (label: 'Pending OK', value: '${_stats!['pending_approvals']}', icon: Icons.approval, color: AppTheme.error),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return _StatCard(label: item.label, value: item.value, icon: item.icon, color: item.color);
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (label: 'Routes', subtitle: 'Manage delivery routes', icon: Icons.route, screen: () => const RouteListScreen()),
      (label: 'Customers', subtitle: 'Customer database', icon: Icons.store, screen: () => const CustomerListScreen()),
      (label: 'Fleet', subtitle: 'Vehicles & drivers', icon: Icons.local_shipping, screen: () => const VehicleListScreen()),
      (label: 'Approvals', subtitle: 'Review pending changes', icon: Icons.approval, screen: () => const ApprovalsScreen()),
      (label: 'Live Tracking', subtitle: 'Driver GPS positions', icon: Icons.gps_fixed_rounded, screen: () => const LiveTrackingScreen()),
      (label: 'Driver Accounts', subtitle: 'Approve new drivers', icon: Icons.manage_accounts_rounded, screen: () => const DriverApprovalScreen()),
    ];

    return Column(
      children: actions.map((a) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(a.icon, color: AppTheme.primary, size: 22),
          ),
          title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(a.subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => a.screen())),
        ),
      )).toList(),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }

  String _timeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}


// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}


// ── Active Trip Card ──────────────────────────────────────────────────────────

class _ActiveTripCard extends StatelessWidget {
  final Trip trip;
  const _ActiveTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final rate = trip.completionRate;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.route?.name ?? 'Trip #${trip.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: rate > 0.7 ? AppTheme.success : AppTheme.warning),
                ),
              ],
            ),
            if (trip.driver != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(trip.driver!.name, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 12),
                  Icon(Icons.store, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${trip.completedStops}/${trip.totalStops} stops',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  rate > 0.7 ? AppTheme.success : AppTheme.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
