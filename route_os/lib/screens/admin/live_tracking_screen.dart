import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  late final AnimationController _radarCtrl;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fetch();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetch(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _radarCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final api = ref.read(apiServiceProvider);
    try {
      final data = await api.getLiveLocations();
      if (mounted) {
        setState(() {
          _locations = data;
          _loading = false;
          _lastRefresh = DateTime.now();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Cannot connect to server';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Row(
          children: [
            // radar pulse icon
            AnimatedBuilder(
              animation: _radarCtrl,
              builder: (_, __) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // outer ring
                    Opacity(
                      opacity: (1 - _radarCtrl.value).clamp(0.0, 1.0),
                      child: Container(
                        width: 32 + 16 * _radarCtrl.value,
                        height: 32 + 16 * _radarCtrl.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(0.15),
                        border: Border.all(color: AppTheme.primary, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.gps_fixed_rounded,
                        color: AppTheme.primary,
                        size: 14,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              'Live Tracking',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.textSecondary,
            ),
            onPressed: _fetch,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── status bar ───────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _error != null ? AppTheme.error : AppTheme.success,
                    boxShadow: _error == null
                        ? [
                            BoxShadow(
                              color: AppTheme.success.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _error != null
                      ? 'Offline'
                      : 'Live — auto-refreshes every 10s',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Last: ${DateFormat('HH:mm:ss').format(_lastRefresh)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // ── driver count header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  '${_locations.length} vehicle${_locations.length != 1 ? 's' : ''} tracked',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // ── content ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 2,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Fetching live positions…',
                          style: GoogleFonts.outfit(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error != null
                ? _ErrorState(error: _error!, onRetry: _fetch)
                : _locations.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _locations.length,
                    itemBuilder: (_, i) =>
                        _DriverLocationCard(data: _locations[i], index: i),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Driver card ───────────────────────────────────────────────────────────────
class _DriverLocationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;

  const _DriverLocationCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? data['identifier'] ?? 'Vehicle';
    final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    final String? accuracy = null;
    final timestamp = (data['last_seen'] ?? data['updated_at']) as String?;
    final tripId = data['journey_id'];
    final hasLocation = data['latitude'] != null && data['longitude'] != null;

    DateTime? ts;
    if (timestamp != null) {
      try {
        ts = DateTime.parse(timestamp).toLocal();
      } catch (_) {}
    }

    final colors = [
      AppTheme.primary,
      AppTheme.accentBlue,
      AppTheme.purple,
      AppTheme.gold,
      AppTheme.accent,
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── top row ───────────────────────────────────────
            Row(
              children: [
                // avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (tripId != null)
                        Text(
                          'Trip #$tripId',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                // live pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.success.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hasLocation ? 'TRACKED' : 'NO GPS',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: hasLocation
                              ? AppTheme.success
                              : AppTheme.warning,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── coordinate rows ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _CoordRow(
                    label: 'LAT',
                    value: lat.toStringAsFixed(6),
                    color: color,
                  ),
                  const SizedBox(height: 6),
                  _CoordRow(
                    label: 'LNG',
                    value: lng.toStringAsFixed(6),
                    color: color,
                  ),
                  if (accuracy != null) ...[
                    const SizedBox(height: 6),
                    _CoordRow(
                      label: 'ACC',
                      value: accuracy,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ],
              ),
            ),
            if (ts != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${DateFormat('HH:mm:ss').format(ts)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CoordRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.textMuted.withOpacity(0.08),
            ),
            child: const Icon(
              Icons.location_off_rounded,
              size: 40,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No drivers are currently active',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Positions will appear here once drivers start trips',
            style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 44, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(error, style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
